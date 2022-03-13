#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>

public Plugin myinfo =
{
	name = "Trolling mod",
	author = "Awnar",
	description = "Plugin do trollowania graczy, poprzez redukcje zadawanych przez nich obrażeń",
	version = "1.0",
	url = "https://github.com/Awnar/CS-GO-Troll"
};

StringMap cheaters = null;
int t_Target[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegAdminCmd("sm_troll", CMD_troll, ADMFLAG_ROOT);
	RegAdminCmd("sm_troll_reset", CMD_reset, ADMFLAG_ROOT);
	RegAdminCmd("sm_troll_info", CMD_info, ADMFLAG_ROOT);
	cheaters = new StringMap();
}

////////////////////////////////////////////////////
//commands
////////////////////////////////////////////////////

public Action CMD_reset(int client, int args)
{
	cheaters.Clear();
	return Plugin_Handled;
}

public Action CMD_info(int client, int args)
{
	PrintToConsole(client, "%i graczy", cheaters.Size);
	StringMapSnapshot tmp = cheaters.Snapshot();
	for (int i = 0; i < tmp.Length; i++)
	{
		char id[32];
		tmp.GetKey(i, id, sizeof(id));
		
		char name[MAX_NAME_LENGTH];
		GetClientName(CheckClientOnline(id), name, sizeof(name));
		
		int status = -1;
		cheaters.GetValue(id, status)
		
		PrintToConsole(client, "%s %i %s", name, status, id);
	}
	return Plugin_Handled;
}

public Action CMD_troll(int client, int args)
{
	if(client == 0 || !IsClientInGame(client))
		return Plugin_Handled;
		
	if (args <= 0)
	{
		Players(client);
	}
	else if (args == 1)
	{
		char arg1[64];
		GetCmdArg(1,arg1,sizeof(arg1));
		
		if(StrEqual(arg1, "man"))
		{
			PrintToConsole(client, "Komenda:	sm_troll 	- uruchamia menu wyboru kogo trollować");
			PrintToConsole(client, "Komenda:	sm_troll [info|reset]	- parametr info pokazuje obecnie trolowanych graczy (nick, typ, steamID), parametr reset resetuje obecne ustawienia");
			PrintToConsole(client, "Komenda:	sm_troll_reset 	- patrz wyżej");
			PrintToConsole(client, "Komenda:	sm_troll_info 	- patrz wyżej");
			PrintToConsole(client, "Komenda:	sm_troll [<typ> <#userid|name>]	- troluje wskazanego gracza, na sposób określony w typie");
			PrintToConsole(client, "Typy:");
			PrintToConsole(client, "	0 	normalne obrażenia");
			PrintToConsole(client, "	1 	brak obrażeń");
			PrintToConsole(client, "	2 	1/2 obrażeń");
			PrintToConsole(client, "	3 	leczenie");	
			PrintToConsole(client, "	-1 	błąd przywrócenie ustawień domyślnych");
		} 
		else if(StrEqual(arg1, "info"))
		{
			CMD_info(client, 0);
		} 
		else if(StrEqual(arg1, "reset"))
		{
			CMD_reset(client, 0);
		}
	}
	else
	{
		char arg1[5];
		char arg2[100];
		GetCmdArg(1,arg1,sizeof(arg1));
		GetCmdArg(2,arg2,sizeof(arg2));
			
		char steamid[32];
		if(GetClientAuthId(FindTarget(client, arg2, false, false), AuthId_Steam2, steamid, sizeof(steamid)))
		{
			int param = StringToInt(arg1)
			if(param == 0)
			{
				cheaters.Remove(steamid);
			}
			else
			{
				cheaters.SetValue(steamid, param);
			}
		}

	}
	return Plugin_Handled;
}

////////////////////////////////////////////////////
//Menu
////////////////////////////////////////////////////

public Players(int client)
{
	    Menu playerMenu = new Menu(Handle_PlayerSelect)
        playerMenu.SetTitle("Wybierz cheatera do ztrollowania");
		AddTargetsToMenu(playerMenu, client, true, true);
        playerMenu.Display(client, MENU_TIME_FOREVER);
}

public Handle_PlayerSelect(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			int userid, target;
			
			menu.GetItem(param2, info, sizeof(info));
			userid = StringToInt(info);		
			
	
			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "[SM] Player no longer available");
			}
			else if (!CanUserTarget(param1, target))
			{
				PrintToChat(param1, "[SM] Unable to target");
			}
			else
			{
				t_Target[param1] = GetClientOfUserId(userid);
				Power(param1);
				return;
			}
			
			if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
			{
				CMD_troll(param1, 0);
			}
		}
		case MenuAction_End:
		//default:
		{
			if (menu != null)
				delete menu;
		}
	}  
}

public Power(int client)
{
	Menu menu = new Menu(Handle_Select);
	char title[100];
	char name[MAX_NAME_LENGTH];
	GetClientName(t_Target[client], name, sizeof(name));
	Format(title, sizeof(title), "Trollowanie %s", name);
	menu.SetTitle(title);
	//menu.ExitBackButton = true;
	
	AddMenuItem(menu, "0", "normalne obrażenia");
	AddMenuItem(menu, "1", "brak obrażeń");
	AddMenuItem(menu, "2", "1/2 obrażeń");
	AddMenuItem(menu, "3", "leczenie");
	
	menu.Display(client, MENU_TIME_FOREVER);
}


public Handle_Select(Menu playerMenu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char steamid[32];
			if(GetClientAuthId(t_Target[param1], AuthId_Steam2, steamid, sizeof(steamid)))
			{
				if(param2==0)
				{
					cheaters.Remove(steamid);
				}
				else
				{
					cheaters.SetValue(steamid, param2);
				}
			}
		}
		case MenuAction_End:
		{
			//if(param2 == MenuEnd_ExitBack) {
            //    Players(param1);
            //} else {
			if (playerMenu != null)
				delete playerMenu;
            //}
		}
	}   
}

////////////////////////////////////////////////////
//Hooks
////////////////////////////////////////////////////

public OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
}

public Action OnPlayerTakeDamage(int iPlayer, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType)
{
	int status = -1;
	char steamid[32];
	
	if(iAttacker!=0 && iAttacker<=MAXPLAYERS+1)
	{
		if(GetClientAuthId(iAttacker, AuthId_Steam2, steamid, sizeof(steamid)))
		{
			if(cheaters.GetValue(steamid, status))
			{
				switch(status)
				{
					case 1:
					{
						flDamage = 0;
						return Plugin_Handled;
					}
					case 2:
					{
						flDamage /= 2;
						return Plugin_Continue;
					}
					case 3:
					{
						flDamage *= -1;
						DoneDMG(iPlayer, flDamage);
						return Plugin_Handled;
					}
					default:
					{
						cheaters.Remove(steamid);
						return Plugin_Continue;
					}
				}
			}
		}
	}
    return Plugin_Continue;
}

////////////////////////////////////////////////////
//Other
////////////////////////////////////////////////////

public DoneDMG(int iPlayer, float &flDamage)
{
	int iMaxHealth = GetEntProp(iPlayer, Prop_Data, "m_iMaxHealth");
	int iHealth    = GetEntProp(iPlayer, Prop_Send, "m_iHealth");  
	if (iHealth < iMaxHealth)
	{
		iHealth -= flDamage;
		if (iHealth > iMaxHealth)
		{
			iHealth = iMaxHealth;
		}
		SetEntProp(iPlayer, Prop_Send, "m_iHealth", iHealth);
	}
}

public CheckClientOnline(char[] SteamID)
{    
    int result = -1;
    
    for (new i = 1, iClients = GetClientCount(); i <= iClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            char szAuthId[32];
            GetClientAuthId(i, AuthId_Steam2, szAuthId, sizeof(szAuthId))
            
            if(StrEqual(szAuthId, SteamID))
            {
                result = i;
            }
        }
    }

    return result;
} 