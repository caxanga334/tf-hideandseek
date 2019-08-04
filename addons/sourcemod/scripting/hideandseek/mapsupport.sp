// global variables
int iRemoveDoors;

char MapSupportFile[PLATFORM_MAX_PATH];

stock MS_BuildPath()
{
	BuildPath(Path_SM, MapSupportFile, sizeof(MapSupportFile), "configs/hideandseek/map_settings.cfg");
	MS_LoadConfig();
}

stock MS_LoadConfig()
{
	// reset globals
	iRemoveDoors = 0;
	
	char CurrentMap[MAX_NAME_LENGTH];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	if(!FileExists(MapSupportFile))
	{
		SetFailState("Configuration file %s not found!", MapSupportFile);
		return;
	}

	KeyValues kv = new KeyValues("MapSettings");
	kv.ImportFromFile(MapSupportFile);
	
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
			iRemoveDoors = kv.GetNum("deletealldoors", 0);
		}
	} while (kv.GotoNextKey());
	
	delete kv;
}

/* Function to prepare the map for hide and seek */
stock PrepareMap() {
	int i = -1;
	while ((i = FindEntityByClassname(i, "trigger_capture_area")) != -1)
	{
		if(IsValidEntity(i))
		{
			AcceptEntityInput(i, "Disable");
		} 
	}
	while ((i = FindEntityByClassname(i, "item_teamflag")) != -1)
	{
		if(IsValidEntity(i))
		{
			AcceptEntityInput(i, "Kill");
		} 
	}
	while ((i = FindEntityByClassname(i, "func_capturezone")) != -1)
	{
		if(IsValidEntity(i))
		{
			AcceptEntityInput(i, "Disable");
		} 
	}
	while ((i = FindEntityByClassname(i, "team_control_point")) != -1)
	{
		if(IsValidEntity(i))
		{
			SetVariantInt(1);
			AcceptEntityInput(i, "SetLocked");
		} 
	}
	while ((i = FindEntityByClassname(i, "team_control_point_master")) != -1)
	{
		if(IsValidEntity(i))
		{
			AcceptEntityInput(i, "Disable");
		} 
	}
	while ((i = FindEntityByClassname(i, "team_round_timer")) != -1)
	{
		if(IsValidEntity(i))
		{
			SetVariantInt(0);
			AcceptEntityInput(i, "SetSetupTime");
		} 
	}
	while ((i = FindEntityByClassname(i, "func_respawnroomvisualizer")) != -1)
	{
		if(IsValidEntity(i))
		{
			AcceptEntityInput(i, "Kill");
		} 
	}
	while ((i = FindEntityByClassname(i, "func_regenerate")) != -1)
	{
		if(IsValidEntity(i) && GetEntProp(i, Prop_Send, "m_iTeamNum") == 2) // func_regenerate belongs to RED team.
		{
			AcceptEntityInput(i, "Kill");
		} 
	}
	if(iRemoveDoors == 1)
	{
		while ((i = FindEntityByClassname(i, "func_door")) != -1)
		{
			if(IsValidEntity(i))
			{
				AcceptEntityInput(i, "Kill");
			} 
		}
	}
}

void MS_AddTime()
{
	int i = -1;
	while ((i = FindEntityByClassname(i, "team_round_timer")) != -1)
	{
		if(IsValidEntity(i))
		{
			SetVariantInt(9999);
			AcceptEntityInput(i, "AddTime");
		} 
	}
}