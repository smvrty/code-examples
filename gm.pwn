// simple gm by smvrty (2019)

#include <a_samp>

#undef MAX_PLAYERS

#define MAX_PLAYERS	(20)

#include "libraries/a_mysql.inc"
#include "libraries/streamer.inc"
#include "libraries/Pawn.CMD.inc"
#include "libraries/sscanf2.inc"

// Макросы

// сообщения
#define Send   	SendClientMessage
#define SendAll SendClientMessageToAll

//
#define fpublic%0(%1) forward%0(%1);public%0(%1)

// работа с данными игрока
#define SetPlayerData(%0,%1,%2) 	g_player_data[%0][%1] = %2
#define GetPlayerData(%0,%1) 		g_player_data[%0][%1]
#define AddPlayerData(%0,%1,%2,%3) 	g_player_data[%0][%1] %2= %3

#define GetPlayerNameEx(%0)         g_player_data[%0][P_NAME]
#define GetPlayerAdminEx(%0)        g_player_data[%0][P_ADMIN]

main()
{

}

// Переменные и массивы
new MySQL: mysql_db = MySQL: -1;

new g_mysql_database[4][12] =
{
	"127.0.0.1",
	"root",
	"mysql",
	"server_base"
};

// типы подключения
enum
{
	LOGIN_STATE_NONE,       		// не загружен
	LOGIN_STATE_ACCOUNT_CHECK,		// проверка наличия в бд
 	LOGIN_STATE_REG_PASSWORD,		// регистрация: ввод пароля
	LOGIN_STATE_REG_EMAIL,			// регистрация: ввод почты
	LOGIN_STATE_REG_GENDER,			// регистрация: выбор пола
	LOGIN_STATE_REG_SKIN,           // регистрация: выбор скина
	LOGIN_STATE_REG_SPAWN,          // регистрация: выбор места спавна
	LOGIN_STATE_REG_FINISH,			// регистрация: завершение
	LOGIN_STATE_AUTH,				// авторизация: ввод пароля
	LOGIN_STATE_AUTH_FINISH,		// авторизация: завершение
	LOGIN_STATE_LOGGED,				// авторизован
}

// флаги админ уровней
enum (<<=1)
{
	FLAG_ADMIN_LOW = 1,
	FLAG_ADMIN_MEDIUM,
	FLAG_ADMIN_HIGH
}

// список диалогов
enum
{
	INVALID_DIALOG_ID = 1,
	//
	DIALOG_LOGIN, // диалог авторизации/регистрации
	//
	MAX_DIALOG_ID
}

enum E_PLAYER_DATA_STRUCT
{
	P_SQL_ID, 		// ид аккаунта
	P_NAME[21], 	// никнейм
	P_PASSWORD[65], // пароль
	P_EMAIL[65], 	// почта
	P_IP[16],       // текущий IP
	P_REG_IP[16],       // регистрационный IP
	P_LAST_LOGIN_IP[16],	// IP последнего входа
	P_REG_TS,       // timestamp регистрации
	P_LAST_LOGIN_TS,    // timestamp последнего входа
	P_GENDER, 		// пол
	P_SKIN,			// скин
	Float: P_POS_X, // позиция x
	Float: P_POS_Y, // позиция y
	Float: P_POS_Z, // позиция z
	Float: P_POS_A, // угол поворота
	Float: P_HEALTH,    // уровень здоровья
	P_ADMIN,        // админ уровень
	//
	P_DIALOG_ID,    // ид диалога
	bool: P_CONNECTED,    // подкл. к серверу
	bool: P_LOGGED,       // авторизован
	bool: P_SPAWNED,      // заспавнился
	P_LOGIN_STATE,   // тип подключения
	P_AUTH_TIME,     // время, выделенное для входа
	P_AUTH_ATTEMPTS,    // количество попыток
	P_SELECT_SKIN    // выбор скина
}

new g_player_data[MAX_PLAYERS][E_PLAYER_DATA_STRUCT];

new g_player_race_id[MAX_PLAYERS];

new g_player_default_values[E_PLAYER_DATA_STRUCT] =
{
	0, 				// ид аккаунта
	"", 			// никнейм
	"", 			// пароль
	"", 			// почта
	"255.255.255.255",  // текущий IP
	"255.255.255.255",  // регистрационный IP
	"255.255.255.255",  // IP последнего входа
	0,              // timestamp регистрации
	0,              // timestamp последнего входа
	0, 				// пол
	0, 				// скин
	0.0,            // позиция x
	0.0,            // позиция y
	0.0,            // позиция z
	100.0,          // уровень здоровья
	0.0,            // угол поворота
	0,              // админ уровень
	//
	INVALID_DIALOG_ID, 	// ид диалога
	false,          // подкл. к серверу
	false,          // авторизован
	false,          // заспавнился
	LOGIN_STATE_NONE,    // тип подключения
	0,              // время, выделенное для входа
	3,              // количество попыток
	0               // выбор скина
};

new p_reg_skins[2][3] =
{
	// мужские
	{
		35,
		36,
		37
	},
	// женские
	{
		40,
		41,
		39
	}
};

// координаты больниц
new Float: g_hospitals[2][4] =
{
	{-286.6985, 	578.0150, 		12.8310, 	90.0}, // больница Арзамас
	{2113.7537, 	-2387.7627, 	21.9404, 	0.0} // больница Южный
};

enum E_SPAWN_POINT_STRUCT
{
	SP_NAME[14],
	Float: SP_POS_X,
	Float: SP_POS_Y,
	Float: SP_POS_Z,
	Float: SP_POS_A
}

// координаты спавнов
new g_spawn_points[3][E_SPAWN_POINT_STRUCT] =
{
	{"г. Южный", 		2500.9856, 	-2135.8010, 23.4404, 0.0}, // ЖД станция Южный
	{"д. Гарель", 		2540.0000, 	-19.0000, 	25.0000, 90.0}, // деревня Гарель
	{"пгт. Батырево", 	1774.6724, 	2241.1758, 	15.8545, 0.0} // пгт Батырево
};

public OnGameModeInit()
{
    mysql_log(ERROR | WARNING);

	if(!ConnectToDatabase())
	{
	    return 0;
	}

	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerConnect(playerid)
{
	if(IsPlayerNPC(playerid))
	{
		KickEx(playerid, 0);
		
		return 0;
	}

	if(GetPlayerData(playerid, P_CONNECTED))
	{
		KickEx(playerid, 0);
		
		return 0;
	}

	ClearPlayerInfo(playerid);

	SetPlayerData(playerid, P_CONNECTED, true);

	SetPlayerData(playerid, P_LOGIN_STATE, LOGIN_STATE_NONE);
	
	GetPlayerIp(playerid, g_player_data[playerid][P_IP], 16 + 1);
	GetPlayerName(playerid, g_player_data[playerid][P_NAME], MAX_PLAYER_NAME + 1);

	TogglePlayerSpectating(playerid, true);

	ShowPlayerLoginDialog(playerid, LOGIN_STATE_NONE, ++ g_player_race_id[playerid]);

	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	if(IsPlayerLogged(playerid))
	{
		SavePlayerAccount(playerid);
	}

	ClearPlayerInfo(playerid);

	g_player_race_id[playerid] ++;

	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(!IsPlayerLogged(playerid))
	{
		KickEx(playerid);
		return 1;
	}
	
	SetPlayerHealth(playerid, GetPlayerData(playerid, P_HEALTH));
	
	SetPlayerData(playerid, P_SPAWNED, true);
	
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	if(killerid != INVALID_PLAYER_ID)
	{
	    new fmt_str[92],
	        weapon_name[32];
	        
		GetWeaponName(reason, weapon_name, sizeof weapon_name);
	    
	    format(fmt_str, sizeof fmt_str, "%s[%d] убил %s[%d] (%s)", GetPlayerNameEx(killerid), killerid, GetPlayerNameEx(playerid), playerid, weapon_name);
	    SendAll(0xFFCD00FF, fmt_str);
	    
		new TODO_give_suspect;
	}
	
	SetPlayerData(playerid, P_SPAWNED, false);
	
	InitPlayerSpawn(playerid, true);

	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	if(!IsPlayerConnected(playerid))
	{
		return 1;
	}

	new last_dialog_id = GetPlayerData(playerid, P_DIALOG_ID);

	SetPlayerData(playerid, P_DIALOG_ID, INVALID_DIALOG_ID);

	if(last_dialog_id == INVALID_DIALOG_ID || last_dialog_id != dialogid)
	{
		return 1;
	}

	for(new i = 0, j = strlen(inputtext); i < j; i++)
	{
		if(inputtext[i] == '%')
		{
			inputtext[i] = '#';
		}
	}

	switch(dialogid)
	{
		case DIALOG_LOGIN:
		{
			switch(GetPlayerData(playerid, P_LOGIN_STATE))
			{
				case LOGIN_STATE_REG_PASSWORD:
				{
					if(!response)
					{
						KickEx(playerid);
						return 1;
					}

					new len = strlen(inputtext);
					if(len < 6 || len > 64)
					{
						ShowRegDialog(playerid, true);
						return 1;
					}

					new bool: invalid = false;

					for(new idx = 0; idx < len; idx++)
					{
						if(inputtext[idx] == '#' || inputtext[idx] == '%')
						{
							invalid = true;
							break;
						}
					}

					if(invalid)
					{
						Send(playerid, 0xFF5533FF, "Пароль не должен содержать символы # или %.");

						ShowRegDialog(playerid, true);
					}
					else
					{
						format(g_player_data[playerid][P_PASSWORD], 64, "%s", inputtext);

						g_player_race_id[playerid] ++;

						CallLocalFunction
						(
							"ShowPlayerLoginDialog",
							"ddd",
							playerid,
							GetPlayerData(playerid, P_LOGIN_STATE) + 1,
							g_player_race_id[playerid]
						);
					}

					return 1;
				}
				case LOGIN_STATE_REG_EMAIL:
				{
					if(!response)
					{
						KickEx(playerid);
						return 1;
					}

					if(strlen(inputtext))
					{
						if(IsValidMail(inputtext, strlen(inputtext)))
						{
							g_player_race_id[playerid] ++;

							format(g_player_data[playerid][P_EMAIL], 64 + 1, "%s", inputtext);

							CallLocalFunction
							(
								"ShowPlayerLoginDialog",
								"ddd",
								playerid,
								GetPlayerData(playerid, P_LOGIN_STATE) + 1,
								g_player_race_id[playerid]
							);

							return 1;
						}
					}

					Send(playerid, 0xFF5533FF, "Адрес электронной почты не соответствует требованиям.");

					ShowEmailDialog(playerid);

					return 1;
				}
				case LOGIN_STATE_REG_GENDER:
				{
					SetPlayerData(playerid, P_GENDER, response ? 0 : 1);

					g_player_race_id[playerid] ++;

					CallLocalFunction
					(
						"ShowPlayerLoginDialog",
						"ddd",
						playerid,
						GetPlayerData(playerid, P_LOGIN_STATE) + 1,
						g_player_race_id[playerid]
					);

					return 1;
				}
				case LOGIN_STATE_REG_SKIN:
				{
				    if(response)
				    {
				        new skin_index = GetPlayerData(playerid, P_SELECT_SKIN) + 1;
				        
				        if(skin_index == sizeof p_reg_skins[])
				        {
				            skin_index = 0;
				        }
				        
				        SetPlayerData(playerid, P_SELECT_SKIN, skin_index);
				        
				        ShowSkinDialog(playerid);
				    }
				    else
				    {
				        new gender = GetPlayerData(playerid, P_GENDER),
				            skin_index = GetPlayerData(playerid, P_SELECT_SKIN);
				    
				        SetPlayerData(playerid, P_SKIN, p_reg_skins[gender][skin_index]);
				        SetPlayerData(playerid, P_SELECT_SKIN, 0);
				        
				        SetPlayerInterior(playerid, 0);
				        
				        TogglePlayerSpectating(playerid, true);
						TogglePlayerControllable(playerid, true);
				    
					    g_player_race_id[playerid] ++;

					    CallLocalFunction
						(
							"ShowPlayerLoginDialog",
							"ddd",
							playerid,
							GetPlayerData(playerid, P_LOGIN_STATE) + 1,
							g_player_race_id[playerid]
						);
					}
				
				    return 1;
				}
				case LOGIN_STATE_REG_SPAWN:
				{
				    if(response)
				    {
				        SetPlayerData(playerid, P_POS_X, g_spawn_points[listitem][SP_POS_X]);
				        SetPlayerData(playerid, P_POS_Y, g_spawn_points[listitem][SP_POS_Y]);
				        SetPlayerData(playerid, P_POS_Z, g_spawn_points[listitem][SP_POS_Z]);
				        SetPlayerData(playerid, P_POS_A, g_spawn_points[listitem][SP_POS_A]);
				        
				        g_player_race_id[playerid] ++;

					    CallLocalFunction
						(
							"ShowPlayerLoginDialog",
							"ddd",
							playerid,
							GetPlayerData(playerid, P_LOGIN_STATE) + 1,
							g_player_race_id[playerid]
						);
				    }
				    else
				    {
				        ShowSpawnDialog(playerid);
				    }
				
				    return 1;
				}
				case LOGIN_STATE_AUTH:
				{
					if(!response)
					{
						KickEx(playerid);
						return 1;
					}

					new len = strlen(inputtext);
					if(len < 6 || len > 32)
					{
						ShowLoginDialog(playerid, true);
						return 1;
					}

					if(strcmp(inputtext, GetPlayerData(playerid, P_PASSWORD), false) == 0)
					{
						g_player_race_id[playerid] ++;

						CallLocalFunction
						(
							"ShowPlayerLoginDialog",
							"ddd",
							playerid,
							LOGIN_STATE_AUTH_FINISH,
							g_player_race_id[playerid]
						);
					}
					else
					{
						AddPlayerData(playerid, P_AUTH_ATTEMPTS, -, 1);

						ShowLoginDialog(playerid, true);

                        new fmt_str[44 + 1];

						format
						(
						    fmt_str,
						    sizeof fmt_str,
						    "[Ошибка] Неверный пароль. Осталось попыток: %d",
						    GetPlayerData(playerid, P_AUTH_ATTEMPTS)
						);

						Send(playerid, 0xFF5533FF, fmt_str);

						if(GetPlayerData(playerid, P_AUTH_ATTEMPTS) == 0)
						{
							HideDialog(playerid);

							KickEx(playerid);
							return 1;
						}
					}

					return 1;
				}
			}

			return 1;
		}
	}
	
	return 1;
}

public OnPlayerCommandReceived(playerid, cmd[], params[], flags)
{
	if((flags & FLAG_ADMIN_LOW) && (GetPlayerAdminEx(playerid) < 1))
	{
	    return 0;
	}
	
	if((flags & FLAG_ADMIN_MEDIUM) && (GetPlayerAdminEx(playerid) < 2))
	{
	    return 0;
	}
	
	if((flags & FLAG_ADMIN_HIGH) && (GetPlayerAdminEx(playerid) < 3))
	{
	    return 0;
	}
	

	return 1;
}

public OnPlayerCommandPerformed(playerid, cmd[], params[], result, flags)
{
	if(result == -1)
	{
	    if(flags & (FLAG_ADMIN_LOW | FLAG_ADMIN_MEDIUM | FLAG_ADMIN_HIGH))
	    {
	        Send(playerid, 0x888888FF, "Недостаточный уровень администратора");
	    }
	}

	return 1;
}

stock IsPlayerLogged(playerid)
{
	if(!(0 <= playerid < MAX_PLAYERS))
	{
		return 0;
	}

	if(!IsPlayerConnected(playerid))
	{
		return 0;
	}

	if(!GetPlayerData(playerid, P_CONNECTED))
	{
		return 0;
	}

	if(!GetPlayerData(playerid, P_LOGGED))
	{
		return 0;
	}

	return 1;
}

stock ClearPlayerInfo(playerid)
{
	g_player_data[playerid] = g_player_default_values;

	return 1;
}

fpublic FixedKick(playerid)
{
	Kick(playerid);

	return 1;
}

stock KickEx(playerid, time_ms = 500)
{
	if(!time_ms)
	{
	    Kick(playerid);
	
	    return 1;
	}
	
	SetTimerEx("FixedKick", time_ms, false, "d", playerid);

	return 1;
}

stock ConnectToDatabase()
{
	if(mysql_db != MySQL: -1)
	{
		mysql_close(mysql_db);
	}

	mysql_db = mysql_connect
	(
		g_mysql_database[0],
		g_mysql_database[1],
		g_mysql_database[2],
		g_mysql_database[3]
	);

    printf("[MySQL] Trying to connect to database:");

	if(mysql_errno())
	{
		new error[129];
		mysql_error(error, sizeof error, mysql_db);

		printf("* Failed: %s", error);
		
		return 0;
	}

	print("* Successfully connected");

	mysql_query(mysql_db, "SET NAMES cp1251;", false);
	mysql_query(mysql_db, "OPTIMIZE TABLE accounts", false);

	return 1;
}

fpublic ShowPlayerLoginDialog(playerid, step, race_id)
{
	if(g_player_race_id[playerid] != race_id)
	{
		return 1;
	}

	SetPlayerData(playerid, P_LOGIN_STATE, step);

	switch(step)
	{
		case LOGIN_STATE_NONE:
		{
			g_player_race_id[playerid] ++;

			SetTimerEx("ShowPlayerLoginDialog", 3000, false, "ddd", playerid, ++ step, g_player_race_id[playerid]);
		}
		case LOGIN_STATE_ACCOUNT_CHECK:
		{
			new fmt_str[43 + MAX_PLAYER_NAME + 1];

			mysql_format
			(
				mysql_db,
				fmt_str,
				sizeof fmt_str,
				"SELECT * FROM accounts WHERE player_name='%e'",
				GetPlayerNameEx(playerid)
			);

			new Cache: cache = mysql_query(mysql_db, fmt_str, true);

			cache_set_active(cache);

			if(cache_num_rows())
			{
				cache_get_value_name_int(0, "id", g_player_data[playerid][P_SQL_ID]);

				cache_get_value_name(0, "password", g_player_data[playerid][P_PASSWORD]);
			}

			cache_delete(cache);

			if(GetPlayerData(playerid, P_SQL_ID))
			{
				ShowLoginDialog(playerid);

				SetPlayerData(playerid, P_AUTH_TIME, 60);
				SetPlayerData(playerid, P_LOGIN_STATE, LOGIN_STATE_AUTH);
			}
			else
			{
				ShowRegDialog(playerid);

				SetPlayerData(playerid, P_AUTH_TIME, 300);
				SetPlayerData(playerid, P_LOGIN_STATE, LOGIN_STATE_REG_PASSWORD);
			}
		}
		case LOGIN_STATE_REG_EMAIL:
		{
		    ShowEmailDialog(playerid);

			AddPlayerData(playerid, P_AUTH_TIME, +, 20);
		}
		case LOGIN_STATE_REG_GENDER:
		{
		    ShowGenderDialog(playerid);

			AddPlayerData(playerid, P_AUTH_TIME, +, 20);
		}
		case LOGIN_STATE_REG_SKIN:
		{
		    SetPlayerData(playerid, P_SELECT_SKIN, 0);
		
		    SetPlayerInterior(playerid, 5);

			TogglePlayerSpectating(playerid, false);
			TogglePlayerControllable(playerid, false);

			SetPlayerPos(playerid, 208.7876, -2.5372, 1001.1967);
			SetPlayerFacingAngle(playerid, 180.0);

		    SetPlayerCameraPos(playerid, 208.8966, -9.0582, 1001.0435);
			SetPlayerCameraLookAt(playerid, 209.0707, -8.0749, 1001.0442);
		
		    ShowSkinDialog(playerid);
		    
		    AddPlayerData(playerid, P_AUTH_TIME, +, 40);
		}
		case LOGIN_STATE_REG_SPAWN:
		{
		    ShowSpawnDialog(playerid);
		    
		    AddPlayerData(playerid, P_AUTH_TIME, +, 30);
		}
		case LOGIN_STATE_REG_FINISH:
		{
		    CreatePlayerAccount(playerid);

		    SetPlayerData(playerid, P_LOGGED, true);

		    SetPlayerData(playerid, P_LOGIN_STATE, LOGIN_STATE_LOGGED);

		    TogglePlayerSpectating(playerid, false);

		    InitPlayerSpawn(playerid);
			SavePlayerAccount(playerid);

		    return 1;
		}
        case LOGIN_STATE_AUTH_FINISH:
		{
			new fmt_str[46];

			mysql_format
			(
				mysql_db,
				fmt_str,
				sizeof fmt_str,
				"SELECT * FROM accounts WHERE id='%d'",
				GetPlayerData(playerid, P_SQL_ID)
			);

			g_player_race_id[playerid]++;

			mysql_tquery(mysql_db, fmt_str, "AccountLoaded", "ii", playerid, g_player_race_id[playerid]);
		}
	}

	return 1;
}

fpublic AccountLoaded(playerid, race_id)
{
	if(g_player_race_id[playerid] != race_id)
	{
		return 1;
	}

	if(cache_num_rows())
	{
		cache_get_value_name(0, "reg_ip", g_player_data[playerid][P_REG_IP]);
		cache_get_value_name(0, "last_login_ip", g_player_data[playerid][P_LAST_LOGIN_IP]);

		cache_get_value_name_int(0, "reg_ts", g_player_data[playerid][P_REG_TS]);
		cache_get_value_name_int(0, "last_login_ts", g_player_data[playerid][P_REG_TS]);

		cache_get_value_name_int(0, "gender", g_player_data[playerid][P_GENDER]);

		cache_get_value_name(0, "email", g_player_data[playerid][P_EMAIL]);

		cache_get_value_name_float(0, "pos_x", g_player_data[playerid][P_POS_X]);
		cache_get_value_name_float(0, "pos_y", g_player_data[playerid][P_POS_Y]);
		cache_get_value_name_float(0, "pos_z", g_player_data[playerid][P_POS_Z]);
		cache_get_value_name_float(0, "pos_a", g_player_data[playerid][P_POS_A]);

		cache_get_value_name_int(0, "skin", g_player_data[playerid][P_SKIN]);
		
		InitPlayerSpawn(playerid);
	}

	return 1;
}

public OnPlayerUpdate(playerid)
{
	if(!IsPlayerLogged(playerid))
	{
	    return 0;
	}
	
	if(GetPlayerData(playerid, P_SPAWNED))
	{
		new Float: x,
			Float: y,
			Float: z,
			Float: a;

		GetPlayerPos(playerid, x, y, z);
		GetPlayerFacingAngle(playerid, a);

		if(x == 0.0 && y == 0.0 && z == 0.0)
		{
			z = 2.0;
		}

		SetPlayerData(playerid, P_POS_X, x);
		SetPlayerData(playerid, P_POS_Y, y);
		SetPlayerData(playerid, P_POS_Z, z);
		SetPlayerData(playerid, P_POS_A, a);

		new Float: health;

		GetPlayerHealth(playerid, health);

		if(health > GetPlayerData(playerid, P_HEALTH))
		{
		    SetPlayerHealthEx(playerid, GetPlayerData(playerid, P_HEALTH));
		}
		else
		{
		    SetPlayerData(playerid, P_HEALTH, health);
		}
	}
	
	return 1;
}

stock ShowDialog(playerid, dialogid, style, caption[], info[], button1[], button2[])
{
	SetPlayerData(playerid, P_DIALOG_ID, dialogid);

	ShowPlayerDialog(playerid, dialogid, style, caption, info, button1, button2);

	return 1;
}

stock HideDialog(playerid)
{
	SetPlayerData(playerid, P_DIALOG_ID, INVALID_DIALOG_ID);

	ShowPlayerDialog(playerid, -1, DIALOG_STYLE_MSGBOX, "null", "null", "null", "null");

	return 1;
}

stock ShowLoginDialog(playerid, bool: wrong_pass = false)
{
	new fmt_str[158];

	format
	(
		fmt_str,
		sizeof fmt_str,
		"{FFFFFF}Добро пожаловать, {FFCD00}%s{FFFFFF}!\n\
		Ваш аккаунт зарегистрирован на сервере.\n\n%s\
		Введите пароль:",
		GetPlayerNameEx(playerid),
		wrong_pass ? ("{FF5533}Неверный пароль{FFFFFF}\n\n") : ("")
	);

	ShowDialog
	(
		playerid,
		DIALOG_LOGIN,
		DIALOG_STYLE_PASSWORD,
		"{FFCD00}Авторизация",
		fmt_str,
		"Далее",
		"Отмена"
	);

	return 1;
}

stock ShowRegDialog(playerid, bool: invalid_pass = false)
{
	new fmt_str[361];

	format
	(
		fmt_str,
		sizeof fmt_str,
		"{FFFFFF}Добро пожаловать, {FFCD00}%s{FFFFFF}!\n\
		Ваш аккаунт не зарегистрирован на сервере.\n\n\
		Пожалуйста, придумайте пароль и введите его.\n\n%s\
		- Пароль должен иметь длину от 6 до 32 символов.\n\
		- Пароль должен состоять из латинских букв, цифр и спец. символов.\n\
		- Пароль чувствителен к регистру.",
		GetPlayerNameEx(playerid),
		invalid_pass ? ("{FF5533}Пароль не соответствует требованиям{FFFFFF}\n\n") : ("")
	);

	ShowDialog
	(
		playerid,
		DIALOG_LOGIN,
		DIALOG_STYLE_INPUT,
		"{FFCD00}Регистрация",
		fmt_str,
		"Далее",
		"Отмена"
	);

	return 1;
}

stock ShowEmailDialog(playerid)
{
	ShowDialog
	(
		playerid,
		DIALOG_LOGIN,
		DIALOG_STYLE_INPUT,
		"{FFCD00}Адрес электронной почты",
		"{FFFFFF}Укажите свой действительный адрес электронной почты.\n\n\
		Белый список E-Mail сервисов: {ABCDEF}yandex.ru, gmail.com, mail.ru\n\
		{FFFFFF}Он поможет восстановить Ваш аккаунт в случае взлома или потери пароля.\n\
		После регистрации электронную почту требуется подтвердить на сайте {66CC33}sitename.ru",
		"Далее",
		"Отмена"
	);

	return 1;
}

stock ShowGenderDialog(playerid)
{
	ShowDialog
	(
		playerid,
		DIALOG_LOGIN,
		DIALOG_STYLE_MSGBOX,
		"{FFCD00}Пол",
		"{FFFFFF}Укажите пол Вашего персонажа.",
		"Мужской",
		"Женский"
	);

	return 1;
}

stock ShowSkinDialog(playerid)
{
	new gender = GetPlayerData(playerid, P_GENDER),
	    skin_index = GetPlayerData(playerid, P_SELECT_SKIN);
	
	/*
	new fmt_str[50];

	format(fmt_str, sizeof fmt_str, "select_skin: %d / skin: %d", skin_index, p_reg_skins[gender][skin_index]);
	Send(playerid, -1, fmt_str);
	*/

	SetPlayerSkin(playerid, p_reg_skins[gender][skin_index]);

    ShowDialog
	(
		playerid,
		DIALOG_LOGIN,
		DIALOG_STYLE_MSGBOX,
		"{FFCD00}Внешность",
		"{FFFFFF}Выберите внешность Вашего персонажа.",
		"Далее",
		"Выбор"
	);

	return 1;
}

stock ShowSpawnDialog(playerid)
{
	new fmt_str[20],
	    fmt_list[sizeof fmt_str * sizeof g_spawn_points];
	    
	for(new idx = 0; idx < sizeof g_spawn_points; idx ++)
	{
	    format(fmt_str, sizeof fmt_str, "%d. %s\n", idx + 1, g_spawn_points[idx][SP_NAME]);
	    
		strcat(fmt_list, fmt_str);
	}
	
	ShowDialog
	(
	    playerid,
	    DIALOG_LOGIN,
	    DIALOG_STYLE_LIST,
	    "{FFCD00}Место появления",
	    fmt_list,
	    "Выбор",
	    "Отмена"
	);

	return 1;
}

stock IsValidMail(email[], len = sizeof email)
{
    new count[2];
	new bool: valid_mail = false;
	new white_list[4][10] =
	{
		"mail.ru",
		"yandex.ru",
		"ya.ru",
		"gmail.com"
	};

	for(new i; i < sizeof white_list; i++)
	{
	    if(strfind(email, white_list[i], true) != -1)
	    {
	        valid_mail = true;
	    
	        break;
	    }
	}

	if(valid_mail)
	{
	    if(!(5 <= len <= 64))
		{
			valid_mail = false;
		}
		else
		{
			for(new i; i != len; i++)
			{
				switch(email[i])
				{
					case '@':
					{
						count[0]++;
						if(count[0] != 1 || i == len - 1 || i == 0)
						{
							valid_mail = false;
						}
					}
					case '.':
					{
						if(count[0] == 1 && count[1] == 0 && i != len - 1)
						{
							count[1] = 1;
						}
					}
					case '0'..'9', 'a'..'z', 'A'..'Z', '_', '-':
					{
						continue;
					}
					default:
					{
						valid_mail = false;
					}
				}
			}
		}

	    if(count[1] == 0)
		{
			valid_mail = false;
		}
	}

    return valid_mail;
}

stock GetNearestHospital(playerid)
{
	new hospital_id = -1;
	
	new Float: x,
	    Float: y,
	    Float: z,
	    Float: dist = 100000.0;
	    
	GetPlayerPos(playerid, x, y, z);
	
	for(new idx = 0; idx < sizeof g_hospitals; idx++)
	{
	    new Float: tmp_dist,
	        Float: tmp_x = g_hospitals[idx][0] - x,
	        Float: tmp_y = g_hospitals[idx][1] - y,
	        Float: tmp_z = g_hospitals[idx][2] - z;
	    
	    tmp_dist = floatsqroot(tmp_x * tmp_x + tmp_y * tmp_y + tmp_z * tmp_z);
	    
	    if(dist > tmp_dist)
	    {
	        dist = tmp_dist;
	        
	        hospital_id = idx;
	    }
	}

	return hospital_id;
}

stock InitPlayerSpawn(playerid, bool: after_death = false)
{
	new Float: x,
	    Float: y,
	    Float: z,
	    Float: a;
	    
	if(after_death)
	{
	    new hospital_id = GetNearestHospital(playerid);
	    
	    x = g_hospitals[hospital_id][0];
	    y = g_hospitals[hospital_id][1];
	    z = g_hospitals[hospital_id][2];
	    a = g_hospitals[hospital_id][3];
	    
	    SetPlayerData(playerid, P_HEALTH, 30.0);
	}
	else
	{
	    x = GetPlayerData(playerid, P_POS_X);
	    y = GetPlayerData(playerid, P_POS_Y);
	    z = GetPlayerData(playerid, P_POS_Z);
	    a = GetPlayerData(playerid, P_POS_A);
	}
	
	SetSpawnInfo
	(
		playerid,
		1,
		GetPlayerData(playerid, P_SKIN),
		x, y, z, a,
		0, 0, 0, 0, 0, 0
	);
	
	// SpawnPlayer(playerid);

	return 1;
}

stock SetPlayerHealthEx(playerid, Float: health)
{
	SetPlayerData(playerid, P_HEALTH, health);
	
	SetPlayerHealth(playerid, health);

	return 1;
}

stock CreatePlayerAccount(playerid)
{
	new fmt_str[606];
	new current_time = gettime();

	format(g_player_data[playerid][P_REG_IP], 16 + 1, "%s", GetPlayerData(playerid, P_IP));
	format(g_player_data[playerid][P_LAST_LOGIN_IP], 16 + 1, "%s", GetPlayerData(playerid, P_IP));

	SetPlayerData(playerid, P_REG_TS, current_time);
	SetPlayerData(playerid, P_LAST_LOGIN_TS, current_time);

	mysql_format
	(
		mysql_db,
		fmt_str,
		sizeof fmt_str,
		"INSERT INTO accounts(player_name,reg_ip,last_login_ip,reg_ts,last_login_ts,\
		password,gender,email,skin) \
		VALUES('%e','%s','%s',%d,%d,'%s',%d,'%e',%d)",
		GetPlayerNameEx(playerid),
		GetPlayerData(playerid, P_IP),
		GetPlayerData(playerid, P_IP),
		current_time,
		current_time,
		GetPlayerData(playerid, P_GENDER),
		GetPlayerData(playerid, P_EMAIL),
		GetPlayerData(playerid, P_SKIN)
	);

	new Cache: cache = mysql_query(mysql_db, fmt_str, true);

	cache_set_active(cache);

	SetPlayerData(playerid, P_SQL_ID, cache_insert_id());
	SetPlayerData(playerid, P_LOGIN_STATE, LOGIN_STATE_LOGGED);

	cache_delete(cache);

	return 1;
}

stock SavePlayerAccount(playerid)
{
	new fmt_str[132];

	format
	(
		fmt_str,
		sizeof fmt_str,
		"UPDATE accounts \
		SET pos_x='%.2f',pos_y='%.2f',pos_z='%.2f',pos_a='%.2f',health='%.2f' \
		WHERE id=%d",
		GetPlayerData(playerid, P_POS_X),
		GetPlayerData(playerid, P_POS_Y),
		GetPlayerData(playerid, P_POS_Z),
		GetPlayerData(playerid, P_POS_A),
		GetPlayerData(playerid, P_HEALTH),
		GetPlayerData(playerid, P_SQL_ID)
	);

	mysql_query(mysql_db, fmt_str, false);
	return 1;
}

// команды
flags:kick(FLAG_ADMIN_LOW);
CMD:kick(playerid, params[])
{
	extract params -> new to_player, string: reason[32] = "none"; else return Send(playerid, 0x888888FF, "Используйте: /kick [id игрока] [причина]");

	if(!IsPlayerLogged(to_player) || playerid == to_player)
	{
	    Send(playerid, 0x888888FF, "Такого игрока нет");
	    
	    return 1;
	}
	
	new fmt_str[144];
	
	format(fmt_str, sizeof fmt_str, "%s[%d] кикнул игрока %s[%d]", GetPlayerNameEx(playerid), playerid, GetPlayerNameEx(to_player), to_player);
	
	if(strcmp(reason, "none"))
	{
	    format(fmt_str, sizeof fmt_str, "%s. Причина: %s", fmt_str, reason);
	}
	
	SendAll(0xFF5533FF, fmt_str);
	
	KickEx(to_player);

	return 1;
}

flags:money(FLAG_ADMIN_HIGH);
CMD:money(playerid, params[])
{
	extract params -> new to_player, money; else return SendClientMessage(playerid, 0x888888FF, "Используйте: /money [id игрока] [кол-во]");
	
	if(!IsPlayerLogged(to_player) || playerid == to_player)
	{
	    Send(playerid, 0x888888FF, "Такого игрока нет");

	    return 1;
	}
	
	if(!(1 <= money <= 1000000))
	{
	    Send(playerid, 0x888888FF, "Количество денег должно быть от 1 до 1.000.000");
	
	    return 1;
	}
	
	new fmt_str[89];
	
	format(fmt_str, sizeof fmt_str, "[$] %s[%d] выдал %s[%d] деньги в размере %d руб.", GetPlayerNameEx(playerid), playerid, GetPlayerNameEx(to_player), to_player, money);
	SendAll(0xFFFF00FF, fmt_str);

	return 1;
}
