#define MAX_INVENTORIES 			(MAX_PLAYERS + MAX_VEHICLES)
#define MAX_INVENTORY_ITEMS         (20)

#define INVALID_INVENTORY_ID        (-1)
#define INVALID_INVENTORY_SLOT_ID   (-1)

#define MAX_INVENTORY_WEIGHT        (50.0)

// работа с данными инвентарей
#define SetInventoryData(%0,%1,%2)      g_inventory[%0][%1] = %2
#define GetInventoryData(%0,%1)         g_inventory[%0][%1]
#define IsValidInventory(%0)            (g_inventory[%0][INV_SQL_ID])

#define IsValidInventorySlot(%0,%1)     (g_inventory[%0][INV_ITEMS][%1] != INVALID_INVENTORY_SLOT_ID)
#define SetInventoryItemID(%0,%1,%2)		g_inventory[%0][INV_ITEMS][%1] = %2
#define GetInventoryItemID(%0,%1)     		g_inventory[%0][INV_ITEMS][%1]
#define SetInventoryItemAmount(%0,%1,%2)    g_inventory[%0][INV_AMOUNT][%1] = %2
#define GetInventoryItemAmount(%0,%1)       g_inventory[%0][INV_AMOUNT][%1]
#define AddInventoryItemAmount(%0,%1,%2,%3) g_inventory[%0][INV_AMOUNT][%1] %2= %3

// работа с данными предметов
#define GetItemData(%0,%1)          g_item[%0][%1]
#define GetItemName(%0)             g_item[%0][I_NAME]
#define GetItemWeight(%0)           g_item[%0][I_WEIGHT]
#define GetItemFlags(%0)            g_item[%0][I_FLAGS]
#define ItemHasFlag(%0,%1)          (bool: (g_item[%0][I_FLAGS] & %1))

// упрощенное хранение идентификаторов listitem
#define GetPlayerListitemValue(%0,%1) 		g_player_listitem[%0][%1]
#define SetPlayerListitemValue(%0,%1,%2) 	g_player_listitem[%0][%1] = %2

#define ClearPlayerListitemValues(%0)		g_player_listitem[%0] = g_listitem_values

#define GetPlayerUseListitem(%0) 		g_player_listitem_use[%0]
#define SetPlayerUseListitem(%0,%1) 	g_player_listitem_use[%0] = %1

// список диалогов
enum
{
	INVALID_DIALOG_ID = 1,
	//
	DIALOG_INVENTORY, // инвентарь
	DIALOG_INVENTORY_ITEM, // взаимодействие с предметом
	//
	MAX_DIALOG_ID
}

// типы инвентарей
enum
{
	INVALID_INVENTORY_TYPE = -1,
	//
	INVENTORY_TYPE_PLAYER = 0,
	INVENTORY_TYPE_VEHICLE,
	//
	MAX_INVENTORY_TYPE
}

enum E_INVENTORY_STRUCT
{
	INV_SQL_ID,
	INV_TYPE,
	INV_OWNER,
	INV_ITEMS[MAX_INVENTORY_ITEMS],
	INV_AMOUNT[MAX_INVENTORY_ITEMS]
}
new g_inventory[MAX_INVENTORIES][E_INVENTORY_STRUCT];

new const g_inventory_default_values[E_INVENTORY_STRUCT] =
{
	0,
	INVALID_INVENTORY_TYPE,
	0
};

// типы предметов
enum
{
	ITEM_TYPE_WEAPON = 0,
	ITEM_TYPE_FOOD,
	ITEM_TYPE_OTHER
}

// флаги для предметов
enum (<<=1)
{
	ITEM_FLAG_NONE = 0,
	ITEM_FLAG_NO_DROP = 1,
	ITEM_FLAG_STACKABLE
}

enum E_ITEM_STRUCT
{
	I_NAME[32],
	Float: I_WEIGHT,
	I_TYPE,
	I_FLAGS
}

new const g_item[][E_ITEM_STRUCT] =
{
	{"Справочник",	0.1,	ITEM_TYPE_OTHER,	ITEM_FLAG_NO_DROP},
	{"Пистолет",	0.6,	ITEM_TYPE_WEAPON, 	ITEM_FLAG_STACKABLE}
};

// listitem values by nazarik
new g_player_listitem[MAX_PLAYERS][32];
new g_listitem_values[sizeof(g_player_listitem[])] = {0, ...};

new g_player_listitem_use[MAX_PLAYERS] = {-1, ...};

stock Float: GetInventoryWeight(inv_id)
{
	new Float: weight = 0.0;

	for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
	{
	    if(IsValidInventorySlot(inv_id, slot_id))
	    {
	        weight += GetItemWeight(GetInventoryItemID(inv_id, slot_id));
	    }
	}

	return weight;
}

stock InitInventory()
{
	for(new inv_id = 0; inv_id < MAX_INVENTORIES; inv_id++)
	{
	    g_inventory[inv_id] = g_inventory_default_values;
	    
	    for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
	    {
	        SetInventoryItemID(inv_id, slot_id, INVALID_INVENTORY_SLOT_ID);
	        SetInventoryItemAmount(inv_id, slot_id, 0);
	    }
	}
}

stock FindFreeInventorySlot()
{
	for(new inv_id = 0; inv_id < MAX_INVENTORIES; inv_id++)
	{
	    if(!IsValidInventory(inv_id))
	    {
	        return inv_id;
	    }
	}
	
	return INVALID_INVENTORY_ID;
}

stock FindFreeItemSlot(inv_id)
{
	for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
	{
	    if(!IsValidInventorySlot(inv_id, slot_id))
	    {
	        return slot_id;
	    }
	}
	
	return INVALID_INVENTORY_SLOT_ID;
}

stock FindItemSlot(inv_id, item_id)
{
	for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
	{
	    if(GetInventoryItemID(inv_id, slot_id) == item_id)
	    {
	        return slot_id;
	    }
	}
	
	return INVALID_INVENTORY_SLOT_ID;
}

stock FindStackableItemSlot(inv_id, item_id)
{
    new slot_id = FindItemSlot(inv_id, item_id);

	if(slot_id == INVALID_INVENTORY_SLOT_ID)
	{
	    slot_id = FindFreeItemSlot(inv_id);
	}
	
	return slot_id;
}

stock CreateInventory(owner, owner_sql_id, type = INVENTORY_TYPE_PLAYER)
{
	new inv_id = FindFreeInventorySlot();
	
	if(inv_id != INVALID_INVENTORY_ID)
	{
		new fmt_query[60];

		mysql_format
		(
		    mysql_db,
		    fmt_query,
		    sizeof fmt_query,
		    "INSERT INTO inventories(type, owner) VALUES (%d, %d)",
		    type,
		    owner_sql_id
		);

		new Cache: cache = mysql_query(mysql_db, fmt_query, true);
		cache_set_active(cache);

		SetInventoryData(inv_id, INV_SQL_ID, cache_insert_id());
		SetInventoryData(inv_id, INV_TYPE, type);
		SetInventoryData(inv_id, INV_OWNER, owner);

		cache_delete(cache);
	}
	
	return inv_id;
}

stock LoadInventory(owner, owner_sql_id)
{
	new inv_id = FindFreeInventorySlot();
	
	if(inv_id != INVALID_INVENTORY_ID)
	{
		new fmt_query[55];

		mysql_format
		(
		    mysql_db,
		    fmt_query, sizeof fmt_query,
		    "SELECT * FROM inventories WHERE owner=%d LIMIT 1",
		    owner_sql_id
		);

		new Cache: cache = mysql_query(mysql_db, fmt_query, true);

		cache_set_active(cache);

		if(cache_num_rows())
		{
		    SetInventoryData(inv_id, INV_OWNER, owner);
		    cache_get_value_name_int(0, "id", g_inventory[inv_id][INV_SQL_ID]);
		    cache_get_value_name_int(0, "type", g_inventory[inv_id][INV_TYPE]);
		    
		    new fmt_field[15];
		    
		    for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
		    {
		        format(fmt_field, sizeof fmt_field, "item_id_%d", slot_id);
		        cache_get_value_name_int(0, fmt_field, g_inventory[inv_id][INV_ITEMS][slot_id]);
		        
		        format(fmt_field, sizeof fmt_field, "item_amount_%d", slot_id);
		        cache_get_value_name_int(0, fmt_field, g_inventory[inv_id][INV_AMOUNT][slot_id]);
		    }
		}

		cache_delete(cache);
 	}
 	
 	return inv_id;
}

stock ShowInventory(playerid, inv_id, bool: can_use = true)
{
	if(inv_id == INVALID_INVENTORY_ID)
	{
	    return 0;
	}

	new fmt_item[50];
	new fmt_dialog[sizeof fmt_item * MAX_INVENTORY_ITEMS];
	new count = 0;

	for(new slot_id = 0; slot_id < MAX_INVENTORY_ITEMS; slot_id++)
	{
	    if(IsValidInventorySlot(inv_id, slot_id))
	    {
	        new item_id = GetInventoryItemID(inv_id, slot_id);
	        new bool: display_amount = ItemHasFlag(item_id, ITEM_FLAG_STACKABLE);
	        
	        new fmt_amount[10];
	        format(fmt_amount, sizeof fmt_amount, " [%d]", GetInventoryItemAmount(inv_id, slot_id));
	    
	        format(fmt_item, sizeof fmt_item, "%d. %s%s\n", (count + 1), GetItemName(item_id), (display_amount) ? (fmt_amount) : (""));
	        strcat(fmt_dialog, fmt_item);
	        
	        SetPlayerListitemValue(playerid, count++, slot_id);
	    }
	}
	
	if(!count)
	{
	    format(fmt_dialog, 14, "{888888}Пусто");
	    SetPlayerListitemValue(playerid, 0, INVALID_INVENTORY_SLOT_ID);
	}
	
	ShowDialog(playerid, (can_use) ? (DIALOG_INVENTORY) : (0), DIALOG_STYLE_LIST, "{FFCC00}Инвентарь", fmt_dialog, "Выбор", "Отмена");

	if(can_use)
	{
		SetPVarInt(playerid, "active_inventory", (inv_id + 1));
	}

	return 1;
}

stock ShowInventoryItem(playerid, inv_id)
{
	if(inv_id == INVALID_INVENTORY_ID)
	{
	    ShowInventory(playerid, inv_id);
	
		return 0;
	}

	new slot_id = GetPlayerListitemValue(playerid, GetPlayerUseListitem(playerid));
	
	if(slot_id == INVALID_INVENTORY_SLOT_ID)
	{
	    return 0;
	}
	
	new item_id = GetInventoryItemID(inv_id, slot_id);
	
	new caption[41];
	
	format(caption, sizeof caption, "{FFCC00}%s", GetItemName(item_id));
	
	ShowDialog
	(
	    playerid,
	    DIALOG_INVENTORY_ITEM,
		DIALOG_STYLE_LIST,
		caption,
		"1. Выбросить",
		"Выбор", "Отмена"
	);

	return 1;
}

stock GiveItem(inv_id, item_id, item_amount)
{
	if(inv_id == INVALID_INVENTORY_ID)
	{
	    return -1;
	}
	
	if(!(0 <= item_id <= sizeof g_item - 1))
	{
	    return -1;
	}
	
	if((MAX_INVENTORY_WEIGHT - GetInventoryWeight(inv_id)) < (GetItemWeight(item_id) * item_amount))
	{
	    return 0;
	}
	
	new slot_id = INVALID_INVENTORY_SLOT_ID;
	
	if(ItemHasFlag(item_id, ITEM_FLAG_STACKABLE))
	{
	    slot_id = FindStackableItemSlot(inv_id, item_id);
	}
	else
	{
	    slot_id = FindFreeItemSlot(inv_id);
	}
	
	if(slot_id == INVALID_INVENTORY_SLOT_ID)
	{
	    return 0;
	}
	
	SetInventoryItemID(inv_id, slot_id, item_id);
	AddInventoryItemAmount(inv_id, slot_id, +, item_amount);
	
	SaveItem(inv_id, slot_id);
	
	return 1;
}

stock TakeItem(inv_id, item_id, amount = -1)
{
	if(inv_id == INVALID_INVENTORY_ID)
	{
		return -1;
	}
	
	new slot_id = FindItemSlot(inv_id, item_id);
	
	if(slot_id == INVALID_INVENTORY_SLOT_ID)
	{
	    return 0;
	}
	
	if(amount == -1)
	{
	    amount = GetInventoryItemAmount(inv_id, slot_id);
	}
	
	if(GetInventoryItemAmount(inv_id, slot_id) < amount)
	{
	    return 0;
	}
	
	AddInventoryItemAmount(inv_id, slot_id, -, amount);
	
	if(!GetInventoryItemAmount(inv_id, slot_id))
	{
	    SetInventoryItemID(inv_id, slot_id, -1);
	}
	
	SaveItem(inv_id, slot_id);

	return 1;
}

stock SaveItem(inv_id, slot_id)
{
	new fmt_query[80];
	
	mysql_format
	(
		mysql_db,
		fmt_query, sizeof fmt_query,
		"UPDATE inventories SET item_id_%d=%d, item_amount_%d=%d WHERE id=%d",
		slot_id,
		GetInventoryItemID(inv_id, slot_id),
		slot_id,
		GetInventoryItemAmount(inv_id, slot_id),
		GetInventoryData(inv_id, INV_SQL_ID)
	);
	
	mysql_query(mysql_db, fmt_query);
	
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid)
    {
        case DIALOG_INVENTORY:
		{
		    if(response)
		    {
			    new inv_id = (GetPVarInt(playerid, "active_inventory") - 1);

			    if(inv_id != INVALID_INVENTORY_ID)
			    {
					if(GetPlayerListitemValue(playerid, listitem) == INVALID_INVENTORY_SLOT_ID)
					{
					    ShowInventory(playerid, inv_id);
					    
					    return 1;
					}
					
					SetPlayerUseListitem(playerid, listitem);
					ShowInventoryItem(playerid, inv_id);
			    }
		    }
		}
		case DIALOG_INVENTORY_ITEM:
		{
		    new inv_id = (GetPVarInt(playerid, "active_inventory") - 1);
		    
		    if(inv_id != INVALID_INVENTORY_ID)
		    {
		        if(response)
		        {
		            new slot_id = GetPlayerListitemValue(playerid, GetPlayerUseListitem(playerid));
		            
		            if(slot_id != INVALID_INVENTORY_SLOT_ID)
		            {
		                new item_id = GetInventoryItemID(inv_id, slot_id);
		        
			            switch(listitem + 1)
			            {
			                case 1: // выбросить
			                {
			                    if(ItemHasFlag(item_id, ITEM_FLAG_NO_DROP))
			                    {
			                        Send(playerid, 0xFF5533FF, "Данный предмет нельзя выбросить из инвентаря");
			                        
			                        ShowInventoryItem(playerid, inv_id);
			                    }
			                    else
			                    {
			                        TakeItem(inv_id, item_id);
			                        ShowInventory(playerid, inv_id);

			                        Send(playerid, 0xFFCC00FF, "Вы выбросили предмет из инвентаря");
			                    }
			                }
			            }
			        }
		        }
		        else
		        {
		            ShowInventory(playerid, inv_id);
		        }
		    }
		}
    }

    return 1;
}