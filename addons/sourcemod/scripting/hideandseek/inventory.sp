// remove items from the player
void StripItems( int client )
{	
	if( !IsClientInGame(client) || IsFakeClient( client ) || !IsPlayerAlive( client ) )
		return;
		
	int iEntity;
	int iOwner;
	iEntity = -1;
	while( ( iEntity = FindEntityByClassname( iEntity, "tf_wearable_demoshield" ) ) > MaxClients )
	{
		iOwner = GetEntPropEnt( iEntity, Prop_Send, "m_hOwnerEntity" );
		if( iOwner == client )
		{
			TF2_RemoveWearable( client, iEntity );
			AcceptEntityInput( iEntity, "Kill" );
		}
	}
	
	iEntity = -1;
	while( ( iEntity = FindEntityByClassname( iEntity, "tf_wearable_razorback" ) ) > MaxClients )
	{
		iOwner = GetEntPropEnt( iEntity, Prop_Send, "m_hOwnerEntity" );
		if( iOwner == client )
		{
			TF2_RemoveWearable( client, iEntity );
			AcceptEntityInput( iEntity, "Kill" );
		}
	}
	
	TF2_RemoveAllWeapons(client);
	// bug: sappers and toolboxes
}

// use TF2Items for giving weapons
int SpawnWeapon(int client,char[] name,int index,int level,int qual,bool bWearable = false)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	
	if (hWeapon==null)
		return -1;
		
	int entity = TF2Items_GiveNamedItem(client, hWeapon);
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

void PrepareWeapons(int iClient)
{
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	TFClassType iClass = TF2_GetPlayerClass( iClient );
	//new iIndex; // item definition index
	int iWeapon; // weapon entity index
	
	if(iTeam == TFTeam_Red)
	{
		// remove weapons
		StripItems( iClient );
		
		switch( iClass )
		{
			case TFClass_Scout:
			{
				SpawnWeapon( iClient, "tf_weapon_jar_milk", 222, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_bat", 0, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.60);
			}
			case TFClass_Soldier:
			{
				SpawnWeapon( iClient, "tf_weapon_buff_item", 354, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_katana", 357, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage bonus", 1.25);
			}
			case TFClass_Pyro:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_fireaxe", 348, 1, 0, false); // Sharpened Volcano Fragment
				TF2Attrib_SetByName(iWeapon, "damage bonus", 1.30);
			}
			case TFClass_DemoMan:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_katana", 357, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "melee attack rate bonus", 1.15);
			}
			case TFClass_Heavy: 
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_lunchbox", 42, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_fists", 656, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage bonus", 1.80);
				TF2Attrib_SetByName(iWeapon, "melee attack rate bonus", 1.20);
			}
			case TFClass_Engineer:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_robot_arm", 142, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_pda_engineer_build", 25, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "mod teleporter cost", 2.0);
				SpawnWeapon( iClient, "tf_weapon_pda_engineer_destroy", 26, 1, 0, false);
				SpawnWeapon( iClient, "tf_weapon_builder", 28, 1, 0, false);
			}
			case TFClass_Medic:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_bonesaw", 304, 1, 0, false);
			}
			case TFClass_Sniper:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_jar", 58, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_club", 3, 1, 0, false);
			}
			case TFClass_Spy:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_knife", 4, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "disguise on backstab", 1.0);
				TF2Attrib_SetByName(iWeapon, "silent killer", 1.0);
				SpawnWeapon( iClient, "tf_weapon_builder", 735, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_invis", 30, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "mult cloak meter regen rate", 0.70);
			}
		}	
	}
}

// charges RED soldier's banners
void HS_RED_ChargeBanner(float flAmount = 1.0)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if( IsValidClient(i) )
		{
			if( IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red && TF2_GetPlayerClass(i) == TFClass_Soldier )
			{
				if( !TF2_IsPlayerInCondition(i, TFCond_DefenseBuffed ) )
				{
					float flCharge = GetEntPropFloat(i, Prop_Send, "m_flRageMeter");
					flCharge += flAmount;
					SetEntPropFloat(i, Prop_Send, "m_flRageMeter", flCharge);
				}
			}
		}
	}
}