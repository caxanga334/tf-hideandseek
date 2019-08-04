ArrayList array_bluspawns;
ArrayList array_redspawns;

int iMaxREDSP, iMaxBLUSP;

bool bSpawnPointsRED; // does the current map have spawn points?
bool bSpawnPointsBLU; // does the current map have spawn points?

char g_strConfigFile[PLATFORM_MAX_PATH];

stock SP_BuildPath()
{
	BuildPath(Path_SM, g_strConfigFile, sizeof(g_strConfigFile), "configs/hideandseek/spawnpoints.cfg");
	array_bluspawns = new ArrayList(3);
	array_redspawns = new ArrayList(3);
	SP_LoadConfig();
}

stock SP_LoadConfig()
{
	char CurrentMap[MAX_NAME_LENGTH];
	char CfgOrigin[16];
	float Origin[3];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	array_redspawns.Clear();
	array_bluspawns.Clear();
	bSpawnPointsRED = false;
	bSpawnPointsBLU = false;
	
	if(!FileExists(g_strConfigFile))
	{
		SetFailState("Configuration file %s not found!", g_strConfigFile);
		return;
	}

	KeyValues kv = new KeyValues("SpawnPoints");
	kv.ImportFromFile(g_strConfigFile);
	
	// Jump into the first subsection
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
	}
	
	// Iterate over subsections at the same nesting level
	char buffer[255];
	do
	{
		kv.GetSectionName(buffer, sizeof(buffer));
		if (StrEqual(buffer, CurrentMap))
		{
			LogMessage("Found SpawnPoints. Map: %s Buffer: %s", CurrentMap, buffer);
			// RED
			if(kv.JumpToKey("red", false))
			{
				iMaxREDSP = kv.GetNum("max");
				bSpawnPointsRED = true;
				for (int i = 1; i <= iMaxREDSP; i++)
				{
					Format(CfgOrigin, sizeof(CfgOrigin), "origin%i", i);
					kv.GetVector(CfgOrigin, Origin);
					array_redspawns.PushArray(Origin);
				}
				kv.GoBack();
			}
			// BLU
			if(kv.JumpToKey("blue", false))
			{
				iMaxBLUSP = kv.GetNum("max");
				bSpawnPointsBLU = true;
				for (int i = 1; i <= iMaxBLUSP; i++)
				{
					Format(CfgOrigin, sizeof(CfgOrigin), "origin%i", i);
					kv.GetVector(CfgOrigin, Origin);
					array_bluspawns.PushArray(Origin);
				}
				kv.GoBack();
			}
		}
	} while (kv.GotoNextKey());
	
	delete kv;
}

// this functions teleports a player to a random origin from the config file
stock SP_TeleportPlayer(int iClient, int iTeam)
{
	int iTarget;
	float origin[3];
	if(iTeam == 2)
	{
		iTarget = GetRandomInt(0, iMaxREDSP - 1);
		array_redspawns.GetArray(iTarget, origin);
	}
	else if(iTeam == 3)
	{
		iTarget = GetRandomInt(0, iMaxBLUSP - 1);
		array_bluspawns.GetArray(iTarget, origin);
	}
	TeleportEntity(iClient, origin, NULL_VECTOR, NULL_VECTOR);
}

// spawn points available?
bool SP_Available_RED()
{
	if(bSpawnPointsRED)
	{
		return true
	}
	else
	{
		return false
	}
}
bool SP_Available_BLU()
{
	if(bSpawnPointsBLU)
	{
		return true
	}
	else
	{
		return false
	}
}
