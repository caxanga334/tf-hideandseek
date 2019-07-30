#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <tf2_isPlayerInSpawn>
#include <tf2wearables>
#include <morecolors>
#define REQUIRE_EXTENSIONS
#define AUTOLOAD_EXTENSIONS
#include <tf2items>
#include <SteamWorks>
#include "hideandseek/mapsupport.sp"
#include "hideandseek/spawnpoints.sp"

new const String:PLUGIN_VERSION[] = "0.0.1";
new const String:PLUGIN_STATE[] = "ALPHA";

/********BOOLEANS********/
bool bRoundActive; // is round active
bool bRoundSetup; // round is in setup mode.
bool bReadyToPlay; // determine if the game is ready
bool bWaitingForPlayers;
bool g_bBLUFrozen; // Is BLU team frozen?
//bool g_bInSpawn[MAXPLAYERS + 1]; // is player inside spawn?
bool g_bWasBLU[MAXPLAYERS + 1]; // player started on BLU team?

/********INTEGERS********/
int g_iRoundTime;
int g_iRoundInitialTime;
int g_iTeam[MAXPLAYERS + 1]; // remember player's team
int g_iCampStrikes[MAXPLAYERS + 1]; // how many camp strikes players received
//new g_iPlayersInGame = 0;
int g_iKillCounter[MAXPLAYERS + 1];

/********FLOATS********/
float flLastTimeAnn = 0.0;

/********HANDLES********/
Handle HT_WinCheck;
Handle HT_CampCheck;

/********CONVARS********/
ConVar sm_has_round_time;
ConVar sm_has_rt_per_player; // seconds to add to round time per players
ConVar sm_has_round_time_cap; // maximum round time allowed
ConVar sm_has_rt_kill_reduction; // round kill time reduction
ConVar sm_has_camp_strikes;
ConVar sm_has_time_remaining;
ConVar sm_has_freeze_duration;
ConVar sm_has_blu_ratio;
/********GAMECVARS********/
ConVar mp_scrambleteams_auto;
ConVar mp_autoteambalance;
ConVar mp_teams_unbalance_limit;

// =========
int cvar_iRoundTime;
int cvar_iMaxCampStrikes;
int cvar_iRTKillReduction;
float cvar_flTimeAnnCooldown;

// Better TF2 Weapon Loadout Slots
enum
{
	TFWepSlot_Primary = 0,
	TFWepSlot_Secondary = 1,
	TFWepSlot_Melee = 2,
	TFWepSlot_PDA_Build = 3,
	TFWepSlot_PDA_Destroy = 4,
	TFWepSlot_Building = 5,
	TFWepSlot_Spy_Revolver = 0,
	TFWepSlot_Sapper = 1,
	TFWepSlot_PDA_Disguise = 3,
	TFWepSlot_PDA_InvisWatch = 4,
};

 
public Plugin myinfo =
{
	name = "[TF2] Hide and Seek",
	author = "caxanga334",
	description = "Hide and Seek plugin for TF2",
	version = PLUGIN_VERSION,
	url = "https://github.com/caxanga334/"
}
 
public void OnPluginStart()
{	
	SP_BuildPath();
	MS_BuildPath();
	
	HookEvent("player_spawn", E_PlayerSpawn);
	HookEvent("player_death", E_PlayerDeath);
	HookEvent("teamplay_round_start", E_RoundStart);
	HookEvent("post_inventory_application", E_PostInventoryApplication );
	
	// translations
	LoadTranslations("hideandseek.phrases");
	LoadTranslations("common.phrases");
	
	//Timers
	CreateTimer(100.0, Timer_Announce, _, TIMER_REPEAT);
	CreateTimer(10.0, Timer_CheckForPlayers, _, TIMER_REPEAT);
	
	// Commands
	AddCommandListener(command_suicide, "kill");
	AddCommandListener(command_suicide, "explode");	
	RegConsoleCmd("sm_roundtimeleft", Command_RoundTimeLeft, "Displays the time remaining for the current round.");
	RegConsoleCmd("sm_rtl", Command_RoundTimeLeft, "Displays the time remaining for the current round.");
	RegConsoleCmd("sm_hasrules", Command_Rules, "Displays the Hide and Seek game rules.");
	
	// convars
	CreateConVar("sm_hideandseek_version", PLUGIN_VERSION, "Hide and Seek plugin version", FCVAR_NOTIFY);
	sm_has_round_time = CreateConVar( "sm_has_round_time", "180", "How low does the hide and seek round last? Base Time", FCVAR_NONE, true, 60.0, false);
	sm_has_rt_per_player = CreateConVar( "sm_has_rt_per_player", "30", "Round Time to add per player connected to the server. 2 Players are ignored.", FCVAR_NONE, true, 0.0, false);
	sm_has_round_time_cap = CreateConVar( "sm_has_round_time_cap", "600", "Maximum round time duration allowed in seconds.", FCVAR_NONE, true, 300.0, false);
	sm_has_camp_strikes = CreateConVar( "sm_has_camp_strikes", "3", "How many strikes can a player receive before being flagged as a spawn camper? 0 = Disabled.", FCVAR_NONE, true, 0.0, true, 10.0 );
	sm_has_time_remaining = CreateConVar( "sm_has_time_remaining", "90.0", "Cooldown between round time remaining adverts. 0 = Disabled.", FCVAR_NONE, true, 0.0, true, 300.0 );
	sm_has_freeze_duration = CreateConVar( "sm_has_freeze_duration", "15.0", "How long are BLU players frozen on round start?", FCVAR_NONE, true, 0.1, true, 60.0 );
	sm_has_rt_kill_reduction = CreateConVar( "sm_has_rt_kill_reduction", "15", "How many seconds to reduce from the round duration when a BLU player is killed by a RED player? 0 = Disabled", FCVAR_NONE, true, 0.0, true, 60.0 );
	sm_has_blu_ratio = CreateConVar( "sm_has_blu_ratio", "4", "BLU Player ratio. 1 every N RED. N is this cvar value.", FCVAR_NONE, true, 2.0, true, 31.0);
	
	sm_has_round_time = FindConVar("sm_has_round_time");
	if (sm_has_round_time != null)
	{
		sm_has_round_time.AddChangeHook(OnTimeConVarChanged);
		cvar_iRoundTime = sm_has_round_time.IntValue;
	}
	sm_has_camp_strikes = FindConVar("sm_has_camp_strikes");
	if (sm_has_camp_strikes != null)
	{
		sm_has_camp_strikes.AddChangeHook(OnCampConVarChanged);
		cvar_iMaxCampStrikes = sm_has_camp_strikes.IntValue;
	}
	sm_has_time_remaining = FindConVar("sm_has_time_remaining");
	if (sm_has_time_remaining != null)
	{
		sm_has_time_remaining.AddChangeHook(OnAnnConVarChanged);
		cvar_flTimeAnnCooldown = sm_has_time_remaining.FloatValue;
	}
	sm_has_rt_kill_reduction = FindConVar("sm_has_rt_kill_reduction");
	if (sm_has_rt_kill_reduction != null)
	{
		sm_has_rt_kill_reduction.AddChangeHook(OnRTKRConVarChanged);
		cvar_iRTKillReduction = sm_has_rt_kill_reduction.IntValue;
	}
	mp_autoteambalance = FindConVar("mp_autoteambalance");
	if (mp_autoteambalance != null)
	{
		mp_autoteambalance.AddChangeHook(OnAutoTeamBalanceChanged);
	}
	mp_teams_unbalance_limit = FindConVar("mp_teams_unbalance_limit");
	if (mp_teams_unbalance_limit != null)
	{
		mp_teams_unbalance_limit.AddChangeHook(OnTeamBalanceChanged);
	}
	mp_scrambleteams_auto = FindConVar("mp_scrambleteams_auto");
	if (mp_scrambleteams_auto != null)
	{
		mp_scrambleteams_auto.AddChangeHook(OnScrambleTeamChanged);
	}
	AutoExecConfig(true, "plugin.hideandseek");
}

public void OnMapStart()
{
	SteamWorks_SetGameDescription("Hide and Seek");
	SP_LoadConfig();
	MS_LoadConfig();
}

public void TF2_OnWaitingForPlayersStart() {
	bWaitingForPlayers = true;
	LogMessage("TF2 Waiting For Players started.");
}

public void TF2_OnWaitingForPlayersEnd() {
	bWaitingForPlayers = false;
	LogMessage("TF2 Waiting For Players ended.");
}

/****************************************************
				CONVAR FUNCTIONS
*****************************************************/

public OnTimeConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iRoundTime = sm_has_round_time.IntValue;
}

public OnCampConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iMaxCampStrikes = sm_has_camp_strikes.IntValue;
}

public OnAnnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_flTimeAnnCooldown = sm_has_time_remaining.FloatValue;
}

public OnRTKRConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iRTKillReduction = sm_has_camp_strikes.IntValue;
}

public OnScrambleTeamChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}

public OnAutoTeamBalanceChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}

public OnTeamBalanceChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}


/****************************************************
					COMMANDS
*****************************************************/

// Commands
public Action command_suicide(int client, const char[] command, int argc)
{
	if(bRoundActive)
	{
		LogAction(client, -1, "Player %L attempted to suicide while the round was active.", client);
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action Command_RoundTimeLeft(int client, int args)
{
	new iTimeRemaining = GetRemainingTime();
	CPrintToChat(client, "%t", "Round Time", iTimeRemaining);
	return Plugin_Handled;
}

public Action Command_Rules(int client, int args)
{
	CPrintToChat(client,"%t", "GRT");
	CPrintToChat(client,"%t", "GRL1");
	CPrintToChat(client,"%t", "GRL2");
	CPrintToChat(client,"%t", "GRL3");
	CPrintToChat(client,"%t", "GRL4", cvar_iRTKillReduction);
	return Plugin_Handled;
}

/****************************************************
					MENUS
*****************************************************/

/****************************************************
				EVENT FUNCTIONS
*****************************************************/

public Action:E_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new iKiller = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(bRoundActive) {
		// RED player died during while the round is active, move him/her to BLU.
		if(iKiller >= 1) {
			if(GetClientTeam(iClient) == _:TFTeam_Red && IsClientInGame(iKiller)) {
				TF2_ChangeClientTeam(iClient, TFTeam_Blue);
				g_iTeam[iClient] = 3;
				g_iKillCounter[iKiller]++; // add 1 kill
			}
			
			if(GetClientTeam(iClient) == _:TFTeam_Blue && GetClientTeam(iKiller) == _:TFTeam_Red && IsClientInGame(iKiller)) {
			if(cvar_iRTKillReduction >= 1) {
					g_iRoundTime = g_iRoundTime - cvar_iRTKillReduction;
				}
			}			
		}
		else if(iKiller == 0 && GetRunningTime() > 15) {
			TF2_ChangeClientTeam(iClient, TFTeam_Blue);
		}
		CheckPlayers();
	}
}

public Action:E_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	new TFTeam:iTeam = TF2_GetClientTeam(iClient);
	if(bRoundActive) // round is active
	{
		// player spawned as RED while round is active move the player to BLU
		// g_iTeam check allows RED players that were dead before the round was active to respawn
		if(iTeam == TFTeam_Red && g_iTeam[iClient] != 2)
		{
			CPrintToChat(iClient, "%t", "Cannot Join");
			TF2_ChangeClientTeam(iClient, TFTeam_Blue);
		}
		if(iTeam == TFTeam_Blue && g_bBLUFrozen == true)
		{
			SetEntityMoveType(iClient, MOVETYPE_NONE);
		}
	}
	if(bReadyToPlay)
	{
		if(iTeam == TFTeam_Red && SP_Available_RED())
		{
			SP_TeleportPlayer(iClient, 2);
		}
		if(iTeam == TFTeam_Blue && SP_Available_BLU())
		{
			SP_TeleportPlayer(iClient, 3);
		}
	}
	CheckPlayers();
}

public Action:E_PostInventoryApplication(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(bReadyToPlay)
	{
		PrepareWeapons(iClient);
	}
}

public Action:E_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrepareMap();
	CheckPlayers();
	if(bReadyToPlay)
	{
		// reset player's team
		for (new i = 1; i <= MaxClients; i++)
		{
			g_iTeam[i] = 0;
			// g_bInSpawn[i] = true;
		}
		CreateTimer(2.0, Timer_RoundStart);
	}
}

/****************************************************
				ROUND FUNCTIONS
*****************************************************/
// functions to manage rounds

stock SetRoundTime()
{
	int iPlayers = GetTeamClientCount(2) + GetTeamClientCount(3); // ignore spectators
	int iAddPerPlayer, iFreezeTime;
	sm_has_rt_per_player = FindConVar("sm_has_rt_per_player");
	sm_has_round_time_cap = FindConVar("sm_has_round_time_cap");
	sm_has_freeze_duration = FindConVar("sm_has_freeze_duration");
	if (sm_has_rt_per_player == null || sm_has_round_time_cap == null || sm_has_freeze_duration == null)
	{
		LogError("Round time received null from convar!");
	}
	
	iFreezeTime = RoundToNearest(sm_has_freeze_duration.FloatValue);
	
	iPlayers -= 2; // if we have exactly 2 players, use base time only
	if(iPlayers > 0) {
		iAddPerPlayer = sm_has_rt_per_player.IntValue * iPlayers;
	}
	else {
		iAddPerPlayer = 0; // fail-safe
	}
	
	g_iRoundTime = GetTime() + cvar_iRoundTime + iAddPerPlayer + iFreezeTime;
	
	if(g_iRoundTime > GetTime() + sm_has_round_time_cap.IntValue)
	{
		g_iRoundTime = GetTime() + sm_has_round_time_cap.IntValue + iFreezeTime;
	}
	else
	{
		g_iRoundTime = GetTime() + cvar_iRoundTime; // fail-safe
		LogError("An error occurred during round time calculation.");
	}

	
	g_iRoundInitialTime = GetTime();
	flLastTimeAnn = GetGameTime() + cvar_flTimeAnnCooldown;
}

// starts a new round
stock StartNewRound()
{
	bRoundSetup = true;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_iCampStrikes[i] = 0;
			g_iKillCounter[i] = 0;
		}
	}
	CreateTeams();
}

// This function will move players to form teams.
stock CreateTeams()
{
	int iTarget;
	int iMaxBLU = GetInitialBLUPlayers();
	
	// select BLU players and store on g_iTeam
	for (new i = 1; i <= iMaxBLU; i++)
	{
		LogMessage("BLU Selection: i = %d", i);
		iTarget = GetRandomPlayer();
		if(IsClientInGame(iTarget))
		{
			g_iTeam[iTarget] = 3; // BLU
			g_bWasBLU[iTarget] = true;
			LogMessage("Player %L was selected to play on BLU team", iTarget);
			CPrintToChat(iTarget,"%t", "Selected BLU");
		}
	}
	// assign players to a team
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i)) // move BLU players to RED
		{
			if(g_iTeam[i] == 3) // move BLU players to BLU
			{
				TF2_ChangeClientTeam(i, TFTeam_Blue);
				LogMessage("Player %L was moved to BLU team", i);
			}
			else
			{
				TF2_ChangeClientTeam(i, TFTeam_Red);
				g_iTeam[i] = 2;
				g_bWasBLU[i] = false;
			}
		}
	}
	CreateTimer(2.0, ActiveRound);
}
 
public Action ActiveRound(Handle timer)
{
	//respawns dead players after moving them
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) >= 2) // checks for dead RED/BLU players at round start.
		{
			TF2_RespawnPlayer(i); // respawns them.
		}
	}
	// RED = 2 | BLU = 3
	if(GetTeamClientCount(3) <= 0) // round is about to start but BLU is empty
	{
		new iTarget = GetRandomPlayer();
		TF2_ChangeClientTeam(iTarget, TFTeam_Blue);
		g_bWasBLU[iTarget] = true;
		CPrintToChat(iTarget, "%t", "Moved");
		LogMessage("WARNING: ActiveRound was called with 0 players on BLU.");
	}
	// Round Timers
	if(HT_WinCheck != INVALID_HANDLE)
	{
		KillTimer(HT_WinCheck);
		HT_WinCheck = INVALID_HANDLE;
	}
	if(HT_CampCheck != INVALID_HANDLE)
	{
		KillTimer(HT_CampCheck);
		HT_CampCheck = INVALID_HANDLE;
	}
	HT_WinCheck = CreateTimer(1.0, Timer_WinCheck, _, TIMER_REPEAT); // timed check to see if any team won
	HT_CampCheck = CreateTimer(8.0, Timer_SpawnCheck, _, TIMER_REPEAT); // check for players camping inside spawn
	// End Round Timers
	bRoundActive = true;// enable round start flag, this blocks people from moving from BLU to RED
	bRoundSetup = false;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) == _:TFTeam_Blue)
			{
				CPrintToChat(i,"%t", "You Seek");// round start message
			}
			else if(GetClientTeam(i) == _:TFTeam_Red)
			{
				CPrintToChat(i,"%t", "You Hide");// round start message
			}
		}
	}
	SetRoundTime();
	FreezePlayers();
	int iRoundDuration = GetRemainingTime();
	CPrintToChatAll("%t", "Round Start", iRoundDuration);// round start message
}

stock EndRound(int iWinner)
{
	if(HT_WinCheck != INVALID_HANDLE)
	{
		KillTimer(HT_WinCheck);
		HT_WinCheck = INVALID_HANDLE;
	}
	if(HT_CampCheck != INVALID_HANDLE)
	{
		KillTimer(HT_CampCheck);
		HT_CampCheck = INVALID_HANDLE;
	}
	int iMVP = 0;
	int iPlayer = -1;
	bRoundActive = false;
	
	new iFlags = GetCommandFlags("mp_forcewin");
	SetCommandFlags( "mp_forcewin", iFlags & ~FCVAR_CHEAT );
	ServerCommand( "mp_forcewin %i", iWinner );
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(g_iKillCounter[i] > iMVP) // grab the highest number stored in the array
		{
			iMVP = g_iKillCounter[i]; // store the highest number
			iPlayer = i; // store the player userid
		}
	}
	if(iMVP > 0 && IsClientInGame(iPlayer)) // oh look someone died
	{
		decl String:MVPPlayerName[MAX_NAME_LENGTH];
		GetClientName(iPlayer, MVPPlayerName, sizeof(MVPPlayerName));
		CPrintToChatAll("%t", "Round MVP", MVPPlayerName, iMVP);
		LogMessage("Hide and Seek round ended. BLU MVP was: %L", iPlayer);
	}
}

/****************************************************
					TIMERS
*****************************************************/

public Action:Timer_Announce(Handle:hTimer)
{
	int msg = GetRandomInt(0,4);
	if(msg == 1)
	{
		CPrintToChatAll("%t", "Plugin By");
		CPrintToChatAll("{green}https://github.com/caxanga334/tf-hideandseek");
	}
	else if(msg == 2)
	{
		CPrintToChatAll("%t", "Plugin Version", PLUGIN_VERSION, PLUGIN_STATE);
	}
	else if(msg == 3)
	{
		CPrintToChatAll("%t", "AD1");
	}
	else if(msg == 4)
	{
		CPrintToChatAll("%t", "AD2");
	}
}

public Action:Timer_CheckForPlayers(Handle:hTimer)
{
	CheckPlayers();
}

public Action Timer_RoundStart(Handle timer)
{
	StartNewRound();
}

public Action Timer_UnfreezeBLU(Handle timer)
{
	g_bBLUFrozen = false;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == _:TFTeam_Blue)
		{
			SetEntityMoveType(i, MOVETYPE_WALK);
			CPrintToChat(i, "%t", "Unfrozen");
		}
	}
	LogMessage("BLU Players unfrozen.");
}

public Action Timer_WinCheck(Handle timer)
{
	CheckPlayers();
	if((GetGameTime() > flLastTimeAnn) && cvar_flTimeAnnCooldown > 0)
	{
		flLastTimeAnn = GetGameTime() + cvar_flTimeAnnCooldown;
		new iTimeRemaining = g_iRoundTime - GetTime();
		CPrintToChatAll("%t", "Round Time", iTimeRemaining);
	}
	if(GetTime() > g_iRoundTime)
	{
		// round ends here
		// RED = 2 | BLU = 3
		if(GetTeamClientCount(2) >= 1) // round ended with at least 1 RED player alive.
		{
			CPrintToChatAll("%t", "Win By Time");
			EndRound(2);
		}
	}
}

public Action Timer_SpawnCheck(Handle timer)
{
	if(!bRoundActive || cvar_iMaxCampStrikes == 0) // round is not active OR camp strike is disabled, do nothing
	{
		return Plugin_Continue;
	}
	else
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) == _:TFTeam_Red && GetRunningTime() > 30)
			{
				if(TF2Spawn_IsClientInSpawn2(i))
				{
					if(g_iCampStrikes[i] > cvar_iMaxCampStrikes) // player is a camper
					{
						ForcePlayerSuicide(i);
						CPrintToChat(i, "%t", "Camper Killed");
						LogMessage("Player %L was killed for camping inside spawn", i);
						return Plugin_Continue;
					}
					else
					{
						g_iCampStrikes[i]++;
						CPrintToChat(i, "%t", "Camper Warning");
						LogMessage("Player %L was flagged for camping inside spawn", i);
						return Plugin_Continue;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

/****************************************************
				PLAYER FUNCTIONS
*****************************************************/

public OnClientConnected(iTarget)
{
	if(bRoundActive)
	{
		g_iTeam[iTarget] = 3; // Assign players to BLU team if they connect after round setup
		g_bWasBLU[iTarget] = false;
		g_iKillCounter[iTarget] = 0;
	}
}

public OnClientDisconnect(iTarget)
{
	g_iTeam[iTarget] = 0;
	g_bWasBLU[iTarget] = false;
	g_iKillCounter[iTarget] = 0;
	CheckPlayers();
}

// a function to get a random player that works (maybe?)
int GetRandomPlayer()
{
	new players_available[MAXPLAYERS+1];
	new counter = 0; // counts how many valid players we have
	for (new i = 1; i <= MaxClients; i++)
	{
		// Ignore players who was selected to start on BLU last round.
		if (IsClientInGame(i) && !IsFakeClient(i) && g_bWasBLU[i] == false)
		{
			players_available[counter] = i; // stores the client userid
			counter++;
		}
	}
	// now we should have an array filled with user ids and exactly how many players we have in game.
	int iRandomMax = counter - 1;
	int iRandom = GetRandomInt(0,iRandomMax); // get a random number between 1 and counted players
	// now we get the user id from the array cell selected via iRandom
	//CPrintToChatAll("DEBUG: iRandom: %d ,UserID: %d , iRandomMax: %d", iRandom, players_available[iRandom], iRandomMax);
	LogMessage("DEBUG: iRandom: %d ,UserID: %d , iRandomMax: %d", iRandom, players_available[iRandom], iRandomMax);
	return players_available[iRandom];
}

public void TF2Spawn_EnterSpawn( iClient, iEntity )
{
	if(bRoundActive && IsClientInGame(iClient) && IsPlayerAlive(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) == _:TFTeam_Red)
	{
		if(g_iCampStrikes[iClient] > cvar_iMaxCampStrikes) // player is a camper
		{
			ForcePlayerSuicide(iClient);
			CPrintToChat(iClient, "%t", "Camper Killed");
			LogMessage("Player %L was killed for camping inside spawn", iClient);
		}
		else
		{
			g_iCampStrikes[iClient]++;
			CPrintToChat(iClient, "%t", "Camper Warning");
		}
	}
}

/* public void TF2Spawn_LeaveSpawn( iClient, iEntity )
{
	g_bInSpawn[iClient] = false;
} */

// function that checks player count
stock CheckPlayers()
{
	// RED = 2 | BLU = 3
	int iRed = GetTeamClientCount(2);
	int iBlue = GetTeamClientCount(3);
	// game is in progress
	if(bRoundActive)
	{
		if(iRed <= 0)
		{
			EndRound(3);
		}
		else if(iBlue <= 0)
		{
			EndRound(2);		
		}		
	}
	else if(!bReadyToPlay && !bRoundSetup && !bWaitingForPlayers) // not playing and not enough players
	{
		if(iRed + iBlue >= 2) // we have 2 players in game
		{
			bReadyToPlay = true; // set ready to play
			ServerCommand("mp_restartround 5"); // restarts round
		}
	}
	else if(bReadyToPlay && iRed + iBlue < 2) // game is ready but we have 1 or less players
	{
		bReadyToPlay = false;
	}
}

// this functions returns how many players should be on BLU team at the start of a round
int GetInitialBLUPlayers()
{
	sm_has_blu_ratio = FindConVar("sm_has_blu_ratio");
	if (sm_has_blu_ratio == null) {
		LogError("Round time received null from convar!");
	}
	int iPlayerCount = GetTeamClientCount(2) + GetTeamClientCount(3); // ignore spectators
	int iRatio = sm_has_blu_ratio.IntValue;
	int iTmp;
	
	if(iPlayerCount <= iRatio) // players in the server is less than or equal to the value of sm_has_blu_ratio 
	{
		iTmp = 1;
		LogMessage("Player count is lower than sm_has_blu_ratio. 1 player will start on BLU this round.");
	}
	else 
	{
		iTmp = iPlayerCount / iRatio;
		LogMessage("%d player(s) will start on BLU this round.", iTmp);	
	}
	return iTmp;
}

stock FreezePlayers() {
	sm_has_freeze_duration = FindConVar("sm_has_freeze_duration");
	if (sm_has_freeze_duration != null) {
		g_bBLUFrozen = true;
		
		CreateTimer(sm_has_freeze_duration.FloatValue, Timer_UnfreezeBLU);
		
		int iFreezeTime;
		iFreezeTime = RoundToNearest(sm_has_freeze_duration.FloatValue);
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == _:TFTeam_Blue)
			{
				SetEntityMoveType(i, MOVETYPE_NONE);
				CPrintToChat(i,"%t", "BLU Frozen", iFreezeTime);
			}
		}
	}
	else {
		g_bBLUFrozen = false;
	}
}
  
/****************************************************
				TIME FUNCTIONS
*****************************************************/

// returns the time remaining for the round in seconds
int GetRemainingTime()
{
	new iTimeRemaining = g_iRoundTime - GetTime();
	if(bRoundActive)
	{
		return iTimeRemaining;
	}
	else
	{
		return -1;
	}
}

// returns how many seconds has passed since the round started
int GetRunningTime()
{
	new iRunningTime = GetTime() - g_iRoundInitialTime;
	if(bRoundActive)
	{
		return iRunningTime;
	}
	else
	{
		return -1;
	}
}
/****************************************************
				WEAPON FUNCTIONS
*****************************************************/

stock PrepareWeapons(int iClient)
{
	int iPrimary, iSecondary;
	new TFTeam:iTeam = TF2_GetClientTeam(iClient);
	new TFClassType:iClass = TF2_GetPlayerClass( iClient );
	new String:weaponAttribs[256];
	//new iIndex; // item definition index
	new iWeapon; // weapon entity index
	
	if(iTeam == TFTeam_Red)
	{
		// remove wearables
		iPrimary = TF2_GetPlayerLoadoutSlot(iClient, TF2LoadoutSlot_Primary, true);
		if(iPrimary != -1)
		{
			TF2_RemovePlayerWearable(iClient, iPrimary);
		}
		iSecondary = TF2_GetPlayerLoadoutSlot(iClient, TF2LoadoutSlot_Secondary, true);
		if(iSecondary != -1)
		{
			TF2_RemovePlayerWearable(iClient, iSecondary);
		}
		
		TF2_RemoveAllWeapons(iClient);
		
		switch( iClass )
		{
			case TFClass_Scout: // cleaver causes knockback, slow recharge | no fall damage, 10% increased jump height
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "522 ; 1 ; 278 ; 4.0");
				SpawnWeapon( iClient, "tf_weapon_cleaver", 812, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25 ; 275 ; 1 ; 326 ; 1.1");
				SpawnWeapon( iClient, "tf_weapon_bat", 0, 1, 0, weaponAttribs, false);
				CPrintToChat( iClient, "%t", "class red scout");
			}
			case TFClass_Soldier: // bonuses: Move speed increases as the user becomes injured, Damage increases as the user becomes injured 
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.40 ; 235 ; 2 ; 115 ; 1");
				SpawnWeapon( iClient, "tf_weapon_shovel", 447, 1, 0, weaponAttribs, false);
			}
			case TFClass_Pyro: // slows down enemy on hit
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25 ; 182 ; 3");
				SpawnWeapon( iClient, "tf_weapon_fireaxe", 348, 1, 0, weaponAttribs, false); // Sharpened Volcano Fragment
				CPrintToChat( iClient, "%t", "class red pyro");
			}
			case TFClass_DemoMan:
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "249 ; 0.3"); // slow recharge shield
				SpawnWeapon( iClient, "tf_wearable_demoshield", 131, 1, 0, weaponAttribs, true);
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25");
				SpawnWeapon( iClient, "tf_weapon_bottle", 1, 1, 0, weaponAttribs, false);
			}
			case TFClass_Heavy: // reduced damage from ranged sources
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "874 ; 2.0");
				SpawnWeapon( iClient, "tf_weapon_lunchbox", 42, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.5 ; 205 ; 0.2 ; 737 ; 3");
				SpawnWeapon( iClient, "tf_weapon_fists", 656, 1, 0, weaponAttribs, false);
			}
			case TFClass_Engineer:
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25");
				SpawnWeapon( iClient, "tf_weapon_robot_arm", 142, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "287 ; 0.25 ; 113 ; 10 ; 286 ; 0.4 ; 790 ; 4.0"); // -75% sentry gun damage, +10 metal every 5 sec, -60% building health, teleport costs 200 metal
				SpawnWeapon( iClient, "tf_weapon_pda_engineer_build", 25, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "153 ; 1");
				SpawnWeapon( iClient, "tf_weapon_pda_engineer_destroy", 26, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "153 ; 1");
				SpawnWeapon( iClient, "tf_weapon_builder", 28, 1, 0, weaponAttribs, false);
			}
			case TFClass_Medic:
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25 ; 129 ; -2"); // reduced health regen
				SpawnWeapon( iClient, "tf_weapon_bonesaw", 304, 1, 0, weaponAttribs, false);
			}
			case TFClass_Sniper:
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "278 ; 2.0"); // 100% slow recharge speed
				SpawnWeapon( iClient, "tf_weapon_jar", 58, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "1 ; 0.25");
				SpawnWeapon( iClient, "tf_weapon_club", 3, 1, 0, weaponAttribs, false);
				CPrintToChat( iClient, "%t", "class red sniper");
			}
			case TFClass_Spy:
			{
				Format(weaponAttribs, sizeof(weaponAttribs), "156 ; 1 ; 154 ; 1"); // silent killer, disguise on backstab
				SpawnWeapon( iClient, "tf_weapon_knife", 4, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "426 ; 0.0 ; 428 ; 2.0"); // -100% damage, + 100% health
				SpawnWeapon( iClient, "tf_weapon_builder", 735, 1, 0, weaponAttribs, false);
				Format(weaponAttribs, sizeof(weaponAttribs), "35 ; 0.25 ; 729 ; 0.5 ; 82 ; 1.4 ; 728 ; 1 ; 160 ; 1 ; 159 ; 1"); // -75% slower cloak regen, +40% cloak consume rate, +1 second blink time, silent uncloak
				SpawnWeapon( iClient, "tf_weapon_invis", 30, 1, 0, weaponAttribs, false); // No cloak meter from ammo boxes when invisible, -50% cloak meter from ammo boxes
			}
		}
		// global RED attributes
		iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if(iWeapon >= 1)
		{
			TF2Attrib_SetByName(iWeapon, "health from packs decreased", 0.50);
			TF2Attrib_SetByName(iWeapon, "heal on hit for slowfire", 10.0);
			TF2Attrib_SetByName(iWeapon, "restore health on kill", 100.0);
		}
	}
	else if(iTeam == TFTeam_Blue)
	{
		// global ammo regen for primary weapons
		iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
		if(iWeapon >= 1)
		{
			TF2Attrib_SetByName(iWeapon, "ammo regen", 0.25);
			TF2Attrib_SetByName(iWeapon, "health regen", 1.0);
			TF2Attrib_SetByName(iWeapon, "critboost on kill", 8.0);
		}
		switch( iClass )
		{
			case TFClass_Scout:
			{
				iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
				if(iWeapon >= 1)
				{
					TF2Attrib_SetByName(iWeapon, "slow enemy on hit major", 1.0);
					TF2Attrib_SetByName(iWeapon, "halloween increased jump height", 1.4);
				}
			}
/* 			case TFClass_Soldier:
			{

			} */
			case TFClass_Pyro:
			{
				iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
				if(iWeapon >= 1)
				{
					TF2Attrib_SetByName(iWeapon, "weapon burn time increased", 1.8);
					TF2Attrib_SetByName(iWeapon, "weapon burn dmg increased", 1.4);
				}
			}
/* 			case TFClass_DemoMan:
			{
		
			}
			case TFClass_Heavy:
			{
			
			} */
			case TFClass_Engineer:
			{
				iWeapon = GetPlayerWeaponSlot(iClient, TFWepSlot_PDA_Build);
				if(iWeapon >= 1)
				{
					TF2Attrib_SetByName(iWeapon, "metal regen", 20.0);
				}
			}
/* 			case TFClass_Medic:
			{

			}
			case TFClass_Sniper:
			{

			}
			case TFClass_Spy:
			{

			} */
		}
	}
}

// stun players when they get jarated
public TF2_OnConditionAdded(client, TFCond:cond)
{
	if(GetClientTeam(client) == _:TFTeam_Blue && bRoundActive && cond == TFCond_Jarated)
	{
		TF2_StunPlayer(client, 5.0, 0.0, TF_STUNFLAG_LIMITMOVEMENT|TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_THIRDPERSON);
	}
}

/* public TF2_OnConditionRemoved(client, TFCond:cond)
{
	// is RED, finished taunt and is soldier
    if (GetClientTeam(client) == _:TFTeam_Red && cond == TFCond_Taunting && GetEntProp(client, Prop_Send, "m_iClass") == 3)
    {
        SetEntPropFloat(client, Prop_Send, "m_flRageMeter", 100.0);
    }
} */

stock SpawnWeapon(client,String:name[],index,level,qual,String:att[], bool:bWearable = false)
{
	new Handle:hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	new String:atts[32][32];
	new count = ExplodeString(att, " ; ", atts, 32, 32);
	if (count > 0)
	{
		TF2Items_SetNumAttributes(hWeapon, count/2);
		new i2 = 0;
		for (new i = 0; i < count; i+=2)
		{
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else
		TF2Items_SetNumAttributes(hWeapon, 0);
	if (hWeapon==INVALID_HANDLE)
		return -1;
	new entity = TF2Items_GiveNamedItem(client, hWeapon);
	CloseHandle(hWeapon);
	if( IsValidEdict( entity ) )
	{
		if( bWearable )
		{
			TF2_EquipPlayerWearable(client, entity);
		}
		else
			EquipPlayerWeapon( client, entity );
	}
	return entity;
}