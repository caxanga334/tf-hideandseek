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
#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include "hideandseek/mapsupport.sp"
#include "hideandseek/spawnpoints.sp"
#include "hideandseek/functions.sp"

#define PLUGIN_VERSION "0.0.7"
#define PLUGIN_STATE "ALPHA"

/********BOOLEANS********/
bool g_bBLUFrozen; // Is BLU team frozen?
bool g_bWasBLU[MAXPLAYERS + 1]; // player started on BLU team?
bool g_bSelected[MAXPLAYERS + 1]; // player who were selected for the current round

/********INTEGERS********/
int g_iRoundTime;
int g_iRoundInitialTime;
int g_iTeam[MAXPLAYERS + 1]; // remember player's team
int g_iCampStrikes[MAXPLAYERS + 1]; // how many camp strikes players received
int g_iKillCounter[MAXPLAYERS + 1];
int g_iPSState; // BLU selection state
int g_iHASState; // game state

/********FLOATS********/
float flLastTimeAnn = 0.0;

/********CHAR********/


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
ConVar c_svTag; // server tags

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

enum
{
	HAS_State_NONE = -1, // initial state on map load
	HAS_State_WFP = 0, // waiting for players
	HAS_State_NEP = 1, // not enough players
	HAS_State_READY = 2, // game is ready to start
	HAS_State_SETUP = 3, // round is in setup
	HAS_State_ACTIVE = 4, // round is active
};

 
public Plugin myinfo =
{
	name = "[TF2] Hide and Seek",
	author = "caxanga334",
	description = "Hide and Seek plugin for TF2",
	version = PLUGIN_VERSION,
	url = "https://github.com/caxanga334/"
}

stock APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char gamefolder[32]
	GetGameFolderName(gamefolder, sizeof(gamefolder));
	if(!StrEqual(gamefolder, "tf")
	{
		LogError("This plugin is for TF2 only!");
		return APLRes_Failure;
	}
	else
	{
		return APLRes_Success;
	}
}
 
public void OnPluginStart()
{	
	SP_BuildPath();
	MS_BuildPath();
	
	HookEvent( "player_spawn", E_PlayerSpawn );
	HookEvent( "player_death", E_PlayerDeath );
	HookEvent( "teamplay_round_start", E_RoundStart );
	HookEvent( "post_inventory_application", E_PostInventoryApplication );
	HookEvent( "player_builtobject", E_BuildObject, EventHookMode_Pre );
	
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
	RegAdminCmd("sm_has_debug", Command_Debug, ADMFLAG_ROOT, "Print debug info");
	
	// convars
	CreateConVar("sm_hideandseek_version", PLUGIN_VERSION, "Hide and Seek plugin version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
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
	
	c_svTag = FindConVar("sv_tags");
	
	// convar hooks
	if( c_svTag != null )
	{
		c_svTag.AddChangeHook(OnTagsChanged);
	}
	
	AutoExecConfig(true, "plugin.hideandseek");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "SteamWorks", false))
	{
		SteamWorks_SetGameDescription("Hide and Seek");
	}
}

public void OnMapStart()
{
	if(LibraryExists("SteamWorks"))
		SteamWorks_SetGameDescription("Hide and Seek");
		
	SP_LoadConfig();
	MS_LoadConfig();
	g_iPSState = 0; // state 0, nobody joined BLU
	g_iHASState = HAS_State_NONE;
	AddPluginTag("HAS");
	
	// Precache
	PrecacheSound("vo/announcer_AM_LastManAlive01.mp3");
	PrecacheSound("vo/announcer_ends_60sec.mp3");
	PrecacheSound("vo/announcer_ends_30sec.mp3");
	PrecacheSound("vo/announcer_ends_10sec.mp3");
	PrecacheSound("vo/announcer_ends_5sec.mp3");
	PrecacheSound("vo/announcer_ends_4sec.mp");
	PrecacheSound("vo/announcer_ends_3sec.mp3");
	PrecacheSound("vo/announcer_ends_2sec.mp");
	PrecacheSound("vo/announcer_ends_1sec.mp");
}

public void TF2_OnWaitingForPlayersStart() {
	g_iHASState = HAS_State_WFP; // waiting for players
	LogMessage("TF2 Waiting For Players started.");
}

public void TF2_OnWaitingForPlayersEnd() {
	g_iHASState = HAS_State_NEP; // waiting for players ended
	LogMessage("TF2 Waiting For Players ended.");
}

/****************************************************
				CONVAR FUNCTIONS
*****************************************************/

public void OnTimeConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iRoundTime = sm_has_round_time.IntValue;
}

public void OnCampConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iMaxCampStrikes = sm_has_camp_strikes.IntValue;
}

public void OnAnnConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_flTimeAnnCooldown = sm_has_time_remaining.FloatValue;
}

public void OnRTKRConVarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	cvar_iRTKillReduction = sm_has_camp_strikes.IntValue;
}

public void OnScrambleTeamChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}

public void OnAutoTeamBalanceChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}

public void OnTeamBalanceChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) != 0)
	{
		convar.IntValue = 0;
	}
}

public void OnTagsChanged(ConVar convar, char[] oldValue, char[] newValue)
{
	AddPluginTag("HAS");
}

/****************************************************
					COMMANDS
*****************************************************/

// Commands
public Action command_suicide(int client, const char[] command, int argc)
{
	if(g_iHASState == HAS_State_ACTIVE)
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
	int iTimeRemaining = GetRemainingTime();
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

public Action Command_Debug(int client, int args)
{
	char gamestate[64];
	
	ReplyToCommand(client, "===Hide and Seek Debug===");
	
	switch( g_iHASState )
	{
		case HAS_State_NONE:
		{
			gamestate = "NONE";
		}
		case HAS_State_WFP:
		{
			gamestate = "WAITING FOR PLAYERS";
		}
		case HAS_State_NEP:
		{
			gamestate = "NOT ENOUGH PLAYERS";
		}
		case HAS_State_READY:
		{
			gamestate = "READY";
		}
		case HAS_State_SETUP:
		{
			gamestate = "ROUND SETUP";
		}
		case HAS_State_ACTIVE:
		{
			gamestate = "ROUND ACTIVE";
		}
	}
	
	ReplyToCommand(client, "Game State: %s", gamestate);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			if(g_bWasBLU[i] == true)
			{
				ReplyToCommand(client, "Player %N Was BLU: True", i);
			}
			else
			{
				ReplyToCommand(client, "Player %N Was BLU: False", i);
			}
		}
	}
}

/****************************************************
					MENUS
*****************************************************/

/****************************************************
				EVENT FUNCTIONS
*****************************************************/

public Action E_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	int iKiller = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(g_iHASState == HAS_State_ACTIVE) {
		// RED player died during while the round is active, move him/her to BLU.
		if(iKiller >= 1) {
			if(GetClientTeam(iClient) == view_as<int>(TFTeam_Red) && IsClientInGame(iKiller)) {
				TF2_ChangeClientTeam(iClient, TFTeam_Blue);
				g_iTeam[iClient] = 3;
				g_iKillCounter[iKiller]++; // add 1 kill
			}
			
			if(GetClientTeam(iClient) == view_as<int>(TFTeam_Blue) && GetClientTeam(iKiller) == view_as<int>(TFTeam_Red) && IsClientInGame(iKiller)) {
				if(cvar_iRTKillReduction >= 1) {
					g_iRoundTime = g_iRoundTime - cvar_iRTKillReduction;
				}
			}			
		}
		else if(iKiller == 0 && GetRunningTime() > 15) {
			CreateTimer(0.1, Timer_MovetoBLU, iClient, TIMER_FLAG_NO_MAPCHANGE);
		}
		CheckPlayers();
	}
}

public Action E_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	if(g_iHASState == HAS_State_ACTIVE) // round is active
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
	if(g_iHASState >= HAS_State_READY)
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

public Action E_PostInventoryApplication(Event event, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_iHASState >= HAS_State_READY)
	{
		PrepareWeapons(iClient);
	}
}

public Action E_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrepareMap();
	CheckPlayers();
	if(g_iHASState >= HAS_State_READY)
	{
		// reset player's team
		for (int i = 1; i <= MaxClients; i++)
		{
			g_iTeam[i] = 0;
			// g_bInSpawn[i] = true;
		}
		CreateTimer(2.0, Timer_RoundStart);
	}
}

public Action E_BuildObject(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int index = event.GetInt("index");
	if( !IsFakeClient(client) && GetEntProp( index, Prop_Send, "m_iTeamNum" ) == view_as<int>(TFTeam_Red) )
	{
		CreateTimer(0.1, Timer_BuildObject, index);
	}
}

/****************************************************
				ROUND FUNCTIONS
*****************************************************/
// functions to manage rounds

void SetRoundTime()
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
	LogMessage("[DEBUG] Round Time: %i, RT Cvar: %i, Add Per Player: %i, Players: %i, Freeze: %i", g_iRoundTime, cvar_iRoundTime, iAddPerPlayer, iPlayers, iFreezeTime);
	
	if(g_iRoundTime > GetTime() + sm_has_round_time_cap.IntValue)
	{
		g_iRoundTime = GetTime() + sm_has_round_time_cap.IntValue + iFreezeTime;
	}
/* 	else
	{
		g_iRoundTime = GetTime() + cvar_iRoundTime; // fail-safe
		LogError("An error occurred during round time calculation.");
	} */

	
	g_iRoundInitialTime = GetTime();
	flLastTimeAnn = GetGameTime() + cvar_flTimeAnnCooldown;
}

// starts a new round
void StartNewRound()
{
	g_iHASState = HAS_State_SETUP;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_iCampStrikes[i] = 0;
			g_iKillCounter[i] = 0;
			g_bSelected[i] = false;
		}
	}
	CreateTeams();
}

// This function will move players to form teams.
void CreateTeams()
{
	int iTarget;
	int iMaxBLU = GetInitialBLUPlayers();
	
	// select BLU players and store on g_iTeam
	for (int i = 1; i <= iMaxBLU; i++)
	{
		LogMessage("BLU Selection: i = %d", i);
		iTarget = GetRandomPlayer();
		if(IsClientInGame(iTarget))
		{
			g_iTeam[iTarget] = 3; // BLU
			g_bWasBLU[iTarget] = true;
			g_bSelected[iTarget] = true;
			LogMessage("Player %L was selected to play on BLU team", iTarget);
			CPrintToChat(iTarget,"%t", "Selected BLU");
		}
	}
	// assign players to a team
	for (int i = 1; i <= MaxClients; i++)
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
				// g_bWasBLU[i] = false;
			}
		}
	}
	CreateTimer(2.0, ActiveRound);
}
 
public Action ActiveRound(Handle timer)
{
	//respawns dead players after moving them
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) >= 2) // checks for dead RED/BLU players at round start.
		{
			TF2_RespawnPlayer(i); // respawns them.
		}
	}
	// RED = 2 | BLU = 3
	if(GetTeamClientCount(3) <= 0) // round is about to start but BLU is empty
	{
		int iTarget = GetRandomPlayer();
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

	g_iHASState = HAS_State_ACTIVE;

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(GetClientTeam(i) == view_as<int>(TFTeam_Blue))
			{
				CPrintToChat(i,"%t", "You Seek");// round start message
			}
			else if(GetClientTeam(i) == view_as<int>(TFTeam_Red))
			{
				CPrintToChat(i,"%t", "You Hide");// round start message
			}
		}
	}
	SetRoundTime();
	FreezePlayers();
	int iRoundDuration = GetRemainingTime();
	CPrintToChatAll("%t", "Round Start", iRoundDuration);// round start message
	CreateTimer(15.0, Timer_SetTeamRoundTimer);
	
	if(g_iPSState == 1) // reset g_bWasBLU
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			g_bWasBLU[i] = false;
		}
		g_iPSState = 0; // set state to 0
	}
	
	return Plugin_Stop;
}

void EndRound(int iWinner)
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
	g_iHASState = HAS_State_READY;
	
	int iFlags = GetCommandFlags("mp_forcewin");
	SetCommandFlags( "mp_forcewin", iFlags & ~FCVAR_CHEAT );
	ServerCommand( "mp_forcewin %i", iWinner );
	
	for (int i = 1; i <= MaxClients; i++)
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

public Action Timer_Announce(Handle timer)
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

public Action Timer_CheckForPlayers(Handle timer)
{
	CheckPlayers();
}

public Action Timer_RoundStart(Handle timer)
{
	StartNewRound();
	return Plugin_Stop;
}

public Action Timer_UnfreezeBLU(Handle timer)
{
	g_bBLUFrozen = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TFTeam_Blue))
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
		int iTimeRemaining = g_iRoundTime - GetTime();
		CPrintToChatAll("%t", "Round Time", iTimeRemaining);
	}
	
	int iTime = GetRemainingTime();
	switch( iTime )
	{
		case 60: EmitGameSoundToAll("Announcer.RoundEnds60seconds");
		case 30: EmitGameSoundToAll("Announcer.RoundEnds30seconds");
		case 10: EmitGameSoundToAll("Announcer.RoundEnds10seconds");
		case 5: EmitGameSoundToAll("Announcer.RoundEnds5seconds");
		case 4: EmitGameSoundToAll("Announcer.RoundEnds4seconds");
		case 3: EmitGameSoundToAll("Announcer.RoundEnds3seconds");
		case 2: EmitGameSoundToAll("Announcer.RoundEnds2seconds");
		case 1: EmitGameSoundToAll("Announcer.RoundEnds1seconds");
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
	if(g_iHASState == HAS_State_ACTIVE || cvar_iMaxCampStrikes == 0) // round is not active OR camp strike is disabled, do nothing
	{
		return Plugin_Continue;
	}
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && GetClientTeam(i) == view_as<int>(TFTeam_Red) && GetRunningTime() > 30)
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

public Action Timer_MovetoBLU(Handle timer, any iClient)
{
	TF2_ChangeClientTeam(iClient, TFTeam_Blue);
	IsLastRED();
	return Plugin_Stop;
}

public Action Timer_BuildObject(Handle timer, any index)
{
	char classname[32];
	
	if( IsValidEdict(index) )
	{
		GetEdictClassname(index, classname, sizeof(classname))
		
		if( strcmp(classname, "obj_dispenser", false) == 0 )
		{
			SetEntProp(index, Prop_Send, "m_bMiniBuilding", 1);
			SetEntPropFloat(index, Prop_Send, "m_flModelScale", 0.90);
			SetVariantInt(100);
			AcceptEntityInput(index, "SetHealth");			
		}
	}
	
	return Plugin_Stop;
}

public Action Timer_SetTeamRoundTimer(Handle timer)
{
	MS_AddTime();
	return Plugin_Stop;
}

/****************************************************
				PLAYER FUNCTIONS
*****************************************************/

public OnClientConnected(iTarget)
{
	if(g_iHASState == HAS_State_ACTIVE)
	{
		g_iTeam[iTarget] = view_as<int>(TFTeam_Blue); // Assign players to BLU team if they connect after round setup
		g_bWasBLU[iTarget] = false;
		g_bSelected[iTarget] = false;
		g_iKillCounter[iTarget] = 0;
	}
}

public OnClientDisconnect(iTarget)
{
	g_iTeam[iTarget] = view_as<int>(TFTeam_Unassigned);
	g_bWasBLU[iTarget] = false;
	g_bSelected[iTarget] = false;
	g_iKillCounter[iTarget] = 0;
	CheckPlayers();
}

// selects a random player to join BLU
// state 0: none or some players joined BLU, select those who didn't joined BLU before
// state 1: all players joined BLU, select random players.
int GetRandomPlayer()
{
	int players_available[MAXPLAYERS+1];
	int counter = 0; // counts how many valid players we have
	for (int i = 1; i <= MaxClients; i++)
	{
		// Ignore players who was selected to start on BLU last round.
		if (IsClientInGame(i) && !IsFakeClient(i) && g_bWasBLU[i] == false)
		{
			players_available[counter] = i; // stores the client userid
			counter++;
		}
	}
	
	// all available players already played on BLU
	if(counter == 0)
	{
		LogMessage("DEBUG: All players already played on BLU, resetting...");
		g_iPSState = 1; // state 1, all players joined BLU
		for (int i = 1; i <= MaxClients; i++)
		{
			// Ignore players who were already selected for the current round. 
			if (IsClientInGame(i) && !IsFakeClient(i) && g_bSelected[i] == false) 
			{
				players_available[counter] = i; // stores the client userid
				counter++;
			}
		}
	}
	
	// now we should have an array filled with user ids and exactly how many players we have in game.
	int iRandomMax = counter - 1;
	int iRandom = GetRandomInt(0,iRandomMax); // get a random number between 0 and counted players
	// now we get the user id from the array cell selected via iRandom
	//CPrintToChatAll("DEBUG: iRandom: %d ,UserID: %d , iRandomMax: %d", iRandom, players_available[iRandom], iRandomMax);
	LogMessage("DEBUG: iRandom: %d ,UserID: %d , iRandomMax: %d", iRandom, players_available[iRandom], iRandomMax);
	return players_available[iRandom];
}

public void TF2Spawn_EnterSpawn( iClient, iEntity )
{
	if(g_iHASState == HAS_State_ACTIVE && IsClientInGame(iClient) && IsPlayerAlive(iClient) && !IsFakeClient(iClient) && GetClientTeam(iClient) == view_as<int>(TFTeam_Red))
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
void CheckPlayers()
{
	// RED = 2 | BLU = 3
	int iRed = GetTeamClientCount(2);
	int iBlue = GetTeamClientCount(3);
	// game is in progress
	if(g_iHASState == HAS_State_ACTIVE)
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
	else if(g_iHASState == HAS_State_NEP) // not playing and not enough players
	{
		if(iRed + iBlue >= 2) // we have 2 players in game
		{
			g_iHASState = HAS_State_READY; // set ready to play
			//ServerCommand("mp_restartround 5"); // restarts round
			EndRound(0); // stalemate
			LogMessage("We have 2 or more players, starting hide and seek.")
		}
	}
	else if(g_iHASState >= HAS_State_READY && iRed + iBlue < 2) // game is ready but we have 1 or less players
	{
		g_iHASState = HAS_State_NEP; // not enough players
		LogMessage("1 or less players, game state changed to not enough players")
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

void FreezePlayers() {
	sm_has_freeze_duration = FindConVar("sm_has_freeze_duration");
	if (sm_has_freeze_duration != null) {
		g_bBLUFrozen = true;
		
		CreateTimer(sm_has_freeze_duration.FloatValue, Timer_UnfreezeBLU);
		
		int iFreezeTime;
		iFreezeTime = RoundToNearest(sm_has_freeze_duration.FloatValue);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i) == view_as<int>(TFTeam_Blue))
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
	int iTimeRemaining = g_iRoundTime - GetTime();
	if(g_iHASState == HAS_State_ACTIVE)
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
	int iRunningTime = GetTime() - g_iRoundInitialTime;
	if(g_iHASState == HAS_State_ACTIVE)
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

// stun players when they get jarated
public TF2_OnConditionAdded(int client, TFCond cond)
{
	if(GetClientTeam(client) == view_as<int>(TFTeam_Blue) && g_iHASState == HAS_State_ACTIVE && cond == TFCond_Jarated)
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

// add plugin tag to sv_tags
void AddPluginTag(const char[] tag)
{
	char tags[255];
	c_svTag.GetString(tags, sizeof(tags));

	if (!(StrContains(tags, tag, false)>-1))
	{
		char newTags[255];
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag);
		c_svTag.SetString(newTags, _, true);
		c_svTag.GetString(tags, sizeof(tags));
	}
}