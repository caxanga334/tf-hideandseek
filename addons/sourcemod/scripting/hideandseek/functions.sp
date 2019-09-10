// functions that doens't use global vars.

// announces to the last RED player he is the last one alive
void IsLastRED()
{
	if( GetTeamClientCount(view_as<int>(TFTeam_Red)) == 1 )
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if( IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red )
			{
				EmitGameSoundToClient(i, "Announcer.AM_LastManAlive01");
			}
		}
	}
}