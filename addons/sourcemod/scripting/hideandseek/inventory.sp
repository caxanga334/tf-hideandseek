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
			case TFClass_Scout: // cleaver causes knockback, slow recharge
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_cleaver", 812, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "effect bar recharge rate increased", 4.5);
				TF2Attrib_SetByName(iWeapon, "apply look velocity on damage", 250.0);
				TF2Attrib_SetByName(iWeapon, "apply z velocity on damage", 250.0);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_bat", 0, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
				CPrintToChat( iClient, "%t", "class red scout");
			}
			case TFClass_Soldier: // to do: soldier
			{
				SpawnWeapon( iClient, "tf_weapon_shovel", 6, 1, 0, false);
			}
			case TFClass_Pyro: // slows down enemy on hit
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_fireaxe", 348, 1, 0, false); // Sharpened Volcano Fragment
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
				TF2Attrib_SetByName(iWeapon, "slow enemy on hit major", 3.0);
				CPrintToChat( iClient, "%t", "class red pyro");
			}
			case TFClass_DemoMan:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_bottle", 1, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
			}
			case TFClass_Heavy: // reduced damage from ranged sources
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_lunchbox", 42, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "mult_item_meter_charge_rate", 2.5);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_fists", 656, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.5);
				TF2Attrib_SetByName(iWeapon, "dmg from ranged reduced", 0.5);
				TF2Attrib_SetByName(iWeapon, "speed_boost_on_hit", 3.0);
			}
			case TFClass_Engineer:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_robot_arm", 142, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_pda_engineer_build", 25, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "metal regen", 10.0);
				TF2Attrib_SetByName(iWeapon, "engy sentry damage bonus", 0.25);
				TF2Attrib_SetByName(iWeapon, "engy building health bonus", 0.4);
				TF2Attrib_SetByName(iWeapon, "mod teleporter cost", 2.0);
				SpawnWeapon( iClient, "tf_weapon_pda_engineer_destroy", 26, 1, 0, false);
				SpawnWeapon( iClient, "tf_weapon_builder", 28, 1, 0, false);
			}
			case TFClass_Medic:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_bonesaw", 304, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
			}
			case TFClass_Sniper:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_jar", 58, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "effect bar recharge rate increased", 2.5);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_club", 3, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "damage penalty", 0.25);
				CPrintToChat( iClient, "%t", "class red sniper");
			}
			case TFClass_Spy:
			{
				iWeapon = SpawnWeapon( iClient, "tf_weapon_knife", 4, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "disguise on backstab", 1.0);
				TF2Attrib_SetByName(iWeapon, "silent killer", 1.0);
				SpawnWeapon( iClient, "tf_weapon_builder", 735, 1, 0, false);
				iWeapon = SpawnWeapon( iClient, "tf_weapon_invis", 30, 1, 0, false);
				TF2Attrib_SetByName(iWeapon, "mult cloak meter regen rate", 0.45);
				TF2Attrib_SetByName(iWeapon, "SET BONUS: quiet unstealth", 1.0);
				TF2Attrib_SetByName(iWeapon, "NoCloakWhenCloaked", 1.0);
				TF2Attrib_SetByName(iWeapon, "ReducedCloakFromAmmo", 0.8);
			}
		}
		// global RED attributes
		iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if(iWeapon >= 1)
		{
			TF2Attrib_SetByName(iWeapon, "health from packs decreased", 0.50);
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
					TF2Attrib_SetByName(iWeapon, "halloween increased jump height", 1.4);
				}
			}
			case TFClass_Soldier:
			{
				iWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
				if(iWeapon >= 1)
				{
					TF2Attrib_SetByName(iWeapon, "rocket specialist", 2.0);
				}
			}
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
				TF2Attrib_SetByName(iClient, "metal regen", 20.0);
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