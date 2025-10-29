#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <morecolors>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1

public Plugin myinfo =
{
	name = "Levelup System",
	author = "Refirser",
	description = "TF2 Levelup System",
	version = "0.1",
	url = ""
};

ConVar g_redEnableStatApply;
ConVar g_blueEnableStatApply;

Database h_database = null;

int g_sequence = 0;
int ConnectLock = 0;

const float g_GiveTime = 600.0;
const int g_GivePointOnTimer = 100;
const int g_GiveExpOnTimer = 50;
const int g_GiveDamageStacked = 2000;
const int g_GivePointOnReachDamageStacked = 40;  
const int g_GiveExpOnReachDamageStacked = 20; 
const int g_GivePointOnKilled = 20;
const int g_GiveExpOnKilled = 20;
const int g_GiveSkillPointOnLevelup = 3;

const int g_maxUpgrade = 20;

const int g_revivePointBase = 200;
const int g_reviveCountBase = 2;
const int g_addRevivePointOnRevive = 2;
const int g_addRevivePointOnTime = 100;
const float g_addRevivePointTime = 300.0;
const int g_healOnRevive = 2000;

const int g_skillResetPoint = 0;

new const expTable[80] =
{
	25, 60, 110, 175, 250, 350, 475, 625, 800, 1000,
	1225, 1475, 1750, 2050, 2375, 2725, 3100, 3500, 3925, 4375,
	4850, 5350, 5875, 6425, 7000, 7600, 8225, 8875, 9550, 10250,
	10975, 11725, 12500, 13300, 14125, 14975, 15850, 16750, 17675, 18625,
	19600, 20600, 21625, 22675, 23750, 24850, 25975, 27125, 28300, 29500,
	30750, 32050, 33400, 34800, 36250, 37750, 39300, 40900, 42550, 44250,
	46000, 47800, 49650, 51550, 53500, 55500, 57550, 59650, 61800, 64000,
	66250, 68550, 70900, 73300, 75750, 78250, 80800, 83400, 86050, 88750
};

float weaponUpgradeSuccessTable[15] = {
	1.0, 0.85, 0.85, 0.70, 0.70, 0.70, 0.45, 0.45,
	0.30, 0.30, 0.30, 0.15, 0.15, 0.10, 0.05
};

float weaponUpgradeMissTable[15] = {
	0.0, 0.15, 0.15, 0.30, 0.30, 0.30, 0.30, 0.30,
	0.40, 0.40, 0.40, 0.50, 0.50, 0.50, 0.50
};

float weaponUpgradeResetTable[15] = {
	0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.25, 0.25,
	0.30, 0.30, 0.30, 0.35, 0.35, 0.40, 0.45
};

new const weaponUpgradeCostTable[15] = {
	200,400, 600, 1200, 2000, 3500, 7000, 12000,
	20000, 35000, 50000, 100000, 150000, 250000, 
	400000
};

#define EXP_TABLE_SIZE (sizeof(expTable))
#define CLASS_SCOUT 0
#define CLASS_MEDIC 1 
#define CLASS_SOLDIER 2
#define CLASS_PYRO 3
#define CLASS_SPY 4
#define CLASS_DEMOMAN 5
#define CLASS_SNIPER 6
#define CLASS_ENGINEER 7
#define CLASS_HEAVY 8
#define CLASS_HALE 9 
#define CLASS_SHARED 10
#define CLASS_WEAPON 11

#define ADDITIVE_PERCENT 0
#define ADDITIVE_NUMBER 1
#define MINUS_PERCENT 2
#define MINUS_NUMBER 3

#define LOAD_PLAYERDATA 0
#define LOAD_CLASSATTRIBUTEDATA 1
#define LOAD_COMPLETE 2

enum struct AttributeTable
{
	char uid[64];
	char title[80];
	int class;
	int max;
	int point;
	float value;
	float defaultValue;
	int additiveMode;
	
	bool isDisableDrawValue;
}

enum struct AttributeData
{
	char uid[64];
	int id;
	int class;
	int upgrade;
}

enum struct PlayerData {
	char steamid[32];
	char basenick[255];
	
	int sequencenum;
	int level;
	int exp;
	int point;
	int skillpoint;
	
	int permission;
	
	int damage;
	
	int revivePoint;
	int reviveCount;
	
	bool isLoadComplete;
	
	int loadStatus;
	
	AttributeData scoutAttributeData[13];
	AttributeData medicAttributeData[14];
	AttributeData soldierAttributeData[13];
	AttributeData pyroAttributeData[13];
	AttributeData spyAttributeData[16];
	AttributeData demomanAttributeData[16];
	AttributeData sniperAttributeData[15];
	AttributeData engineerAttributeData[17];
	AttributeData heavyAttributeData[14];
	AttributeData haleAttributeData[3];
	AttributeData sharedAttributeData[2];
	AttributeData weaponAttributeData[1];
}

enum PlayerPermission
{
    ENGI_ENGIPAD  = (1 << 0),   // 1
};

#pragma newdecls required 
 
PlayerData playerDataList[MAXPLAYERS+1];
Handle g_Timer = INVALID_HANDLE;
Handle g_Timer_AddRevivePoint = INVALID_HANDLE;

AttributeTable scoutAttributeTable[13];
AttributeTable medicAttributeTable[14];
AttributeTable soldierAttributeTable[13];
AttributeTable pyroAttributeTable[13];
AttributeTable spyAttributeTable[16];
AttributeTable demomanAttributeTable[16];
AttributeTable sniperAttributeTable[15];
AttributeTable engineerAttributeTable[17];
AttributeTable heavyAttributeTable[14];
AttributeTable haleAttributeTable[3];
AttributeTable sharedAttributeTable[2];
AttributeTable weaponAttributeTable[1];

int prevOpenMenuPage = -1;

public void HealClient(int client, int amount)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    int current = GetClientHealth(client);
    int maxHp = GetEntProp(client, Prop_Data, "m_iMaxHealth");
    int newHp = current + amount;

    if (newHp > maxHp)
        newHp = maxHp;

    SetEntProp(client, Prop_Data, "m_iHealth", newHp);
}

public Action ShowPlayerInfoText(Handle timer) 
{
    for (int client = 1; client <= MaxClients; client++) 
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }
        
        // ✅ 블루팀(3번)은 HUD 표시 안함
        int team = GetClientTeam(client);
        if (team == 3)  // 블루팀
        {
            continue;
        }
        
        // ✅ 레드팀(2번)만 HUD 표시
        char hintText[512];
        Format(hintText, sizeof(hintText),
            "레벨 : %d\n경험치 : %d/%d\n포인트 : %d",
            playerDataList[client].level,
            playerDataList[client].exp,
            expTable[playerDataList[client].level],
            playerDataList[client].point
        );

        SetHudTextParams(0.01, 0.0, 1.0, 255, 200, 0, 255, 0, 0.0, 0.0, 0.1);
        ShowHudText(client, 4, hintText);
    }
    
    return Plugin_Continue;
}

int AttachParticle(int iEntity, char[] strParticleEffect, char[] strAttachPoint, float flZOffset, float flSelfDestruct) 
{ 
		int iParticle = CreateEntityByName("info_particle_system"); 
		if( !IsValidEdict(iParticle) ) 
			return 0; 
		 
		float flPos[3]; 
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flPos); 
		flPos[2] += flZOffset; 
		 
		TeleportEntity(iParticle, flPos, NULL_VECTOR, NULL_VECTOR); 
		 
		DispatchKeyValue(iParticle, "effect_name", strParticleEffect); 
		DispatchSpawn(iParticle); 
		 
		SetVariantString("!activator"); 
		AcceptEntityInput(iParticle, "SetParent", iEntity); 
		ActivateEntity(iParticle); 
		 
		if(strlen(strAttachPoint)) 
		{ 
			SetVariantString(strAttachPoint); 
			AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset"); 
		} 
		 
		AcceptEntityInput(iParticle, "start"); 
		 
		if( flSelfDestruct > 0.0 ) 
			CreateTimer( flSelfDestruct, Timer_DeleteParticle, EntIndexToEntRef(iParticle) ); 
		 
		return iParticle; 
}

public Action Timer_DeleteParticle(Handle hTimer, any iRefEnt) 
{ 
	int iEntity = EntRefToEntIndex(iRefEnt); 
	if(iEntity > MaxClients) 
		AcceptEntityInput(iEntity, "Kill"); 
	 
	return Plugin_Handled; 
}

public void OnCreateTable(Database db, DBResultSet result, const char[] error, any data)
{

}

public void OnDatabaseConnect(Database db, const char[] error, any data)
{

	if (data != ConnectLock || h_database != null)
	{
		delete db;
		return;
	}
	
	ConnectLock = 0;
	h_database = db;

	if (h_database == null)
	{
		LogError("Failed to connect to database: %s", error);
		return;
	}
	
    char query[512];
    Format(query, sizeof(query),
        "CREATE TABLE IF NOT EXISTS playerData (steamid TEXT PRIMARY KEY, level INTEGER DEFAULT 0, exp INTEGER DEFAULT 0, point INTEGER DEFAULT 0, skillpoint INTEGER DEFAULT 0, permission INTEGER DEFAULT 0);");
    db.Query(OnCreateTable, query);
    
	Format(query, sizeof(query),
        "CREATE TABLE IF NOT EXISTS classAttributeData (steamid TEXT, uid TEXT, id INTEGER DEFAULT 0, class INTEGER DEFAULT 0, upgrade INTEGER DEFAULT 0, UNIQUE (steamid, uid, class));");
	db.Query(OnCreateTable, query);
} 
 
void RequestDatabaseConnection()
{
	ConnectLock = ++g_sequence;
	Database.Connect(OnDatabaseConnect, "levelup", ConnectLock);
}

void FetchUser(int client)
{
	if (h_database != null){
		char query[256];
		
		Format(query, sizeof(query), "INSERT OR IGNORE INTO playerData (steamid, level, exp, point, skillpoint, permission) VALUES ('%s', %d, %d, %d, %d, %d);", 
		playerDataList[client].steamid, 0, 0, 0, 0, 0);

		playerDataList[client].loadStatus = LOAD_PLAYERDATA;
	
		DataPack dataPack = new DataPack();
		dataPack.WriteCell(client);
		
		h_database.Query(OnReceiveCreateUser, query, dataPack, DBPrio_High);
	}
}

void OnReceiveUser(Database db, DBResultSet result, const char[] error, any data)
{
    DataPack dataPack = view_as<DataPack>(data);
    dataPack.Reset();
    
    if (db == null)
    {
        PrintToServer("❌ OnReceiveUser Database Null");
        delete dataPack;
        return;
    }
    
    int client = dataPack.ReadCell();
    
    if (result == null)
    {
        PrintToServer("❌ OnReceiveUser result null");
        delete dataPack;
        return;
    }
    
    delete dataPack;
    
    char steamid[32];
    int level = 0;
    int exp = 0;
    int point = 0;
    int skillpoint = 0;
    int permission = 0;
    
    while(result.FetchRow())
    {
        result.FetchString(0, steamid, sizeof(steamid));
        level = result.FetchInt(1);
        exp = result.FetchInt(2);
        point = result.FetchInt(3);
        skillpoint = result.FetchInt(4);
        permission = result.FetchInt(5);
    }
    
    playerDataList[client].steamid = steamid;
    playerDataList[client].level = level;
    playerDataList[client].exp = exp;
    playerDataList[client].point = point;
    playerDataList[client].skillpoint = skillpoint;
    playerDataList[client].permission = permission;
    
    PrintToServer("✅ OnReceiveUser: Client %d (%s) - Level=%d EXP=%d Point=%d", 
                 client, steamid, level, exp, point);
    
    char prefix[12];
    char prefixName[255];
    Format(prefix, sizeof(prefix), "[Lv%d]", playerDataList[client].level);
    Format(prefixName, sizeof(prefixName), "%s%s", prefix, playerDataList[client].basenick);
    SetClientInfo(client, "name", prefixName);

    // ✅✅✅ 즉시 로드 완료로 설정!
    playerDataList[client].isLoadComplete = true;
    
    PrintToServer("✅ OnReceiveUser: Client %d - 로드 완료!", client);
    
    // ✅ 게임 중일 때만 메시지 표시
    if (IsClientInGame(client))
    {
        PrintCenterText(client, "데이터 로드 완료!\n레벨: %d | 포인트: %d", level, point);
        CPrintToChat(client, "{green}[Levelup]{default} 데이터 로드 완료! (레벨: {orange}%d{default}, 포인트: {unique}%d{default})", level, point);
        
        // ✅ 사운드 (옵션)
        EmitSoundToClient(client, "ui/item_store_add_to_cart.wav");
    }

    // ✅ 속성 로드 (비동기)
    FetchAttribute(client);
}

void OnReceiveCreateUser(Database db, DBResultSet result, const char[] error, any data)
{
	DataPack dataPack = view_as<DataPack>(data);
	dataPack.Reset();
	
	if (db == null)
	{
		PrintToServer("OnReceiveCreateUser Database Null");
		delete dataPack;
		return;
	}
	
	int client = dataPack.ReadCell();
	
	char query[256];
	
	playerDataList[client].sequencenum = ++g_sequence;	
	
	Format(query, sizeof(query),
    "SELECT * FROM playerData WHERE steamid = '%s';", playerDataList[client].steamid);	
	
	DataPack dataPack2 = new DataPack();
	dataPack2.WriteCell(client);	
	
	db.Query(OnReceiveUser, query, dataPack2, DBPrio_High);
	
	delete dataPack;
}

void UpdateUserData(int client)
{
	// ✅ 유효성 체크 추가
	if (!IsClientConnected(client) || IsFakeClient(client))
	{
		PrintToServer("UpdateUserData: Invalid client %d", client);
		return;
	}
	
	if (StrEqual(playerDataList[client].steamid, ""))
	{
		PrintToServer("UpdateUserData: Client %d has no steamid", client);
		return;
	}
	
	if (h_database != null){
		char query[256];
		
		int level = playerDataList[client].level;
		int exp = playerDataList[client].exp;
		int point = playerDataList[client].point;
		int skillpoint = playerDataList[client].skillpoint;
		int permission = playerDataList[client].permission;

		Format(query, sizeof(query), "UPDATE playerData SET level = %d, exp = %d, point = %d, skillpoint = %d, permission = %d WHERE steamid = '%s';", level, exp, point, skillpoint, permission, playerDataList[client].steamid);
	
		playerDataList[client].sequencenum = ++g_sequence;		
	
		DataPack dataPack = new DataPack();
		dataPack.WriteCell(client);
	
		h_database.Query(OnReceiveUpdateUserData, query, dataPack, DBPrio_High);
		
		PrintToServer("UpdateUserData: Client %d (%s) saved", client, playerDataList[client].steamid);
	}
}

void OnReceiveUpdateUserData(Database db, DBResultSet result, const char[] error, any data)
{
	DataPack dataPack = view_as<DataPack>(data);
	dataPack.Reset();
	
	if (db == null)
	{
		PrintToServer("OnReceiveUpdateUserData Database Null");
		delete dataPack;
		return;
	}
	
	
	if (result == null)
	{
		delete dataPack;
		return;
	}

	delete dataPack;
}

void FetchAttribute(int client)
{
    playerDataList[client].loadStatus = LOAD_CLASSATTRIBUTEDATA;

    if (h_database != null){
        
        // ✅ Scout - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].scoutAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].scoutAttributeData[i].id;
            int class = playerDataList[client].scoutAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].scoutAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].scoutAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Medic - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].medicAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].medicAttributeData[i].id;
            int class = playerDataList[client].medicAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].medicAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].medicAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Soldier - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].soldierAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].soldierAttributeData[i].id;
            int class = playerDataList[client].soldierAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].soldierAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].soldierAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Pyro - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].pyroAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].pyroAttributeData[i].id;
            int class = playerDataList[client].pyroAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].pyroAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].pyroAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Spy - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].spyAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].spyAttributeData[i].id;
            int class = playerDataList[client].spyAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].spyAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].spyAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Demoman - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].demomanAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].demomanAttributeData[i].id;
            int class = playerDataList[client].demomanAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].demomanAttributeData[i].uid, id, class, 0);
        
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].demomanAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }
        
        // ✅ Sniper - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].sniperAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].sniperAttributeData[i].id;
            int class = playerDataList[client].sniperAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].sniperAttributeData[i].uid, id, class, 0);
        
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].sniperAttributeData[i].uid);
            
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Engineer - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].engineerAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].engineerAttributeData[i].id;
            int class = playerDataList[client].engineerAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].engineerAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].engineerAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Heavy - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].heavyAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].heavyAttributeData[i].id;
            int class = playerDataList[client].heavyAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].heavyAttributeData[i].uid, id, class, 0);
        
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].heavyAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }

        // ✅ Hale - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].haleAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].haleAttributeData[i].id;
            int class = playerDataList[client].haleAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].haleAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].haleAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }    

        // ✅ Shared - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].sharedAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].sharedAttributeData[i].id;
            int class = playerDataList[client].sharedAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].sharedAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].sharedAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }
        
        // ✅ Weapon - INSERT OR IGNORE
        for (int i=0;i<sizeof(playerDataList[client].weaponAttributeData);i++)
        {
            char query[256];
            int id = playerDataList[client].weaponAttributeData[i].id;
            int class = playerDataList[client].weaponAttributeData[i].class;
            
            Format(query, sizeof(query), 
                "INSERT OR IGNORE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].weaponAttributeData[i].uid, id, class, 0);

            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);
            dataPack.WriteCell(id);
            dataPack.WriteCell(class);
            dataPack.WriteString(playerDataList[client].weaponAttributeData[i].uid);
        
            h_database.Query(OnReceiveCreateAttribute, query, dataPack, DBPrio_Low);        
        }        
    }
}

// ✅ INSERT 완료 후 SELECT
void OnInsertAllAttributes(Database db, DBResultSet result, const char[] error, any client)
{
	if (db == null)
	{
		PrintToServer("OnInsertAllAttributes Database Null");
		return;
	}
	
	if (result == null)
	{
		PrintToServer("OnInsertAllAttributes result null: %s", error);
		return;
	}
	
	// ✅ INSERT 완료 후 데이터 로드
	char query[512];
	Format(query, sizeof(query),
		"SELECT * FROM classAttributeData WHERE steamid = '%s' ORDER BY class, id;",
		playerDataList[client].steamid);
	
	DataPack dataPack = new DataPack();
	dataPack.WriteCell(client);
	
	h_database.Query(OnReceiveAttribute, query, dataPack, DBPrio_High);
}



void OnReceiveCreateAttribute(Database db, DBResultSet result, const char[] error, any data)
{
    DataPack dataPack = view_as<DataPack>(data);
    dataPack.Reset();
    
    if (db == null)
    {
        PrintToServer("OnReceiveCreateAttribute Database Null");
        delete dataPack;
        return;
    }
    
    int client = dataPack.ReadCell();
    int id = dataPack.ReadCell();
    int class = dataPack.ReadCell();
    char uid[64]; 
    dataPack.ReadString(uid, sizeof(uid));
    
    char query[256];

    Format(query, sizeof(query),
        "SELECT * FROM classAttributeData WHERE steamid = '%s' AND uid = '%s' AND class = %d AND id = %d;", 
        playerDataList[client].steamid, uid, class, id);    

    DataPack dataPack2 = new DataPack();
    dataPack2.WriteCell(client);    
    
    db.Query(OnReceiveAttribute, query, dataPack2, DBPrio_High);
    
    delete dataPack;
}

void OnReceiveAttribute(Database db, DBResultSet result, const char[] error, any data)
{
    DataPack dataPack = view_as<DataPack>(data);
    dataPack.Reset();
    
    if (db == null)
    {
        PrintToServer("OnReceiveAttribute Database Null");
        delete dataPack;
        return;
    }
    
    int client = dataPack.ReadCell();
    
    if (result == null)
    {
        PrintToServer("OnReceiveAttribute result null");
        delete dataPack;
        return;
    }    
    
    delete dataPack;
    
    char steamid[32];
    int id;
    int class;
    char uid[64];
    int upgrade;
    
    while(result.FetchRow())
    {
        result.FetchString(0, steamid, sizeof(steamid));
        result.FetchString(1, uid, sizeof(uid));
        id = result.FetchInt(2);
        class = result.FetchInt(3);
        upgrade = result.FetchInt(4);
        
        if (class == CLASS_WEAPON && id >= sizeof(weaponAttributeTable) - 1){
            playerDataList[client].isLoadComplete = true;
            PrintToServer("OnReceiveAttribute Completed");
        }
        
        PrintToServer("OnReceiveAttribute %s, %s %d %d %d", steamid, uid, id, class, upgrade);
        
        if (class == CLASS_SCOUT){
            playerDataList[client].scoutAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_MEDIC){
            playerDataList[client].medicAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_SPY){
            playerDataList[client].spyAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_SOLDIER){
            playerDataList[client].soldierAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_PYRO){
            playerDataList[client].pyroAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_DEMOMAN){
            playerDataList[client].demomanAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_SNIPER){
            playerDataList[client].sniperAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_ENGINEER){
            playerDataList[client].engineerAttributeData[id].upgrade = upgrade;
        }        
        else if (class == CLASS_HEAVY){
            playerDataList[client].heavyAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_HALE){
            playerDataList[client].haleAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_SHARED){
            playerDataList[client].sharedAttributeData[id].upgrade = upgrade;
        }
        else if (class == CLASS_WEAPON){
            playerDataList[client].weaponAttributeData[id].upgrade = upgrade;
        }
    }
}

void UpdateAttributeData(int client)
{
    if (h_database != null){        
        // ✅ Scout
        for (int i=0;i<sizeof(playerDataList[client].scoutAttributeData);i++)
        {
            int id = i;
            int class = CLASS_SCOUT;
            int upgrade = playerDataList[client].scoutAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].scoutAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }
        
        // ✅ Medic
        for (int i=0;i<sizeof(playerDataList[client].medicAttributeData);i++)
        {
            int id = i;
            int class = CLASS_MEDIC;
            int upgrade = playerDataList[client].medicAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].medicAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }    

        // ✅ Soldier
        for (int i=0;i<sizeof(playerDataList[client].soldierAttributeData);i++)
        {
            int id = i;
            int class = CLASS_SOLDIER;
            int upgrade = playerDataList[client].soldierAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].soldierAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }    

        // ✅ Pyro
        for (int i=0;i<sizeof(playerDataList[client].pyroAttributeData);i++)
        {
            int id = i;
            int class = CLASS_PYRO;
            int upgrade = playerDataList[client].pyroAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].pyroAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Spy
        for (int i=0;i<sizeof(playerDataList[client].spyAttributeData);i++)
        {
            int id = i;
            int class = CLASS_SPY;
            int upgrade = playerDataList[client].spyAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].spyAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Demoman
        for (int i=0;i<sizeof(playerDataList[client].demomanAttributeData);i++)
        {
            int id = i;
            int class = CLASS_DEMOMAN;
            int upgrade = playerDataList[client].demomanAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].demomanAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Sniper
        for (int i=0;i<sizeof(playerDataList[client].sniperAttributeData);i++)
        {
            int id = i;
            int class = CLASS_SNIPER;
            int upgrade = playerDataList[client].sniperAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].sniperAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Engineer
        for (int i=0;i<sizeof(playerDataList[client].engineerAttributeData);i++)
        {
            int id = i;
            int class = CLASS_ENGINEER;
            int upgrade = playerDataList[client].engineerAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].engineerAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Heavy
        for (int i=0;i<sizeof(playerDataList[client].heavyAttributeData);i++)
        {
            int id = i;
            int class = CLASS_HEAVY;
            int upgrade = playerDataList[client].heavyAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].heavyAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }    

        // ✅ Hale
        for (int i=0;i<sizeof(playerDataList[client].haleAttributeData);i++)
        {
            int id = i;
            int class = CLASS_HALE;
            int upgrade = playerDataList[client].haleAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].haleAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }

        // ✅ Shared
        for (int i=0;i<sizeof(playerDataList[client].sharedAttributeData);i++)
        {
            int id = i;
            int class = CLASS_SHARED;
            int upgrade = playerDataList[client].sharedAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].sharedAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }        
        
        // ✅ Weapon
        for (int i=0;i<sizeof(playerDataList[client].weaponAttributeData);i++)
        {
            int id = i;
            int class = CLASS_WEAPON;
            int upgrade = playerDataList[client].weaponAttributeData[i].upgrade;
            
            char query[512];
            
            DataPack dataPack = new DataPack();
            dataPack.WriteCell(client);            
            
            Format(query, sizeof(query), 
                "INSERT OR REPLACE INTO classAttributeData (steamid, uid, id, class, upgrade) VALUES ('%s', '%s', %d, %d, %d);", 
                playerDataList[client].steamid, playerDataList[client].weaponAttributeData[i].uid, id, class, upgrade);
        
            h_database.Query(OnReceiveUpdateAttributeData, query, dataPack, DBPrio_High);    
        }            
    }
}

void OnReceiveUpdateAttributeData(Database db, DBResultSet result, const char[] error, any data)
{
	DataPack dataPack = view_as<DataPack>(data);
	dataPack.Reset();
	
	if (db == null)
	{
		PrintToServer("OnReceiveUpdateAttributeData Database Null");
		delete dataPack;
		return;
	}
	
	if (result == null)
	{
		delete dataPack;
		return;
	}
	
	delete dataPack;
}

public void AddPermission(int client, int permission)
{
    int bit = permission % 32;
    playerDataList[client].permission &= ~(1 << bit);
}

public void RemovePermission(int client, int permission)
{
    int bit = permission % 32;
    playerDataList[client].permission &= ~(1 << bit);
}

public bool HasPermission(int client, int permission)
{

    int bit = permission % 32;
    return (playerDataList[client].permission & (1 << bit)) != 0;
}

public void SetPlayerPoints(int client, int point)
{
	playerDataList[client].point = point;
}

public void AddPlayerPoints(int client, int point)
{
	playerDataList[client].point += point;
}

public void TakePlayerPoints(int client, int point)
{
	playerDataList[client].point -= point;
}

public void SetPlayerEXP(int client, int exp)
{
	playerDataList[client].exp = exp;
}

public void AddPlayerEXP(int client, int exp)
{
	playerDataList[client].exp += exp;
	
	int delta = playerDataList[client].exp - expTable[playerDataList[client].level];

	
	if (playerDataList[client].level < (EXP_TABLE_SIZE - 1) && playerDataList[client].exp >= expTable[playerDataList[client].level])
	{
		TakePlayerEXP(client, playerDataList[client].exp);
	
		playerDataList[client].level++;
		
		char prefix[12];
		char prefixName[255];
		Format(prefix, sizeof(prefix), "[Lv%d]", playerDataList[client].level);
		Format(prefixName, sizeof(prefixName), "%s%s", prefix, playerDataList[client].basenick);
		SetClientInfo(client, "name", prefixName);
	
		AddPlayerEXP(client, delta);
		AddPlayerSkillPoint(client, g_GiveSkillPointOnLevelup);
		
		EmitSoundToClient(client, "misc/achievement_earned.wav", _, _, SNDLEVEL_RAIDSIREN);
		
		if(IsClientInGame(client) && IsPlayerAlive(client)){
            AttachParticle(client, "bl_killtaunt", "head", 0.0, 0.5);
            AttachParticle(client, "achieved", "head", 0.0, 0.5);  	
		}

		CPrintToChat(client, "{green}[레벨업]{default} 축하합니다! 레벨이 올라 {orange}%d{default} 레벨이 되었습니다!", playerDataList[client].level);
	}
}

public void TakePlayerEXP(int client, int exp)
{
	playerDataList[client].exp -= exp;
}

public void SetPlayerSkillPoint(int client, int skillpoint)
{
	playerDataList[client].skillpoint = skillpoint;
}

public void AddPlayerSkillPoint(int client, int skillpoint)
{
	playerDataList[client].skillpoint += skillpoint;
}

public void TakePlayerSkillPoint(int client, int skillpoint)
{
	playerDataList[client].skillpoint -= skillpoint;
}

public Action Timer_Update(Handle timer)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && playerDataList[i].isLoadComplete)
        {
            AddPlayerPoints(i, g_GivePointOnTimer);
            AddPlayerEXP(i, g_GiveExpOnTimer);
			CPrintToChat(i, "{olive}[EXP&Point]{default} 10분간 플레이하여 {rare}[%d 경험치]{default} {unique}[%d 포인트]{default}를 얻었습니다!", g_GiveExpOnTimer, g_GivePointOnTimer);
        }
    }

    return Plugin_Continue;
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

	PrintToServer("OnPlayerSPAWN : %d", client);

    if (client > 0 && (!IsClientInGame(client) || IsFakeClient(client) || !IsClientAuthorized(client)))
        return Plugin_Continue;

	int team = GetClientTeam(client);

	if (team == 2) {
		int value = g_redEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}		
	}
	else if (team == 3){
		int value = g_blueEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}	
	}

	TF2Attrib_RemoveAll(client);

    if (TF2_GetPlayerClass(client) == TFClass_Scout)
    {
		for (int i=0; i<sizeof(playerDataList[client].scoutAttributeData);i++)
		{
			int id = playerDataList[client].scoutAttributeData[i].id;
			int upgrade = playerDataList[client].scoutAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}
			
			float result = 0.0;
			
			if (scoutAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) + (float(upgrade) * scoutAttributeTable[id].value);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) - (float(upgrade) * scoutAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
		}	
    }
	else if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		for (int i=0; i<sizeof(playerDataList[client].medicAttributeData);i++)
		{
			int id = playerDataList[client].medicAttributeData[i].id;
			int upgrade = playerDataList[client].medicAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (medicAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) + (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) - (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
		}			
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		for (int i=0; i<sizeof(playerDataList[client].soldierAttributeData);i++)
		{
			int id = playerDataList[client].soldierAttributeData[i].id;
			int upgrade = playerDataList[client].soldierAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (soldierAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) + (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) - (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
		}			
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		for (int i=0; i<sizeof(playerDataList[client].pyroAttributeData);i++)
		{
			int id = playerDataList[client].pyroAttributeData[i].id;
			int upgrade = playerDataList[client].pyroAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (pyroAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) + (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) - (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
		}			
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		for (int i=0; i<sizeof(playerDataList[client].spyAttributeData);i++)
		{
			int id = playerDataList[client].spyAttributeData[i].id;
			int upgrade = playerDataList[client].spyAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (spyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) + (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) - (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
		}
					
	}
	else if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		for (int i=0; i<sizeof(playerDataList[client].demomanAttributeData);i++)
		{
			int id = playerDataList[client].demomanAttributeData[i].id;
			int upgrade = playerDataList[client].demomanAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (demomanAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) + (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) - (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
		}		
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		for (int i=0; i<sizeof(playerDataList[client].sniperAttributeData);i++)
		{
			int id = playerDataList[client].sniperAttributeData[i].id;
			int upgrade = playerDataList[client].sniperAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (sniperAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) + (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) - (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
		}		
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		for (int i=0; i<sizeof(playerDataList[client].engineerAttributeData);i++)
		{
			int id = playerDataList[client].engineerAttributeData[i].id;
			int upgrade = playerDataList[client].engineerAttributeData[i].upgrade;
			
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (engineerAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) + (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) - (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Heavy)
	{
		for (int i=0; i<sizeof(playerDataList[client].heavyAttributeData);i++)
		{
			int id = playerDataList[client].heavyAttributeData[i].id;
			int upgrade = playerDataList[client].heavyAttributeData[i].upgrade;
			
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (heavyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) + (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) - (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
		}			
	}	
	
	CreateTimer(0.5, Timer_ApplySharedAttribute, client);

    return Plugin_Continue;
}

public Action OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("damageamount");

    if ((attacker > 0 && victim > 0) && (!IsClientInGame(attacker) || attacker == victim || IsFakeClient(attacker)))
    {
        return Plugin_Continue;
    }

    playerDataList[attacker].damage += damage;

	int multiple = 1;
	
	if (playerDataList[attacker].damage >= g_GiveDamageStacked)
	{
		multiple = playerDataList[attacker].damage/g_GiveDamageStacked;
	
		for (int i=0;i<multiple;i++){
			AddPlayerEXP(attacker, g_GiveExpOnReachDamageStacked);
			AddPlayerPoints(attacker, g_GivePointOnReachDamageStacked);
		}	

		CPrintToChat(attacker, "{olive}[EXP&Point]{default} 데미지 누적 달성! 	{rare}[%d 경험치]{default} {unique}[%d 포인트]{default} 획득!", g_GiveExpOnReachDamageStacked * multiple, g_GivePointOnReachDamageStacked * multiple);
		
		playerDataList[attacker].damage -= multiple * g_GiveDamageStacked;
	}

    return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    ShowReviveMenu(victim);	

	if (attacker > 0 && IsClientInGame(attacker) && !IsFakeClient(attacker) && attacker != victim){
		AddPlayerEXP(attacker, g_GiveExpOnKilled);
		AddPlayerPoints(attacker, g_GivePointOnKilled);

		CPrintToChat(attacker, "{olive}[EXP&Point]{default} 적 처치! {rare}[%d 경험치]{default} {unique}[%d 포인트]{default} 획득!", g_GiveExpOnKilled, g_GivePointOnKilled);	
	}

    return Plugin_Continue;
}

public Action Command_LevelInfo(int client, int args)
{
    PrintToServer("Command_LevelInfo: Client %d", client);
    
    if (!IsClientInGame(client) || IsFakeClient(client))
    {
        PrintToServer("Command_LevelInfo: Invalid client");
        return Plugin_Handled;
    }
    
    // ❌ 이 체크 제거!
    /*
    if (!playerDataList[client].isLoadComplete)
    {
        CPrintToChat(client, "{red}[Levelup]{default} 데이터 로딩 중... 잠시 후 다시 시도하세요.");
        return Plugin_Handled;
    }
    */
    
    // ✅ 연결 여부만 체크
    if (!IsClientAuthorized(client))
    {
        CPrintToChat(client, "{red}[Levelup]{default} 인증 중... 잠시 후 다시 시도하세요.");
        return Plugin_Handled;
    }
    
    PrintToServer("Command_LevelInfo: Opening menu for client %d", client);
    
    ShowMainMenu(client);

    return Plugin_Handled;
}

void ShowMainMenu(int client)
{
    Menu menu = CreateMenu(MainMenuHandler);
    menu.SetTitle("<< 수상한 거래 서버에 오신걸 환영합니다 >>");

    menu.AddItem("info",      "내정보");
    menu.AddItem("classStat",      "클래스 스탯");
    menu.AddItem("shop",      "상점");
    menu.AddItem("weaponStat",   "무기 강화");
    menu.AddItem("revive",    "부활권");
    menu.AddItem("inventory", "인벤토리");
    menu.AddItem("skillReset", "스킬초기화");

    menu.ExitButton = true; // 0. 종료

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }

    if (action != MenuAction_Select)
        return 0;

    char info[32];
    menu.GetItem(item, info, sizeof(info));

    if (StrEqual(info, "info"))
    {
        ShowPlayerInfoMenu(client);
    }
	else if (StrEqual(info, "classStat"))
	{
		ShowClassStatMenu(client);
	}
	else if (StrEqual(info, "revive"))
	{
		ShowReviveMenu(client);
	}
	else if (StrEqual(info, "skillReset"))
	{
		ShowSkillResetMenu(client);
	}
	else if (StrEqual(info, "weaponStat"))
	{
		ShowWeaponUpgradeMenu(client);
	}
    else
    {
        PrintToChat(client, "아직 구현되지 않은 메뉴입니다: %s", info);
    }

    return 0;
}

void ShowPlayerInfoMenu(int client)
{
    Menu menu = CreateMenu(InfoMenuHandler);

    char buffer[128];

	char name[64];
	GetClientName(client, name, sizeof(name));

    menu.SetTitle("당신의 정보입니다.");

    Format(buffer, sizeof(buffer), "이름 : %s", name);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    Format(buffer, sizeof(buffer), "돈 : %d", playerDataList[client].point);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    Format(buffer, sizeof(buffer), "레벨 : %d", playerDataList[client].level);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    Format(buffer, sizeof(buffer), "경험치 : %d/%d", playerDataList[client].exp, expTable[playerDataList[client].level]);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    Format(buffer, sizeof(buffer), "강화 : %d", g_maxUpgrade);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    Format(buffer, sizeof(buffer), "남은 스킬포인트 : %d", playerDataList[client].skillpoint);
    menu.AddItem("", buffer, ITEMDRAW_DISABLED);

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    menu.Display(client, MENU_TIME_FOREVER);
}

public int InfoMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "back"))
		{
			ShowMainMenu(client);
		}
    }

    return 0;
}

void ShowClassStatMenu(int client)
{
    Menu menu = CreateMenu(ClassStatMenuHandler);
	menu.SetTitle("클래스 스탯");


    menu.AddItem("scout",      "스카웃");
	menu.AddItem("soldier",      "솔져");
	menu.AddItem("pyro",   "파이로");
	menu.AddItem("demoman", "데모맨");
	menu.AddItem("heavy", "헤비");
	menu.AddItem("engineer", "엔지니어");
    menu.AddItem("medic",      "메딕");
    menu.AddItem("sniper", "스나이퍼");
    menu.AddItem("spy",    "스파이");
    menu.AddItem("hale", "헤일(사용불가)");
    menu.AddItem("shared", "공용");

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    menu.Display(client, MENU_TIME_FOREVER);
}

public int ClassStatMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "back"))
		{
			ShowMainMenu(client);
		}
		else if (StrEqual(info, "scout"))
		{
			ShowClassStatMenu2(client, "scout");
		}
		else if (StrEqual(info, "medic"))
		{
			ShowClassStatMenu2(client, "medic");
		}
		else if (StrEqual(info, "soldier"))
		{
			ShowClassStatMenu2(client, "soldier");
		}
		else if (StrEqual(info, "pyro"))
		{
			ShowClassStatMenu2(client, "pyro");
		}
		else if (StrEqual(info, "spy"))
		{
			ShowClassStatMenu2(client, "spy");
		}
		else if (StrEqual(info, "demoman"))
		{
			ShowClassStatMenu2(client, "demoman");
		}
		else if (StrEqual(info, "sniper"))
		{
			ShowClassStatMenu2(client, "sniper");
		}
		else if (StrEqual(info, "engineer"))
		{
			ShowClassStatMenu2(client, "engineer");
		}	
		else if (StrEqual(info, "heavy"))
		{
			ShowClassStatMenu2(client, "heavy");
		}
		else if (StrEqual(info, "hale"))
		{
			ShowClassStatMenu2(client, "hale");
		}				
		else if (StrEqual(info, "shared"))
		{
			ShowClassStatMenu2(client, "shared");
		}			
    }

    return 0;
}

void ShowClassStatMenu2(int client, char[] classID){
    Menu menu = CreateMenu(ClassStatMenu2Handler);
    
    if (StrEqual(classID, "scout"))
    {
        menu.SetTitle("스카웃");
        
        for (int i=0;i<sizeof(scoutAttributeTable);i++){
            if (!StrEqual(scoutAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", scoutAttributeTable[i].title);
                
                if (scoutAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, scoutAttributeTable[i].point, playerDataList[client].scoutAttributeData[i].upgrade, scoutAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, scoutAttributeTable[i].value, scoutAttributeTable[i].point, playerDataList[client].scoutAttributeData[i].upgrade, scoutAttributeTable[i].max);
                }
                
                char key[64];
                Format(key, sizeof(key), "scout_%s", scoutAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }    
    }
    else if (StrEqual(classID, "medic"))
    {
        menu.SetTitle("메딕");
        
        for (int i=0;i<sizeof(medicAttributeTable);i++){
            if (!StrEqual(medicAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", medicAttributeTable[i].title);
                
                if (medicAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, medicAttributeTable[i].point, playerDataList[client].medicAttributeData[i].upgrade, medicAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, medicAttributeTable[i].value, medicAttributeTable[i].point, playerDataList[client].medicAttributeData[i].upgrade, medicAttributeTable[i].max);
                }
                
                char key[64];
                Format(key, sizeof(key), "medic_%s", medicAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "soldier"))
    {
        menu.SetTitle("솔져");
        
        for (int i=0;i<sizeof(soldierAttributeTable);i++){
            if (!StrEqual(soldierAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", soldierAttributeTable[i].title);
                if (soldierAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, soldierAttributeTable[i].point, playerDataList[client].soldierAttributeData[i].upgrade, soldierAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, soldierAttributeTable[i].value, soldierAttributeTable[i].point, playerDataList[client].soldierAttributeData[i].upgrade, soldierAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "soldier_%s", soldierAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "pyro"))
    {
        menu.SetTitle("파이로");
        
        for (int i=0;i<sizeof(pyroAttributeTable);i++){
            if (!StrEqual(pyroAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", pyroAttributeTable[i].title);
                if (pyroAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, pyroAttributeTable[i].point, playerDataList[client].pyroAttributeData[i].upgrade, pyroAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, pyroAttributeTable[i].value, pyroAttributeTable[i].point, playerDataList[client].pyroAttributeData[i].upgrade, pyroAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "pyro_%s", pyroAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "spy"))
    {
        menu.SetTitle("스파이");
        
        for (int i=0;i<sizeof(spyAttributeTable);i++){
            if (!StrEqual(spyAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", spyAttributeTable[i].title);
                if (spyAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, spyAttributeTable[i].point, playerDataList[client].spyAttributeData[i].upgrade, spyAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, spyAttributeTable[i].value, spyAttributeTable[i].point, playerDataList[client].spyAttributeData[i].upgrade, spyAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "spy_%s", spyAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }
    }
    else if (StrEqual(classID, "demoman"))
    {
        menu.SetTitle("데모맨");
        
        for (int i=0;i<sizeof(demomanAttributeTable);i++){
            if (!StrEqual(demomanAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", demomanAttributeTable[i].title);
                if (demomanAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, demomanAttributeTable[i].point, playerDataList[client].demomanAttributeData[i].upgrade, demomanAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, demomanAttributeTable[i].value, demomanAttributeTable[i].point, playerDataList[client].demomanAttributeData[i].upgrade, demomanAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "demoman_%s", demomanAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "sniper"))
    {
        menu.SetTitle("스나이퍼");
        
        for (int i=0;i<sizeof(sniperAttributeTable);i++){
            if (!StrEqual(sniperAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", sniperAttributeTable[i].title);
                if (sniperAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, sniperAttributeTable[i].point, playerDataList[client].sniperAttributeData[i].upgrade, sniperAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, sniperAttributeTable[i].value, sniperAttributeTable[i].point, playerDataList[client].sniperAttributeData[i].upgrade, sniperAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "sniper_%s", sniperAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "engineer"))
    {
        menu.SetTitle("엔지니어");
        
        for (int i=0;i<sizeof(engineerAttributeTable);i++){
            if (!StrEqual(engineerAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", engineerAttributeTable[i].title);
                if (engineerAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, engineerAttributeTable[i].point, playerDataList[client].engineerAttributeData[i].upgrade, engineerAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, engineerAttributeTable[i].value, engineerAttributeTable[i].point, playerDataList[client].engineerAttributeData[i].upgrade, engineerAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "engineer_%s", engineerAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }    
    else if (StrEqual(classID, "heavy"))
    {
        menu.SetTitle("헤비");
        
        for (int i=0;i<sizeof(heavyAttributeTable);i++){
            if (!StrEqual(heavyAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", heavyAttributeTable[i].title);
                if (heavyAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, heavyAttributeTable[i].point, playerDataList[client].heavyAttributeData[i].upgrade, heavyAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, heavyAttributeTable[i].value, heavyAttributeTable[i].point, playerDataList[client].heavyAttributeData[i].upgrade, heavyAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "heavy_%s", heavyAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }
    else if (StrEqual(classID, "hale"))
    {
        menu.SetTitle("헤일(사용불가)");
        
        for (int i=0;i<sizeof(haleAttributeTable);i++){
            if (!StrEqual(haleAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", haleAttributeTable[i].title);
                if (haleAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, haleAttributeTable[i].point, playerDataList[client].haleAttributeData[i].upgrade, haleAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, haleAttributeTable[i].value, haleAttributeTable[i].point, playerDataList[client].haleAttributeData[i].upgrade, haleAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "hale_%s", haleAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }        
    }    
    else if (StrEqual(classID, "shared"))
    {
        menu.SetTitle("공용");
        
        for (int i=0;i<sizeof(sharedAttributeTable);i++){
            if (!StrEqual(sharedAttributeTable[i].uid, "")){
                // ✅ buffer 변수 선언
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", sharedAttributeTable[i].title);
                if (sharedAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, sharedAttributeTable[i].point, playerDataList[client].sharedAttributeData[i].upgrade, sharedAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, sharedAttributeTable[i].value, sharedAttributeTable[i].point, playerDataList[client].sharedAttributeData[i].upgrade, sharedAttributeTable[i].max);
                }
                char key[64];
                Format(key, sizeof(key), "shared_%s", sharedAttributeTable[i].uid);

                menu.AddItem(key, buffer);        
            }            
        }            
    }
    
    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    if (prevOpenMenuPage == -1){
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else{
        DisplayMenuAtItem(menu, client, prevOpenMenuPage, MENU_TIME_FOREVER);
    }
    
    prevOpenMenuPage = -1;
}

public int ClassStatMenu2Handler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "back"))
        {
            ShowClassStatMenu(client);
        }
        else if (StrContains(info, "scout") != -1)
        {
            if (scoutAttributeTable[item].max > playerDataList[client].scoutAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= scoutAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= scoutAttributeTable[item].point;
                    playerDataList[client].scoutAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Scout[%d] upgrade=%d", 
                                 client, item, playerDataList[client].scoutAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }            
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "scout");
        }
        else if (StrContains(info, "medic") != -1)
        {
            if (medicAttributeTable[item].max > playerDataList[client].medicAttributeData[item].upgrade)
            {        
                if (playerDataList[client].skillpoint >= medicAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= medicAttributeTable[item].point;
                    playerDataList[client].medicAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Medic[%d] upgrade=%d", 
                                 client, item, playerDataList[client].medicAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "medic");
        }
        else if (StrContains(info, "soldier") != -1)
        {
            if (soldierAttributeTable[item].max > playerDataList[client].soldierAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= soldierAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= soldierAttributeTable[item].point;
                    playerDataList[client].soldierAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Soldier[%d] upgrade=%d", 
                                 client, item, playerDataList[client].soldierAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "soldier");
        }
        else if (StrContains(info, "pyro") != -1)
        {
            if (pyroAttributeTable[item].max > playerDataList[client].pyroAttributeData[item].upgrade)
            {    
                if (playerDataList[client].skillpoint >= pyroAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= pyroAttributeTable[item].point;
                    playerDataList[client].pyroAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Pyro[%d] upgrade=%d", 
                                 client, item, playerDataList[client].pyroAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "pyro");
        }
        else if (StrContains(info, "spy") != -1)
        {
            if (spyAttributeTable[item].max > playerDataList[client].spyAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= spyAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= spyAttributeTable[item].point;
                    playerDataList[client].spyAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Spy[%d] upgrade=%d", 
                                 client, item, playerDataList[client].spyAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "spy");
        }
        else if (StrContains(info, "demoman") != -1)
        {
            if (demomanAttributeTable[item].max > playerDataList[client].demomanAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= demomanAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= demomanAttributeTable[item].point;
                    playerDataList[client].demomanAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Demoman[%d] upgrade=%d", 
                                 client, item, playerDataList[client].demomanAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }

            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "demoman");
        }    
        else if (StrContains(info, "sniper") != -1)
        {
            if (sniperAttributeTable[item].max > playerDataList[client].sniperAttributeData[item].upgrade)
            {    
                if (playerDataList[client].skillpoint >= sniperAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= sniperAttributeTable[item].point;
                    playerDataList[client].sniperAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Sniper[%d] upgrade=%d", 
                                 client, item, playerDataList[client].sniperAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }    

            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "sniper");                    
        }    
        else if (StrContains(info, "engineer") != -1)
        {
            if (engineerAttributeTable[item].max > playerDataList[client].engineerAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= engineerAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= engineerAttributeTable[item].point;
                    playerDataList[client].engineerAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Engineer[%d] upgrade=%d", 
                                 client, item, playerDataList[client].engineerAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "engineer");
        }
        else if (StrContains(info, "heavy") != -1)
        {
            if (heavyAttributeTable[item].max > playerDataList[client].heavyAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= heavyAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= heavyAttributeTable[item].point;
                    playerDataList[client].heavyAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Heavy[%d] upgrade=%d", 
                                 client, item, playerDataList[client].heavyAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }

            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "heavy");
        }    
        else if (StrContains(info, "hale") != -1)
        {
            if (haleAttributeTable[item].max > playerDataList[client].haleAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= haleAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= haleAttributeTable[item].point;
                    playerDataList[client].haleAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Hale[%d] upgrade=%d", 
                                 client, item, playerDataList[client].haleAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }    
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "hale");
            
        }    
        else if (StrContains(info, "shared") != -1)
        {
            if (sharedAttributeTable[item].max > playerDataList[client].sharedAttributeData[item].upgrade)
            {            
                if (playerDataList[client].skillpoint >= sharedAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= sharedAttributeTable[item].point;
                    playerDataList[client].sharedAttributeData[item].upgrade++;
                    
                    // ✅ 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);
                    
                    PrintToServer("✅ 스탯 찍음: Client %d - Shared[%d] upgrade=%d", 
                                 client, item, playerDataList[client].sharedAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }
            
            prevOpenMenuPage = GetMenuSelectionPosition();
            
            ShowClassStatMenu2(client, "shared");
        }        
    }

    return 0;
}

void ShowReviveMenu(int client)
{

	int team = GetClientTeam(client);

	if (team == 3){
		CPrintToChat(client, "{red}[경고]{default} 블루팀은 리스폰 메뉴를 사용할 수 없습니다!");
		
		return;
	}

    Menu menu = CreateMenu(ShowReviveMenuHandler);
	
    char titleBuffer[512];
	Format(titleBuffer, sizeof(titleBuffer), "헤일 모드 - 부활 메뉴\n―――――――――――――――――\n현재 사용가능한 포인트 : %d\n―――――――――――――――――\n포인트를 사용하면 즉시 부활합니다.\n라운드 시간이 지나거나 부활하면 가격이 비싸집니다.", 
	playerDataList[client].point);	
	menu.SetTitle(titleBuffer);

    char pointBuffer[128];
	Format(pointBuffer, sizeof(pointBuffer), "%d원으로 부활합니다.(%d회 남음)", playerDataList[client].revivePoint, playerDataList[client].reviveCount);

	menu.AddItem("accept", pointBuffer);
	menu.AddItem("cancel", "부활하지 않습니다.");

    menu.ExitButton = true;

    menu.Display(client, MENU_TIME_FOREVER);
}

public int ShowReviveMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "accept"))
		{
			if (!IsClientInGame(client) || IsPlayerAlive(client))
			{
				PrintToChat(client, "당신은 이미 살아있습니다!");
				return 0;
			}
			
			if (playerDataList[client].point < playerDataList[client].revivePoint)
			{
				PrintToChat(client, "포인트가 부족합니다!");
				return 0;
			}
			
			if (playerDataList[client].reviveCount <= 0)
			{
				PrintToChat(client, "부활 횟수를 전부 소진하였습니다!");
				return 0;	
			}

			TakePlayerPoints(client, playerDataList[client].revivePoint);

			playerDataList[client].revivePoint *= g_addRevivePointOnRevive;
			playerDataList[client].reviveCount--;

			TF2_RespawnPlayer(client);
			
			EmitSoundToAll("misc/point_revive.mp3");
			TF2_AddCondition(client, TFCond_Ubercharged, 3.0);

			
			char respawnText[256];
			Format(respawnText, sizeof(respawnText),
			"%s님이 부활권을 사용하여 부활하였습니다.", playerDataList[client].basenick);					
		
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == 3)
				{
					HealClient(i, g_healOnRevive);
				}
			}
		
			for (int i = 1; i <= MaxClients; i++){
				if (!IsClientInGame(i) || IsFakeClient(i)) {
					continue;
				}
				
				PrintCenterText(i, respawnText);
			}	
		}
		else if (StrEqual(info, "cancel"))
		{
			delete menu;
		}
    }

    return 0;
}

void ShowSkillResetMenu(int client)
{
    Menu menu = CreateMenu(ShowSkillResetMenuHandler);
	
    char titleBuffer[512];
	Format(titleBuffer, sizeof(titleBuffer), "헤일 모드 - 스킬 초기화\n―――――――――――――――――\n―――――――――――――――――\n포인트를 사용하면 스킬을 초기화합니다.\n", 
	playerDataList[client].point);	
	menu.SetTitle(titleBuffer);

    char pointBuffer[128];
	Format(pointBuffer, sizeof(pointBuffer), "%d원으로 초기화합니다.", g_skillResetPoint);

	menu.AddItem("accept", pointBuffer);
	menu.AddItem("cancel", "초기화하지 않습니다.");

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    menu.Display(client, MENU_TIME_FOREVER);
}

public int ShowSkillResetMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "accept"))
		{
			if (playerDataList[client].point < g_skillResetPoint)
			{
				PrintToChat(client, "⚠️ 포인트가 부족합니다!");
				return 0;
			}

			TakePlayerPoints(client, g_skillResetPoint);

			
			for (int i=0;i<sizeof(playerDataList[client].scoutAttributeData);i++){
				int upgrade = playerDataList[client].scoutAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].scoutAttributeData[i].upgrade = 0;
				}
			}
			
			for (int i=0;i<sizeof(playerDataList[client].medicAttributeData);i++){
				int upgrade = playerDataList[client].medicAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].medicAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].soldierAttributeData);i++){
				int upgrade = playerDataList[client].soldierAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].soldierAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].pyroAttributeData);i++){
				int upgrade = playerDataList[client].pyroAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].pyroAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].spyAttributeData);i++){
				int upgrade = playerDataList[client].spyAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].spyAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].demomanAttributeData);i++){
				int upgrade = playerDataList[client].demomanAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].demomanAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].sniperAttributeData);i++){
				int upgrade = playerDataList[client].sniperAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].sniperAttributeData[i].upgrade = 0;
				}
			}	

			for (int i=0;i<sizeof(playerDataList[client].engineerAttributeData);i++){
				int upgrade = playerDataList[client].engineerAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].engineerAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].heavyAttributeData);i++){
				int upgrade = playerDataList[client].heavyAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].heavyAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].haleAttributeData);i++){
				int upgrade = playerDataList[client].haleAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].haleAttributeData[i].upgrade = 0;
				}
			}

			for (int i=0;i<sizeof(playerDataList[client].sharedAttributeData);i++){
				int upgrade = playerDataList[client].sharedAttributeData[i].upgrade;
				
				if (upgrade > 0)
				{
					//skillpoint += upgrade;
					
					playerDataList[client].sharedAttributeData[i].upgrade = 0;
				}
			}	

			playerDataList[client].skillpoint = 0;
			playerDataList[client].skillpoint += playerDataList[client].level * 3;
		}
		else if (StrEqual(info, "cancel"))
		{

		}
    }

    return 0;
}

void ShowWeaponUpgradeMenu(int client)
{
    Menu menu = CreateMenu(ShowWeaponUpgradeMenuHandler);
	
    char titleBuffer[1024];

	Format(titleBuffer, sizeof(titleBuffer), "헤일 모드 - 강화 메뉴\n―――――――――――――――――\n현재 사용가능한 포인트 : %d\n―――――――――――――――――\n현재 강화 %d -> %d로 강화\n강화 성공 %.0f%%\n강화 실패 %.0f%%\n강화 파괴 %.0f%%\n―――――――――――――――――\n강화 하시겠습니까?", 
	playerDataList[client].point, playerDataList[client].weaponAttributeData[0].upgrade, playerDataList[client].weaponAttributeData[0].upgrade + 1, 
	weaponUpgradeSuccessTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100), weaponUpgradeMissTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100),
	weaponUpgradeResetTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100));	
	menu.SetTitle(titleBuffer);

	char yesBuffer[128];
	Format(yesBuffer, sizeof(yesBuffer), "예(%d)", weaponUpgradeCostTable[playerDataList[client].weaponAttributeData[0].upgrade]);

	menu.AddItem("accept", yesBuffer);
	menu.AddItem("cancel", "아니오");

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    menu.Display(client, MENU_TIME_FOREVER);
}

public int ShowWeaponUpgradeMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
		char info[32];
		menu.GetItem(item, info, sizeof(info));

		if (StrEqual(info, "accept"))
		{
			int upgrade = playerDataList[client].weaponAttributeData[0].upgrade;
		
			if (playerDataList[client].point < weaponUpgradeCostTable[upgrade])
			{
				PrintToChat(client, "포인트가 부족합니다!");
				return 0;
			}

			PrintCenterText(client, "강화 중 ...");
			PrintToChat(client, "강화 중 ...");
			EmitSoundToClient(client, "misc/reinforcement.mp3", _, _, SNDLEVEL_RAIDSIREN);
			CreateTimer(5.5, Timer_WeaponUpgrade, client);
		}
		else if (StrEqual(info, "back"))
		{
			ShowMainMenu(client);
		}
    }

    return 0;
}

public Action Timer_WeaponUpgrade(Handle timer, any client)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	PrintToServer("TEST TIMER 1");

	int upgrade = playerDataList[client].weaponAttributeData[0].upgrade;
	int random = GetRandomInt(1, 100);
	
	int successPercent = RoundToFloor(weaponUpgradeSuccessTable[upgrade] * float(100));
	int missPercent = RoundToFloor(weaponUpgradeMissTable[upgrade] * float(100));
	int resetPercent = RoundToFloor(weaponUpgradeResetTable[upgrade] * float(100));

	TakePlayerPoints(client, weaponUpgradeCostTable[upgrade]);	

	char upgradeText[256];

	PrintToServer("Success : %.0f %.0f %.0f", weaponUpgradeSuccessTable[upgrade], float(100), weaponUpgradeSuccessTable[upgrade] * float(100));
	PrintToServer("Random : %d", random);
	PrintToServer("Success Percent : %d", successPercent);
	
	if (random <= successPercent){
		Format(upgradeText, sizeof(upgradeText),
		"%d번째 강화에 성공하였습니다.", upgrade + 1);
		PrintToChat(client, upgradeText);
		PrintCenterText(client, upgradeText);
	
		if (upgrade + 1 >= 7){
			Format(upgradeText, sizeof(upgradeText),
			"%s님이 %d번째 강화에 성공했습니다.", playerDataList[client].basenick, upgrade + 1);					
			PrintToChat(client, upgradeText);

			for (int i = 1; i <= MaxClients; i++){
				if (!IsClientInGame(i) || IsFakeClient(i)) {
					continue;
				}
					
				PrintCenterText(i, upgradeText);
			}

			EmitSoundToAll("misc/success1.mp3");
		}
		else
		{
			EmitSoundToClient(client, "misc/success1.mp3", _, _, SNDLEVEL_RAIDSIREN);
		}

		playerDataList[client].weaponAttributeData[0].upgrade++;
	}
	else{
		random -= successPercent;
		
		PrintToServer("Miss Percent : %d %d", random, missPercent);
		
		if (random <= missPercent){
			Format(upgradeText, sizeof(upgradeText),
			"%d번째 강화에 실패했습니다.", upgrade + 1);		
			PrintToChat(client, upgradeText);
			PrintCenterText(client, upgradeText);
			
			if (upgrade + 1 >= 7){
				Format(upgradeText, sizeof(upgradeText),
				"%s님이 %d번째 강화에 실패했습니다.", playerDataList[client].basenick, upgrade + 1);					
				
				for (int i = 1; i <= MaxClients; i++){
					if (!IsClientInGame(i) || IsFakeClient(i)) {
						continue;
					}
						
					PrintCenterText(i, upgradeText);
				}

				EmitSoundToAll("misc/miss1.mp3");
			}
			else
			{
				EmitSoundToClient(client, "misc/miss1.mp3", _, _, SNDLEVEL_RAIDSIREN);
			}
		}
		else{
			if (resetPercent > 0){
				Format(upgradeText, sizeof(upgradeText),
				"%d번째 강화에 대실패했습니다.", upgrade + 1);		
				PrintToChat(client, upgradeText);	
				PrintCenterText(client, upgradeText);
				
				if (upgrade + 1 >= 7){
					Format(upgradeText, sizeof(upgradeText),
					"%s님이 %d번째 강화에 대실패 했습니다.", playerDataList[client].basenick, upgrade + 1);					
					
					for (int i = 1; i <= MaxClients; i++){
						if (!IsClientInGame(i) || IsFakeClient(i)) {
							continue;
						}
							
						PrintCenterText(i, upgradeText);
					}		

					EmitSoundToAll("misc/failed1.mp3");
				}
				else
				{
					EmitSoundToClient(client, "misc/failed1.mp3", _, _, SNDLEVEL_RAIDSIREN);
				}

				playerDataList[client].weaponAttributeData[0].upgrade = 0;
			}
		}
	}

	PrintToServer("TEST TIMER 2");

	ShowWeaponUpgradeMenu(client);

	PrintToServer("TEST TIMER 3");

	return Plugin_Continue;
}

void CreateAttributeTable()
{
	scoutAttributeTable[0].class = CLASS_SCOUT;
	scoutAttributeTable[0].max = 5;
	scoutAttributeTable[0].point = 1;
	scoutAttributeTable[0].uid = "move speed bonus";
	scoutAttributeTable[0].value = float(3);
	scoutAttributeTable[0].defaultValue = float(100);
	scoutAttributeTable[0].additiveMode = ADDITIVE_PERCENT;
	scoutAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	scoutAttributeTable[1].class = CLASS_SCOUT;
	scoutAttributeTable[1].max = 10;
	scoutAttributeTable[1].point = 1;
	scoutAttributeTable[1].uid = "increased jump height";
	scoutAttributeTable[1].value = float(5);
	scoutAttributeTable[1].defaultValue = float(100);
	scoutAttributeTable[1].additiveMode = ADDITIVE_PERCENT;	
	scoutAttributeTable[1].title = "점프높이 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[2].class = CLASS_SCOUT;
	scoutAttributeTable[2].max = 10;
	scoutAttributeTable[2].point = 1;
	scoutAttributeTable[2].uid = "fire rate bonus";
	scoutAttributeTable[2].value = float(5);
	scoutAttributeTable[2].defaultValue = float(100);
	scoutAttributeTable[2].additiveMode = MINUS_PERCENT;	
	scoutAttributeTable[2].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[3].class = CLASS_SCOUT;
	scoutAttributeTable[3].max = 10;
	scoutAttributeTable[3].point = 1;
	scoutAttributeTable[3].uid = "Reload time decreased";
	scoutAttributeTable[3].value = float(5);
	scoutAttributeTable[3].defaultValue = float(100);
	scoutAttributeTable[3].additiveMode = MINUS_PERCENT;		
	scoutAttributeTable[3].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	scoutAttributeTable[4].class = CLASS_SCOUT; 
	scoutAttributeTable[4].max = 3;
	scoutAttributeTable[4].point = 1;
	scoutAttributeTable[4].uid = "deploy time decreased";
	scoutAttributeTable[4].value = float(15);
	scoutAttributeTable[4].defaultValue = float(100);
	scoutAttributeTable[4].additiveMode = MINUS_PERCENT;		
	scoutAttributeTable[4].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[5].class = CLASS_SCOUT; 
	scoutAttributeTable[5].max = 5;
	scoutAttributeTable[5].point = 1;
	scoutAttributeTable[5].uid = "heal on hit for rapidfire";
	scoutAttributeTable[5].value = float(2);
	scoutAttributeTable[5].defaultValue = float(0);
	scoutAttributeTable[5].additiveMode = ADDITIVE_NUMBER;		
	scoutAttributeTable[5].title = "적중 시 체력 %.0f 회복 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[6].class = CLASS_SCOUT; 
	scoutAttributeTable[6].max = 5;
	scoutAttributeTable[6].point = 2;
	scoutAttributeTable[6].uid = "damage bonus HIDDEN";
	scoutAttributeTable[6].value = float(1);
	scoutAttributeTable[6].defaultValue = float(100);
	scoutAttributeTable[6].additiveMode = ADDITIVE_PERCENT;		
	scoutAttributeTable[6].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	scoutAttributeTable[7].class = CLASS_SCOUT; 
	scoutAttributeTable[7].max = 5;
	scoutAttributeTable[7].point = 2;
	scoutAttributeTable[7].uid = "effect bar recharge rate increased";
	scoutAttributeTable[7].value = float(5);
	scoutAttributeTable[7].defaultValue = float(100);
	scoutAttributeTable[7].additiveMode = MINUS_PERCENT;		
	scoutAttributeTable[7].title = "재충전속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	scoutAttributeTable[8].class = CLASS_SCOUT; 
	scoutAttributeTable[8].max = 5;
	scoutAttributeTable[8].point = 2;
	scoutAttributeTable[8].uid = "max health additive bonus";
	scoutAttributeTable[8].value = float(10);
	scoutAttributeTable[8].defaultValue = float(0);
	scoutAttributeTable[8].additiveMode = ADDITIVE_NUMBER;	
	scoutAttributeTable[8].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";		
	
	scoutAttributeTable[9].class = CLASS_SCOUT; 
	scoutAttributeTable[9].max = 4;
	scoutAttributeTable[9].point = 3;
	scoutAttributeTable[9].uid = "clip size bonus";
	scoutAttributeTable[9].value = float(50);
	scoutAttributeTable[9].defaultValue = float(100);
	scoutAttributeTable[9].additiveMode = ADDITIVE_PERCENT;	
	scoutAttributeTable[9].title = "장탄수 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[10].class = CLASS_SCOUT; 
	scoutAttributeTable[10].max = 2;
	scoutAttributeTable[10].point = 3;
	scoutAttributeTable[10].uid = "weapon spread bonus";
	scoutAttributeTable[10].value = float(25);
	scoutAttributeTable[10].defaultValue = float(0);
	scoutAttributeTable[10].additiveMode = MINUS_PERCENT;		
	scoutAttributeTable[10].title = "집탄률 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	scoutAttributeTable[11].class = CLASS_SCOUT; 
	scoutAttributeTable[11].max = 2;
	scoutAttributeTable[11].point = 4;
	scoutAttributeTable[11].uid = "bullets per shot bonus";
	scoutAttributeTable[11].value = float(50);
	scoutAttributeTable[11].defaultValue = float(100);
	scoutAttributeTable[11].additiveMode = ADDITIVE_PERCENT;	
	scoutAttributeTable[11].title = "발사되는 탄환수 %.0f%% 증가 (%dpt)(%d/%d)";	

	scoutAttributeTable[12].class = CLASS_SCOUT;
	scoutAttributeTable[12].max = 1;
	scoutAttributeTable[12].point = 5;
	scoutAttributeTable[12].uid = "cancel falling damage";
	scoutAttributeTable[12].value = float(100);
	scoutAttributeTable[12].defaultValue = float(0);
	scoutAttributeTable[12].additiveMode = ADDITIVE_PERCENT;	
	scoutAttributeTable[12].isDisableDrawValue = true;
	scoutAttributeTable[12].title = "낙하 피해 무시 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[0].class = CLASS_SOLDIER;
	soldierAttributeTable[0].max = 5;
	soldierAttributeTable[0].point = 1;
	soldierAttributeTable[0].uid = "move speed bonus";
	soldierAttributeTable[0].value = float(3);
	soldierAttributeTable[0].defaultValue = float(100);
	soldierAttributeTable[0].additiveMode = ADDITIVE_PERCENT;		
	soldierAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	soldierAttributeTable[1].class = CLASS_SOLDIER;
	soldierAttributeTable[1].max = 10;
	soldierAttributeTable[1].point = 1;
	soldierAttributeTable[1].uid = "fire rate bonus";
	soldierAttributeTable[1].value = float(5);
	soldierAttributeTable[1].defaultValue = float(100);
	soldierAttributeTable[1].additiveMode = MINUS_PERCENT;	
	soldierAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[2].class = CLASS_SOLDIER;
	soldierAttributeTable[2].max = 10;
	soldierAttributeTable[2].point = 1;
	soldierAttributeTable[2].uid = "Reload time decreased";
	soldierAttributeTable[2].value = float(5);
	soldierAttributeTable[2].defaultValue = float(100);
	soldierAttributeTable[2].additiveMode = MINUS_PERCENT;	
	soldierAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";		

	soldierAttributeTable[3].class = CLASS_SOLDIER;
	soldierAttributeTable[3].max = 3;
	soldierAttributeTable[3].point = 1;
	soldierAttributeTable[3].uid = "deploy time decreased";
	soldierAttributeTable[3].value = float(15);
	soldierAttributeTable[3].defaultValue = float(100);
	soldierAttributeTable[3].additiveMode = MINUS_PERCENT;	
	soldierAttributeTable[3].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	soldierAttributeTable[4].class = CLASS_SOLDIER;
	soldierAttributeTable[4].max = 5;
	soldierAttributeTable[4].point = 1;
	soldierAttributeTable[4].uid = "heal on hit for rapidfire";
	soldierAttributeTable[4].value = float(5);
	soldierAttributeTable[4].defaultValue = float(0);
	soldierAttributeTable[4].additiveMode = ADDITIVE_NUMBER;		
	soldierAttributeTable[4].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[5].class = CLASS_SOLDIER;
	soldierAttributeTable[5].max = 5;
	soldierAttributeTable[5].point = 2;
	soldierAttributeTable[5].uid = "damage bonus HIDDEN";
	soldierAttributeTable[5].value = float(1);
	soldierAttributeTable[5].defaultValue = float(100);
	soldierAttributeTable[5].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[5].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	soldierAttributeTable[6].class = CLASS_SOLDIER;
	soldierAttributeTable[6].max = 10;
	soldierAttributeTable[6].point = 2;
	soldierAttributeTable[6].uid = "rocket jump damage reduction";
	soldierAttributeTable[6].value = float(5);
	soldierAttributeTable[6].defaultValue = float(100);
	soldierAttributeTable[6].additiveMode = MINUS_PERCENT;	
	soldierAttributeTable[6].title = "로켓점프 피해 %.0f%% 감소 (%dpt)(%d/%d)";
	
	soldierAttributeTable[7].class = CLASS_SOLDIER;
	soldierAttributeTable[7].max = 5;
	soldierAttributeTable[7].point = 2;
	soldierAttributeTable[7].uid = "Blast radius increased";
	soldierAttributeTable[7].value = float(10);
	soldierAttributeTable[7].defaultValue = float(100);
	soldierAttributeTable[7].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[7].title = "폭발반경 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[8].class = CLASS_SOLDIER;
	soldierAttributeTable[8].max = 5;
	soldierAttributeTable[8].point = 2;
	soldierAttributeTable[8].uid = "Projectile speed increased";
	soldierAttributeTable[8].value = float(10);
	soldierAttributeTable[8].defaultValue = float(100);
	soldierAttributeTable[8].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[8].title = "투사체속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[9].class = CLASS_SOLDIER;
	soldierAttributeTable[9].max = 5;
	soldierAttributeTable[9].point = 2;
	soldierAttributeTable[9].uid = "max health additive bonus";
	soldierAttributeTable[9].value = float(10);
	soldierAttributeTable[9].defaultValue = float(0);
	soldierAttributeTable[9].additiveMode = ADDITIVE_NUMBER;	
	soldierAttributeTable[9].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";		
	
	soldierAttributeTable[10].class = CLASS_SOLDIER;
	soldierAttributeTable[10].max = 4;
	soldierAttributeTable[10].point = 3;
	soldierAttributeTable[10].uid = "clip size bonus";
	soldierAttributeTable[10].value = float(25);
	soldierAttributeTable[10].defaultValue = float(100);
	soldierAttributeTable[10].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[10].title = "장탄수 %.0f%% 증가 (%dpt)(%d/%d)";
	
	soldierAttributeTable[11].class = CLASS_SOLDIER;
	soldierAttributeTable[11].max = 4;
	soldierAttributeTable[11].point = 3;
	soldierAttributeTable[11].uid = "increase buff duration";
	soldierAttributeTable[11].value = float(25);
	soldierAttributeTable[11].defaultValue = float(100);
	soldierAttributeTable[11].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[11].title = "깃발유지시간 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	soldierAttributeTable[12].class = CLASS_SOLDIER;
	soldierAttributeTable[12].max = 1;
	soldierAttributeTable[12].point = 5;
	soldierAttributeTable[12].uid = "rocket specialist";
	soldierAttributeTable[12].value = float(100);
	soldierAttributeTable[12].defaultValue = float(0);
	soldierAttributeTable[12].additiveMode = ADDITIVE_PERCENT;	
	soldierAttributeTable[12].isDisableDrawValue = true;
	soldierAttributeTable[12].title = "로켓특화 (%dpt)(%d/%d)";			
	
	pyroAttributeTable[0].class = CLASS_PYRO;
	pyroAttributeTable[0].max = 5;
	pyroAttributeTable[0].point = 1;
	pyroAttributeTable[0].uid = "move speed bonus";
	pyroAttributeTable[0].value = float(3);
	pyroAttributeTable[0].defaultValue = float(100);
	pyroAttributeTable[0].additiveMode = ADDITIVE_PERCENT;	
	pyroAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	pyroAttributeTable[1].class = CLASS_PYRO;
	pyroAttributeTable[1].max = 10;
	pyroAttributeTable[1].point = 1;
	pyroAttributeTable[1].uid = "fire rate bonus";
	pyroAttributeTable[1].value = float(5);
	pyroAttributeTable[1].defaultValue = float(100);
	pyroAttributeTable[1].additiveMode = MINUS_PERCENT;	
	pyroAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	pyroAttributeTable[2].class = CLASS_PYRO;
	pyroAttributeTable[2].max = 10;
	pyroAttributeTable[2].point = 1;
	pyroAttributeTable[2].uid = "Reload time decreased";
	pyroAttributeTable[2].value = float(5);
	pyroAttributeTable[2].defaultValue = float(100);
	pyroAttributeTable[2].additiveMode = MINUS_PERCENT;	
	pyroAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	pyroAttributeTable[3].class = CLASS_PYRO;
	pyroAttributeTable[3].max = 3;
	pyroAttributeTable[3].point = 1;
	pyroAttributeTable[3].uid = "deploy time decreased";
	pyroAttributeTable[3].value = float(15);
	pyroAttributeTable[3].defaultValue = float(100);
	pyroAttributeTable[3].additiveMode = MINUS_PERCENT;	
	pyroAttributeTable[3].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";			
	
	pyroAttributeTable[4].class = CLASS_PYRO;
	pyroAttributeTable[4].max = 5;
	pyroAttributeTable[4].point = 1;
	pyroAttributeTable[4].uid = "heal on hit for rapidfire";
	pyroAttributeTable[4].value = float(3);
	pyroAttributeTable[4].defaultValue = float(0);
	pyroAttributeTable[4].additiveMode = ADDITIVE_NUMBER;	
	pyroAttributeTable[4].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";	
	
	pyroAttributeTable[5].class = CLASS_PYRO;
	pyroAttributeTable[5].max = 4;
	pyroAttributeTable[5].point = 1;
	pyroAttributeTable[5].uid = "weapon burn dmg increased";
	pyroAttributeTable[5].value = float(50);
	pyroAttributeTable[5].defaultValue = float(100);
	pyroAttributeTable[5].additiveMode = ADDITIVE_PERCENT;	
	pyroAttributeTable[5].title = "화상피해 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	pyroAttributeTable[6].class = CLASS_PYRO;
	pyroAttributeTable[6].max = 5;
	pyroAttributeTable[6].point = 1;
	pyroAttributeTable[6].uid = "weapon burn time increased";
	pyroAttributeTable[6].value = float(25);
	pyroAttributeTable[6].defaultValue = float(100);
	pyroAttributeTable[6].additiveMode = ADDITIVE_PERCENT;	
	pyroAttributeTable[6].title = "화상 지속시간 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	pyroAttributeTable[7].class = CLASS_PYRO;
	pyroAttributeTable[7].max = 5;
	pyroAttributeTable[7].point = 2;
	pyroAttributeTable[7].uid = "damage bonus HIDDEN";
	pyroAttributeTable[7].value = float(1);
	pyroAttributeTable[7].defaultValue = float(100);
	pyroAttributeTable[7].additiveMode = ADDITIVE_PERCENT;	
	pyroAttributeTable[7].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";		

	pyroAttributeTable[8].class = CLASS_PYRO;
	pyroAttributeTable[8].max = 5;
	pyroAttributeTable[8].point = 2;
	pyroAttributeTable[8].uid = "max health additive bonus";
	pyroAttributeTable[8].value = float(10);
	pyroAttributeTable[8].defaultValue = float(0);
	pyroAttributeTable[8].additiveMode = ADDITIVE_NUMBER;	
	pyroAttributeTable[8].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";	

	pyroAttributeTable[9].class = CLASS_PYRO;
	pyroAttributeTable[9].max = 3;
	pyroAttributeTable[9].point = 3;
	pyroAttributeTable[9].uid = "mult airblast refire time";
	pyroAttributeTable[9].value = float(10);
	pyroAttributeTable[9].defaultValue = float(100);
	pyroAttributeTable[9].additiveMode = MINUS_PERCENT;	
	pyroAttributeTable[9].title = "압축공기 발사속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	pyroAttributeTable[10].class = CLASS_PYRO;
	pyroAttributeTable[10].max = 4;
	pyroAttributeTable[10].point = 3;
	pyroAttributeTable[10].uid = "flame_speed";
	pyroAttributeTable[10].value = float(900);
	pyroAttributeTable[10].defaultValue = float(100);
	pyroAttributeTable[10].additiveMode = ADDITIVE_NUMBER;	
	pyroAttributeTable[10].isDisableDrawValue = true;
	pyroAttributeTable[10].title = "사정거리 25% 증가 (%dpt)(%d/%d)";		

	pyroAttributeTable[11].class = CLASS_PYRO;
	pyroAttributeTable[11].max = 2;
	pyroAttributeTable[11].point = 3;
	pyroAttributeTable[11].uid = "mult_item_meter_charge_rate";
	pyroAttributeTable[11].value = float(15);
	pyroAttributeTable[11].defaultValue = float(100);
	pyroAttributeTable[11].additiveMode = MINUS_PERCENT;	
	pyroAttributeTable[11].title = "가열가속기 재충전 속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	pyroAttributeTable[12].class = CLASS_PYRO;
	pyroAttributeTable[12].max = 1;
	pyroAttributeTable[12].point = 4;
	pyroAttributeTable[12].uid = "thermal_thruster_air_launch";
	pyroAttributeTable[12].value = float(100);
	pyroAttributeTable[12].defaultValue = float(0);
	pyroAttributeTable[12].additiveMode = ADDITIVE_PERCENT;	
	pyroAttributeTable[12].isDisableDrawValue = true;
	pyroAttributeTable[12].title = "가열가속기가 공중에서 사용가능합니다 (%dpt)(%d/%d)";		

	demomanAttributeTable[0].class = CLASS_DEMOMAN;
	demomanAttributeTable[0].max = 5;
	demomanAttributeTable[0].point = 1;
	demomanAttributeTable[0].uid = "move speed bonus";
	demomanAttributeTable[0].value = float(3);
	demomanAttributeTable[0].defaultValue = float(100);
	demomanAttributeTable[0].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	demomanAttributeTable[1].class = CLASS_DEMOMAN;
	demomanAttributeTable[1].max = 10;
	demomanAttributeTable[1].point = 1;
	demomanAttributeTable[1].uid = "fire rate bonus";
	demomanAttributeTable[1].value = float(5);
	demomanAttributeTable[1].defaultValue = float(100);
	demomanAttributeTable[1].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[2].class = CLASS_DEMOMAN;
	demomanAttributeTable[2].max = 10;
	demomanAttributeTable[2].point = 1;
	demomanAttributeTable[2].uid = "Reload time decreased";
	demomanAttributeTable[2].value = float(5);
	demomanAttributeTable[2].defaultValue = float(100);
	demomanAttributeTable[2].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[3].class = CLASS_DEMOMAN;
	demomanAttributeTable[3].max = 3;
	demomanAttributeTable[3].point = 1;
	demomanAttributeTable[3].uid = "deploy time decreased";
	demomanAttributeTable[3].value = float(15);
	demomanAttributeTable[3].defaultValue = float(100);
	demomanAttributeTable[3].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[3].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	demomanAttributeTable[4].class = CLASS_DEMOMAN;
	demomanAttributeTable[4].max = 5;
	demomanAttributeTable[4].point = 1;
	demomanAttributeTable[4].uid = "heal on hit for rapidfire";
	demomanAttributeTable[4].value = float(2);
	demomanAttributeTable[4].defaultValue = float(0);
	demomanAttributeTable[4].additiveMode = ADDITIVE_NUMBER;	
	demomanAttributeTable[4].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[5].class = CLASS_DEMOMAN;
	demomanAttributeTable[5].max = 4;
	demomanAttributeTable[5].point = 1;
	demomanAttributeTable[5].uid = "stickybomb charge rate";
	demomanAttributeTable[5].value = float(25);
	demomanAttributeTable[5].defaultValue = float(100);
	demomanAttributeTable[5].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[5].title = "점착 폭탄 충전속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[6].class = CLASS_DEMOMAN;
	demomanAttributeTable[6].max = 5;
	demomanAttributeTable[6].point = 2;
	demomanAttributeTable[6].uid = "damage bonus HIDDEN";
	demomanAttributeTable[6].value = float(1);
	demomanAttributeTable[6].defaultValue = float(100);
	demomanAttributeTable[6].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[6].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[7].class = CLASS_DEMOMAN;
	demomanAttributeTable[7].max = 5;
	demomanAttributeTable[7].point = 2;
	demomanAttributeTable[7].uid = "max health additive bonus";
	demomanAttributeTable[7].value = float(10);
	demomanAttributeTable[7].defaultValue = float(0);
	demomanAttributeTable[7].additiveMode = ADDITIVE_NUMBER;	
	demomanAttributeTable[7].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";		
	
	demomanAttributeTable[8].class = CLASS_DEMOMAN;
	demomanAttributeTable[8].max = 5;
	demomanAttributeTable[8].point = 2;
	demomanAttributeTable[8].uid = "Blast radius increased";
	demomanAttributeTable[8].value = float(10);
	demomanAttributeTable[8].defaultValue = float(100);
	demomanAttributeTable[8].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[8].title = "폭발반경 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[9].class = CLASS_DEMOMAN;
	demomanAttributeTable[9].max = 5;
	demomanAttributeTable[9].point = 2;
	demomanAttributeTable[9].uid = "Projectile speed increased";
	demomanAttributeTable[9].value = float(10);
	demomanAttributeTable[9].defaultValue = float(100);
	demomanAttributeTable[9].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[9].title = "투사체속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[10].class = CLASS_DEMOMAN;
	demomanAttributeTable[10].max = 5;
	demomanAttributeTable[10].point = 2;
	demomanAttributeTable[10].uid = "rocket jump damage reduction";
	demomanAttributeTable[10].value = float(10);
	demomanAttributeTable[10].defaultValue = float(100);
	demomanAttributeTable[10].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[10].title = "폭발점프 피해 %.0f%% 감소 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[11].class = CLASS_DEMOMAN;
	demomanAttributeTable[11].max = 3;
	demomanAttributeTable[11].point = 2;
	demomanAttributeTable[11].uid = "sticky arm time bonus";
	demomanAttributeTable[11].value = float(33);
	demomanAttributeTable[11].defaultValue = float(0);
	demomanAttributeTable[11].additiveMode = MINUS_PERCENT;	
	demomanAttributeTable[11].title = "폭탄 폭파 대기 시간 %.0f%% 감소 (%dpt)(%d/%d)";		
	
	demomanAttributeTable[12].class = CLASS_DEMOMAN;
	demomanAttributeTable[12].max = 3;
	demomanAttributeTable[12].point = 3;
	demomanAttributeTable[12].uid = "charge recharge rate increased";
	demomanAttributeTable[12].value = float(15);
	demomanAttributeTable[12].defaultValue = float(100);
	demomanAttributeTable[12].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[12].title = "돌격 재충전 속도 %.0f%% 증가 (%dpt)(%d/%d)";			
	
	demomanAttributeTable[13].class = CLASS_DEMOMAN;
	demomanAttributeTable[13].max = 2;
	demomanAttributeTable[13].point = 3;
	demomanAttributeTable[13].uid = "melee range multiplier";
	demomanAttributeTable[13].value = float(100);
	demomanAttributeTable[13].defaultValue = float(100);
	demomanAttributeTable[13].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[13].title = "근접 공격 범위 %.0f%%증가 (%dpt)(%d/%d)";	
	
	demomanAttributeTable[14].class = CLASS_DEMOMAN;
	demomanAttributeTable[14].max = 4;
	demomanAttributeTable[14].point = 3;
	demomanAttributeTable[14].uid = "clip size bonus";
	demomanAttributeTable[14].value = float(25);
	demomanAttributeTable[14].defaultValue = float(100);
	demomanAttributeTable[14].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[14].title = "장탄수 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	demomanAttributeTable[15].class = CLASS_DEMOMAN;
	demomanAttributeTable[15].max = 1;
	demomanAttributeTable[15].point = 4;
	demomanAttributeTable[15].uid = "grenade no bounce";
	demomanAttributeTable[15].value = float(0);
	demomanAttributeTable[15].defaultValue = float(100);
	demomanAttributeTable[15].additiveMode = ADDITIVE_PERCENT;	
	demomanAttributeTable[15].isDisableDrawValue = true;
	demomanAttributeTable[15].title = "유탄이 적게 튀어오릅니다 (%dpt)(%d/%d)";		

	heavyAttributeTable[0].class = CLASS_HEAVY;
	heavyAttributeTable[0].max = 5;
	heavyAttributeTable[0].point = 1;
	heavyAttributeTable[0].uid = "move speed bonus";
	heavyAttributeTable[0].value = float(5);
	heavyAttributeTable[0].defaultValue = float(100);
	heavyAttributeTable[0].additiveMode = ADDITIVE_PERCENT;	
	heavyAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	heavyAttributeTable[1].class = CLASS_HEAVY;
	heavyAttributeTable[1].max = 10;
	heavyAttributeTable[1].point = 1;
	heavyAttributeTable[1].uid = "fire rate bonus";
	heavyAttributeTable[1].value = float(5);
	heavyAttributeTable[1].defaultValue = float(100);
	heavyAttributeTable[1].additiveMode = MINUS_PERCENT;		
	heavyAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	heavyAttributeTable[2].class = CLASS_HEAVY;
	heavyAttributeTable[2].max = 3;
	heavyAttributeTable[2].point = 1;
	heavyAttributeTable[2].uid = "deploy time decreased";
	heavyAttributeTable[2].value = float(15);
	heavyAttributeTable[2].defaultValue = float(100);
	heavyAttributeTable[2].additiveMode = MINUS_PERCENT;		
	heavyAttributeTable[2].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	heavyAttributeTable[3].class = CLASS_HEAVY;
	heavyAttributeTable[3].max = 5;
	heavyAttributeTable[3].point = 1;
	heavyAttributeTable[3].uid = "heal on hit for rapidfire";
	heavyAttributeTable[3].value = float(2);
	heavyAttributeTable[3].defaultValue = float(0);
	heavyAttributeTable[3].additiveMode = ADDITIVE_NUMBER;		
	heavyAttributeTable[3].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";

	heavyAttributeTable[4].class = CLASS_HEAVY;
	heavyAttributeTable[4].max = 5;
	heavyAttributeTable[4].point = 1;
	heavyAttributeTable[4].uid = "effect bar recharge rate increased";
	heavyAttributeTable[4].value = float(10);
	heavyAttributeTable[4].defaultValue = float(100);
	heavyAttributeTable[4].additiveMode = MINUS_PERCENT;		
	heavyAttributeTable[4].title = "재충전속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	heavyAttributeTable[5].class = CLASS_HEAVY;
	heavyAttributeTable[5].max = 5;
	heavyAttributeTable[5].point = 2;
	heavyAttributeTable[5].uid = "damage bonus HIDDEN";
	heavyAttributeTable[5].value = float(1);
	heavyAttributeTable[5].defaultValue = float(100);
	heavyAttributeTable[5].additiveMode = ADDITIVE_PERCENT;		
	heavyAttributeTable[5].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";
	
	heavyAttributeTable[6].class = CLASS_HEAVY;
	heavyAttributeTable[6].max = 2;
	heavyAttributeTable[6].point = 2;
	heavyAttributeTable[6].uid = "aiming movespeed increased";
	heavyAttributeTable[6].value = float(25);
	heavyAttributeTable[6].defaultValue = float(100);
	heavyAttributeTable[6].additiveMode = ADDITIVE_PERCENT;		
	heavyAttributeTable[6].title = "총열 회전시 이동속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	heavyAttributeTable[7].class = CLASS_HEAVY;
	heavyAttributeTable[7].max = 4;
	heavyAttributeTable[7].point = 2;
	heavyAttributeTable[7].uid = "minigun spinup time decreased";
	heavyAttributeTable[7].value = float(10);
	heavyAttributeTable[7].defaultValue = float(100);
	heavyAttributeTable[7].additiveMode = MINUS_PERCENT;		
	heavyAttributeTable[7].title = "빠른 사격 준비 속도 %.0f%% 증가 (%dpt)(%d/%d)";

	heavyAttributeTable[8].class = CLASS_HEAVY;
	heavyAttributeTable[8].max = 6;
	heavyAttributeTable[8].point = 2;
	heavyAttributeTable[8].uid = "max health additive bonus";
	heavyAttributeTable[8].value = float(25);
	heavyAttributeTable[8].defaultValue = float(0);
	heavyAttributeTable[8].additiveMode = ADDITIVE_NUMBER;		
	heavyAttributeTable[8].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";

	heavyAttributeTable[9].class = CLASS_HEAVY;
	heavyAttributeTable[9].max = 1;
	heavyAttributeTable[9].point = 3;
	heavyAttributeTable[9].uid = "attack projectiles";
	heavyAttributeTable[9].value = float(1);
	heavyAttributeTable[9].defaultValue = float(0);
	heavyAttributeTable[9].additiveMode = ADDITIVE_NUMBER;		
	heavyAttributeTable[9].isDisableDrawValue = true;
	heavyAttributeTable[9].title = "투사체 파괴 (%dpt)(%d/%d)";

	heavyAttributeTable[10].class = CLASS_HEAVY;
	heavyAttributeTable[10].max = 1;
	heavyAttributeTable[10].point = 3;
	heavyAttributeTable[10].uid = "ring of fire while aiming";
	heavyAttributeTable[10].value = float(50);
	heavyAttributeTable[10].defaultValue = float(0);
	heavyAttributeTable[10].additiveMode = ADDITIVE_NUMBER;		
	heavyAttributeTable[10].title = "총열 회전시 피해 %.0f의 불의고리 생성 (%dpt)(%d/%d)";

	heavyAttributeTable[11].class = CLASS_HEAVY;
	heavyAttributeTable[11].max = 2;
	heavyAttributeTable[11].point = 3;
	heavyAttributeTable[11].uid = "weapon spread bonus";
	heavyAttributeTable[11].value = float(25);
	heavyAttributeTable[11].defaultValue = float(100);
	heavyAttributeTable[11].additiveMode = MINUS_PERCENT;		
	heavyAttributeTable[11].title = "집탄률 %.0f%% 증가 (%dpt)(%d/%d)";

	heavyAttributeTable[12].class = CLASS_HEAVY;
	heavyAttributeTable[12].max = 2;
	heavyAttributeTable[12].point = 4;
	heavyAttributeTable[12].uid = "bullets per shot bonus";
	heavyAttributeTable[12].value = float(25);
	heavyAttributeTable[12].defaultValue = float(100);
	heavyAttributeTable[12].additiveMode = ADDITIVE_PERCENT;		
	heavyAttributeTable[12].title = "발사되는 탄환수 %.0f%% 증가 (%dpt)(%d/%d)";

	heavyAttributeTable[13].class = CLASS_HEAVY;
	heavyAttributeTable[13].max = 1;
	heavyAttributeTable[13].point = 5;
	heavyAttributeTable[13].uid = "crit from behind";
	heavyAttributeTable[13].value = float(1);
	heavyAttributeTable[13].defaultValue = float(0);
	heavyAttributeTable[13].additiveMode = ADDITIVE_NUMBER;		
	heavyAttributeTable[13].isDisableDrawValue = true;
	heavyAttributeTable[13].title = "뒤에서 공격하면 항상 치명타가 들어갑니다 (%dpt)(%d/%d)";
	
	engineerAttributeTable[0].class = CLASS_ENGINEER;
	engineerAttributeTable[0].max = 5;
	engineerAttributeTable[0].point = 1;
	engineerAttributeTable[0].uid = "move speed bonus";
	engineerAttributeTable[0].value = float(3);
	engineerAttributeTable[0].defaultValue = float(100);
	engineerAttributeTable[0].additiveMode = ADDITIVE_PERCENT;	
	engineerAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	engineerAttributeTable[1].class = CLASS_ENGINEER;
	engineerAttributeTable[1].max = 10;
	engineerAttributeTable[1].point = 1;
	engineerAttributeTable[1].uid = "fire rate bonus";
	engineerAttributeTable[1].value = float(5);
	engineerAttributeTable[1].defaultValue = float(100);
	engineerAttributeTable[1].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	engineerAttributeTable[2].class = CLASS_ENGINEER;
	engineerAttributeTable[2].max = 10;
	engineerAttributeTable[2].point = 1;
	engineerAttributeTable[2].uid = "Reload time decreased";
	engineerAttributeTable[2].value = float(5);
	engineerAttributeTable[2].defaultValue = float(100);
	engineerAttributeTable[2].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	engineerAttributeTable[3].class = CLASS_ENGINEER;
	engineerAttributeTable[3].max = 3;
	engineerAttributeTable[3].point = 1;
	engineerAttributeTable[3].uid = "deploy time decreased";
	engineerAttributeTable[3].value = float(15);
	engineerAttributeTable[3].defaultValue = float(100);
	engineerAttributeTable[3].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[3].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	engineerAttributeTable[4].class = CLASS_ENGINEER;
	engineerAttributeTable[4].max = 5;
	engineerAttributeTable[4].point = 1;
	engineerAttributeTable[4].uid = "heal on hit for rapidfire";
	engineerAttributeTable[4].value = float(5);
	engineerAttributeTable[4].defaultValue = float(0);
	engineerAttributeTable[4].additiveMode = ADDITIVE_NUMBER;		
	engineerAttributeTable[4].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";	
	
	engineerAttributeTable[5].class = CLASS_ENGINEER;
	engineerAttributeTable[5].max = 4;
	engineerAttributeTable[5].point = 1;
	engineerAttributeTable[5].uid = "engy dispenser radius increased";
	engineerAttributeTable[5].value = float(200);
	engineerAttributeTable[5].defaultValue = float(100);
	engineerAttributeTable[5].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[5].title = "디스펜서 범위 %.0f%% 증가 (%dpt)(%d/%d)";

	engineerAttributeTable[6].class = CLASS_ENGINEER;
	engineerAttributeTable[6].max = 2;
	engineerAttributeTable[6].point = 1;
	engineerAttributeTable[6].uid = "weapon spread bonus";
	engineerAttributeTable[6].value = float(25);
	engineerAttributeTable[6].defaultValue = float(100);
	engineerAttributeTable[6].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[6].title = "집탄률 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	engineerAttributeTable[7].class = CLASS_ENGINEER;
	engineerAttributeTable[7].max = 5;
	engineerAttributeTable[7].point = 2;
	engineerAttributeTable[7].uid = "damage bonus HIDDEN";
	engineerAttributeTable[7].value = float(1);
	engineerAttributeTable[7].defaultValue = float(100);
	engineerAttributeTable[7].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[7].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";

	engineerAttributeTable[8].class = CLASS_ENGINEER;
	engineerAttributeTable[8].max = 4;
	engineerAttributeTable[8].point = 2;
	engineerAttributeTable[8].uid = "maxammo metal increased";
	engineerAttributeTable[8].value = float(50);
	engineerAttributeTable[8].defaultValue = float(100);
	engineerAttributeTable[8].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[8].title = "최대금속 보유량 %.0f%% 증가 (%dpt)(%d/%d)";

	engineerAttributeTable[9].class = CLASS_ENGINEER;
	engineerAttributeTable[9].max = 5;
	engineerAttributeTable[9].point = 2;
	engineerAttributeTable[9].uid = "build rate bonus";
	engineerAttributeTable[9].value = float(10);
	engineerAttributeTable[9].defaultValue = float(100);
	engineerAttributeTable[9].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[9].title = "건설속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	engineerAttributeTable[10].class = CLASS_ENGINEER;
	engineerAttributeTable[10].max = 5;
	engineerAttributeTable[10].point = 2;
	engineerAttributeTable[10].uid = "max health additive bonus";
	engineerAttributeTable[10].value = float(10);
	engineerAttributeTable[10].defaultValue = float(0);
	engineerAttributeTable[10].additiveMode = ADDITIVE_NUMBER;		
	engineerAttributeTable[10].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";		

	engineerAttributeTable[11].class = CLASS_ENGINEER;
	engineerAttributeTable[11].max = 5;
	engineerAttributeTable[11].point = 2;
	engineerAttributeTable[11].uid = "metal regen";
	engineerAttributeTable[11].value = float(10);
	engineerAttributeTable[11].defaultValue = float(0);
	engineerAttributeTable[11].additiveMode = ADDITIVE_NUMBER;		
	engineerAttributeTable[11].title = "금속 5초마다 %.0f 생성 (%dpt)(%d/%d)";
	
	engineerAttributeTable[12].class = CLASS_ENGINEER;
	engineerAttributeTable[12].max = 4;
	engineerAttributeTable[12].point = 3;
	engineerAttributeTable[12].uid = "engy sentry radius increased";
	engineerAttributeTable[12].value = float(10);
	engineerAttributeTable[12].defaultValue = float(100);
	engineerAttributeTable[12].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[12].title = "센트리 사정거리 %.0f%% 증가 (%dpt)(%d/%d)";	

	engineerAttributeTable[13].class = CLASS_ENGINEER;
	engineerAttributeTable[13].max = 4;
	engineerAttributeTable[13].point = 3;
	engineerAttributeTable[13].uid = "engy sentry fire rate increased";
	engineerAttributeTable[13].value = float(10);
	engineerAttributeTable[13].defaultValue = float(100);
	engineerAttributeTable[13].additiveMode = MINUS_PERCENT;		
	engineerAttributeTable[13].title = "센트리 발사속도 %.0f%% 증가 (%dpt)(%d/%d)";

	engineerAttributeTable[14].class = CLASS_ENGINEER;
	engineerAttributeTable[14].max = 4;
	engineerAttributeTable[14].point = 3;
	engineerAttributeTable[14].uid = "engy building health bonus";
	engineerAttributeTable[14].value = float(25);
	engineerAttributeTable[14].defaultValue = float(100);
	engineerAttributeTable[14].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[14].title = "구조물 내구도 %.0f%% 증가 (%dpt)(%d/%d)";
	
	engineerAttributeTable[15].class = CLASS_ENGINEER;
	engineerAttributeTable[15].max = 4;
	engineerAttributeTable[15].point = 3;
	engineerAttributeTable[15].uid = "clip size bonus";
	engineerAttributeTable[15].value = float(25);
	engineerAttributeTable[15].defaultValue = float(100);
	engineerAttributeTable[15].additiveMode = ADDITIVE_PERCENT;		
	engineerAttributeTable[15].title = "장탄수 %.0f%% 증가 (%dpt)(%d/%d)";

	engineerAttributeTable[16].class = CLASS_ENGINEER;
	engineerAttributeTable[16].max = 1;
	engineerAttributeTable[16].point = 4;
	engineerAttributeTable[16].uid = "bidirectional teleport";
	engineerAttributeTable[16].value = float(1);
	engineerAttributeTable[16].defaultValue = float(0);
	engineerAttributeTable[16].additiveMode = ADDITIVE_NUMBER;		
	engineerAttributeTable[16].isDisableDrawValue = true;
	engineerAttributeTable[16].title = "양방향 텔레포트 활성화 (%dpt)(%d/%d)";	
	
	medicAttributeTable[0].class = CLASS_MEDIC;
	medicAttributeTable[0].max = 5;
	medicAttributeTable[0].point = 1;
	medicAttributeTable[0].uid = "move speed bonus";
	medicAttributeTable[0].value = float(3);
	medicAttributeTable[0].defaultValue = float(100);
	medicAttributeTable[0].additiveMode = ADDITIVE_PERCENT;	
	medicAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";

	medicAttributeTable[1].class = CLASS_MEDIC;
	medicAttributeTable[1].max = 10;
	medicAttributeTable[1].point = 1;
	medicAttributeTable[1].uid = "fire rate bonus";
	medicAttributeTable[1].value = float(5);
	medicAttributeTable[1].defaultValue = float(100);
	medicAttributeTable[1].additiveMode = MINUS_PERCENT;		
	medicAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	medicAttributeTable[1].class = CLASS_MEDIC;
	medicAttributeTable[1].max = 10;
	medicAttributeTable[1].point = 1;
	medicAttributeTable[1].uid = "Reload time decreased";
	medicAttributeTable[1].value = float(5);
	medicAttributeTable[1].defaultValue = float(100);
	medicAttributeTable[1].additiveMode = MINUS_PERCENT;		
	medicAttributeTable[1].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	medicAttributeTable[2].class = CLASS_MEDIC;
	medicAttributeTable[2].max = 3;
	medicAttributeTable[2].point = 1;
	medicAttributeTable[2].uid = "deploy time decreased";
	medicAttributeTable[2].value = float(15);
	medicAttributeTable[2].defaultValue = float(100);
	medicAttributeTable[2].additiveMode = MINUS_PERCENT;	
	medicAttributeTable[2].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";		

	medicAttributeTable[3].class = CLASS_MEDIC;
	medicAttributeTable[3].max = 5;
	medicAttributeTable[3].point = 1;
	medicAttributeTable[3].uid = "heal on hit for rapidfire";
	medicAttributeTable[3].value = float(2);
	medicAttributeTable[3].defaultValue = float(0);
	medicAttributeTable[3].additiveMode = ADDITIVE_NUMBER;	
	medicAttributeTable[3].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";		

	medicAttributeTable[4].class = CLASS_MEDIC;
	medicAttributeTable[4].max = 5;
	medicAttributeTable[4].point = 2;
	medicAttributeTable[4].uid = "damage bonus HIDDEN";
	medicAttributeTable[4].value = float(1);
	medicAttributeTable[4].defaultValue = float(100);
	medicAttributeTable[4].additiveMode = ADDITIVE_PERCENT;	
	medicAttributeTable[4].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";		
	
	medicAttributeTable[5].class = CLASS_MEDIC;
	medicAttributeTable[5].max = 5;
	medicAttributeTable[5].point = 2;
	medicAttributeTable[5].uid = "max health additive bonus";
	medicAttributeTable[5].value = float(10);
	medicAttributeTable[5].defaultValue = float(0);
	medicAttributeTable[5].additiveMode = ADDITIVE_NUMBER;		
	medicAttributeTable[5].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";	

	medicAttributeTable[6].class = CLASS_MEDIC;
	medicAttributeTable[6].max = 5;
	medicAttributeTable[6].point = 2;
	medicAttributeTable[6].uid = "heal rate bonus";
	medicAttributeTable[6].value = float(10);
	medicAttributeTable[6].defaultValue = float(100);
	medicAttributeTable[6].additiveMode = ADDITIVE_PERCENT;	
	medicAttributeTable[6].title = "치료율 %.0f%% 증가 (%dpt)(%d/%d)";		

	medicAttributeTable[7].class = CLASS_MEDIC;
	medicAttributeTable[7].max = 5;
	medicAttributeTable[7].point = 3;
	medicAttributeTable[7].uid = "ubercharge rate bonus";
	medicAttributeTable[7].value = float(5);
	medicAttributeTable[7].defaultValue = float(100);
	medicAttributeTable[7].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[7].title = "우버 충전율 %.0f%% 증가 (%dpt)(%d/%d)";	

	medicAttributeTable[8].class = CLASS_MEDIC;
	medicAttributeTable[8].max = 5;
	medicAttributeTable[8].point = 3;
	medicAttributeTable[8].uid = "add uber charge on hit";
	medicAttributeTable[8].value = float(1);
	medicAttributeTable[8].defaultValue = float(0);
	medicAttributeTable[8].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[8].title = "적중시 우버차지 %.0f%% 추가 (%dpt)(%d/%d)";	

	medicAttributeTable[9].class = CLASS_MEDIC;
	medicAttributeTable[9].max = 5;
	medicAttributeTable[9].point = 3;
	medicAttributeTable[9].uid = "uber duration bonus";
	medicAttributeTable[9].value = float(1);
	medicAttributeTable[9].defaultValue = float(0);
	medicAttributeTable[9].additiveMode = ADDITIVE_NUMBER;		
	medicAttributeTable[9].title = "우버차지 지속시간 %.0f초증가 (%dpt)(%d/%d)";	

	medicAttributeTable[10].class = CLASS_MEDIC;
	medicAttributeTable[10].max = 4;
	medicAttributeTable[10].point = 3;
	medicAttributeTable[10].uid = "clip size bonus";
	medicAttributeTable[10].value = float(100);
	medicAttributeTable[10].defaultValue = float(100);
	medicAttributeTable[10].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[10].title = "장탄수 %.2f%% 증가 (%dpt)(%d/%d)";	

	medicAttributeTable[11].class = CLASS_MEDIC;
	medicAttributeTable[11].max = 4;
	medicAttributeTable[11].point = 3;
	medicAttributeTable[11].uid = "overheal bonus";
	medicAttributeTable[11].value = float(25);
	medicAttributeTable[11].defaultValue = float(100);
	medicAttributeTable[11].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[11].title = "과치료 %.0f%% 증가 (%dpt)(%d/%d)";	

	medicAttributeTable[12].class = CLASS_MEDIC;
	medicAttributeTable[12].max = 1;
	medicAttributeTable[12].point = 5;
	medicAttributeTable[12].uid = "generate rage on heal";
	medicAttributeTable[12].value = float(100);
	medicAttributeTable[12].defaultValue = float(0);
	medicAttributeTable[12].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[12].isDisableDrawValue = true;
	medicAttributeTable[12].title = "투사체 보호막생성 (%dpt)(%d/%d)";		

	medicAttributeTable[13].class = CLASS_MEDIC;
	medicAttributeTable[13].max = 1;
	medicAttributeTable[13].point = 5;
	medicAttributeTable[13].uid = "overheal decay disabled";
	medicAttributeTable[13].value = float(10000);
	medicAttributeTable[13].defaultValue = float(0);
	medicAttributeTable[13].additiveMode = ADDITIVE_PERCENT;		
	medicAttributeTable[13].isDisableDrawValue = true;
	medicAttributeTable[13].title = "과치료 체력이 소멸되지 않습니다 (%dpt)(%d/%d)";	
	
	sniperAttributeTable[0].class = CLASS_SNIPER;
	sniperAttributeTable[0].max = 5;
	sniperAttributeTable[0].point = 1;
	sniperAttributeTable[0].uid = "move speed bonus";
	sniperAttributeTable[0].value = float(3);
	sniperAttributeTable[0].defaultValue = float(100);
	sniperAttributeTable[0].additiveMode = ADDITIVE_PERCENT;		
	sniperAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";		

	sniperAttributeTable[1].class = CLASS_SNIPER;
	sniperAttributeTable[1].max = 10;
	sniperAttributeTable[1].point = 1;
	sniperAttributeTable[1].uid = "fire rate bonus";
	sniperAttributeTable[1].value = float(5);
	sniperAttributeTable[1].defaultValue = float(100);
	sniperAttributeTable[1].additiveMode = MINUS_PERCENT;	
	sniperAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[2].class = CLASS_SNIPER;
	sniperAttributeTable[2].max = 10;
	sniperAttributeTable[2].point = 1;
	sniperAttributeTable[2].uid = "Reload time decreased";
	sniperAttributeTable[2].value = float(5);
	sniperAttributeTable[2].defaultValue = float(100);
	sniperAttributeTable[2].additiveMode = ADDITIVE_PERCENT;	
	sniperAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[3].class = CLASS_SNIPER;
	sniperAttributeTable[3].max = 3;
	sniperAttributeTable[3].point = 1;
	sniperAttributeTable[3].uid = "deploy time decreased";
	sniperAttributeTable[3].value = float(15);
	sniperAttributeTable[3].defaultValue = float(100);
	sniperAttributeTable[3].additiveMode = MINUS_PERCENT;	
	sniperAttributeTable[3].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[4].class = CLASS_SNIPER;
	sniperAttributeTable[4].max = 5;
	sniperAttributeTable[4].point = 1;
	sniperAttributeTable[4].uid = "heal on hit for rapidfire";
	sniperAttributeTable[4].value = float(5);
	sniperAttributeTable[4].defaultValue = float(0);
	sniperAttributeTable[4].additiveMode = ADDITIVE_NUMBER;	
	sniperAttributeTable[4].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";		

	sniperAttributeTable[5].class = CLASS_SNIPER;
	sniperAttributeTable[5].max = 2;
	sniperAttributeTable[5].point = 1;
	sniperAttributeTable[5].uid = "weapon spread bonus";
	sniperAttributeTable[5].value = float(25);
	sniperAttributeTable[5].defaultValue = float(100);
	sniperAttributeTable[5].additiveMode = MINUS_PERCENT;	
	sniperAttributeTable[5].title = "집탄률 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[6].class = CLASS_SNIPER;
	sniperAttributeTable[6].max = 2;
	sniperAttributeTable[6].point = 1;
	sniperAttributeTable[6].uid = "effect bar recharge rate increased";
	sniperAttributeTable[6].value = float(25);
	sniperAttributeTable[6].defaultValue = float(100);
	sniperAttributeTable[6].additiveMode = MINUS_PERCENT;	
	sniperAttributeTable[6].title = "재충전속도 %.0f%% 증가 (%dpt)(%d/%d)";		

	sniperAttributeTable[7].class = CLASS_SNIPER;
	sniperAttributeTable[7].max = 5;
	sniperAttributeTable[7].point = 2;
	sniperAttributeTable[7].uid = "damage bonus HIDDEN";
	sniperAttributeTable[7].value = float(1);
	sniperAttributeTable[7].defaultValue = float(100);
	sniperAttributeTable[7].additiveMode = ADDITIVE_PERCENT;	
	sniperAttributeTable[7].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";		

	sniperAttributeTable[8].class = CLASS_SNIPER;
	sniperAttributeTable[8].max = 5;
	sniperAttributeTable[8].point = 2;
	sniperAttributeTable[8].uid = "max health additive bonus";
	sniperAttributeTable[8].value = float(10);
	sniperAttributeTable[8].defaultValue = float(0);
	sniperAttributeTable[8].additiveMode = ADDITIVE_NUMBER;	
	sniperAttributeTable[8].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[9].class = CLASS_SNIPER;
	sniperAttributeTable[9].max = 5;
	sniperAttributeTable[9].point = 2;
	sniperAttributeTable[9].uid = "health regen";
	sniperAttributeTable[9].value = float(1);
	sniperAttributeTable[9].defaultValue = float(0);
	sniperAttributeTable[9].additiveMode = ADDITIVE_NUMBER;	
	sniperAttributeTable[9].title = "초당 체력 재생 %.0f 증가 (%dpt)(%d/%d)";		

	sniperAttributeTable[10].class = CLASS_SNIPER;
	sniperAttributeTable[10].max = 4;
	sniperAttributeTable[10].point = 3;
	sniperAttributeTable[10].uid = "sniper charge per sec";
	sniperAttributeTable[10].value = float(50);
	sniperAttributeTable[10].defaultValue = float(100);
	sniperAttributeTable[10].additiveMode = ADDITIVE_PERCENT;	
	sniperAttributeTable[10].title = "충전율 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[11].class = CLASS_SNIPER;
	sniperAttributeTable[11].max = 5;
	sniperAttributeTable[11].point = 3;
	sniperAttributeTable[11].uid = "jarate duration";
	sniperAttributeTable[11].value = float(1);
	sniperAttributeTable[11].defaultValue = float(0);
	sniperAttributeTable[11].additiveMode = ADDITIVE_NUMBER;	
	sniperAttributeTable[11].title = "충전사격시 병수도 효과 %.0f초증가 (%dpt)(%d/%d)";		

	sniperAttributeTable[12].class = CLASS_SNIPER;
	sniperAttributeTable[12].max = 4;
	sniperAttributeTable[12].point = 3;
	sniperAttributeTable[12].uid = "headshot damage increase";
	sniperAttributeTable[12].value = float(25);
	sniperAttributeTable[12].defaultValue = float(100);
	sniperAttributeTable[12].additiveMode = ADDITIVE_PERCENT;	
	sniperAttributeTable[12].title = "헤드샷 추가피해 %.0f%% 증가 (%dpt)(%d/%d)";	

	sniperAttributeTable[13].class = CLASS_SNIPER;
	sniperAttributeTable[13].max = 1;
	sniperAttributeTable[13].point = 4;
	sniperAttributeTable[13].uid = "sniper aiming movespeed decreased";
	sniperAttributeTable[13].value = float(4);
	sniperAttributeTable[13].defaultValue = float(1);
	sniperAttributeTable[13].additiveMode = ADDITIVE_NUMBER;	
	sniperAttributeTable[13].isDisableDrawValue = true;
	sniperAttributeTable[13].title = "조준시 이동속도 저하없음 (%dpt)(%d/%d)";	

	sniperAttributeTable[14].class = CLASS_SNIPER;
	sniperAttributeTable[14].max = 1;
	sniperAttributeTable[14].point = 4;
	sniperAttributeTable[14].uid = "sniper full charge damage bonus";
	sniperAttributeTable[14].value = float(100);
	sniperAttributeTable[14].defaultValue = float(100);
	sniperAttributeTable[14].additiveMode = ADDITIVE_PERCENT;	
	sniperAttributeTable[14].title = "완전충전시 피해 %.0f%%증가 (%dpt)(%d/%d)";
	
	spyAttributeTable[0].class = CLASS_SPY;
	spyAttributeTable[0].max = 5;
	spyAttributeTable[0].point = 1;
	spyAttributeTable[0].uid = "move speed bonus";
	spyAttributeTable[0].value = float(3);
	spyAttributeTable[0].defaultValue = float(100);
	spyAttributeTable[0].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[1].class = CLASS_SPY;
	spyAttributeTable[1].max = 10;
	spyAttributeTable[1].point = 1;
	spyAttributeTable[1].uid = "fire rate bonus";
	spyAttributeTable[1].value = float(5);
	spyAttributeTable[1].defaultValue = float(100);
	spyAttributeTable[1].additiveMode = MINUS_PERCENT;
	spyAttributeTable[1].title = "공격속도 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[2].class = CLASS_SPY;
	spyAttributeTable[2].max = 10;
	spyAttributeTable[2].point = 1;
	spyAttributeTable[2].uid = "Reload time decreased";
	spyAttributeTable[2].value = float(5);
	spyAttributeTable[2].defaultValue = float(100);
	spyAttributeTable[2].additiveMode = MINUS_PERCENT;
	spyAttributeTable[2].title = "재장전속도 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[3].class = CLASS_SPY;
	spyAttributeTable[3].max = 10;
	spyAttributeTable[3].point = 1;
	spyAttributeTable[3].uid = "increased jump height";
	spyAttributeTable[3].value = float(5);
	spyAttributeTable[3].defaultValue = float(100);
	spyAttributeTable[3].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[3].title = "점프높이 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[4].class = CLASS_SPY;
	spyAttributeTable[4].max = 3;
	spyAttributeTable[4].point = 1;
	spyAttributeTable[4].uid = "deploy time decreased";
	spyAttributeTable[4].value = float(15);
	spyAttributeTable[4].defaultValue = float(100);
	spyAttributeTable[4].additiveMode = MINUS_PERCENT;
	spyAttributeTable[4].title = "무기전환속도 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[5].class = CLASS_SPY;
	spyAttributeTable[5].max = 2;
	spyAttributeTable[5].point = 1;
	spyAttributeTable[5].uid = "weapon spread bonus";
	spyAttributeTable[5].value = float(25);
	spyAttributeTable[5].defaultValue = float(100);
	spyAttributeTable[5].additiveMode = MINUS_PERCENT;
	spyAttributeTable[5].title = "집탄률 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[6].class = CLASS_SPY;
	spyAttributeTable[6].max = 5;
	spyAttributeTable[6].point = 1;
	spyAttributeTable[6].uid = "heal on hit for rapidfire";
	spyAttributeTable[6].value = float(5);
	spyAttributeTable[6].defaultValue = float(0);
	spyAttributeTable[6].additiveMode = ADDITIVE_NUMBER;
	spyAttributeTable[6].title = "적중시 체력 %.0f 회복 (%dpt)(%d/%d)";

	spyAttributeTable[7].class = CLASS_SPY;
	spyAttributeTable[7].max = 5;
	spyAttributeTable[7].point = 2;
	spyAttributeTable[7].uid = "damage bonus HIDDEN";
	spyAttributeTable[7].value = float(1);
	spyAttributeTable[7].defaultValue = float(100);
	spyAttributeTable[7].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[7].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[8].class = CLASS_SPY;
	spyAttributeTable[8].max = 5;
	spyAttributeTable[8].point = 2;
	spyAttributeTable[8].uid = "max health additive bonus";
	spyAttributeTable[8].value = float(10);
	spyAttributeTable[8].defaultValue = float(0);
	spyAttributeTable[8].additiveMode = ADDITIVE_NUMBER;
	spyAttributeTable[8].title = "최대체력 %.0f 증가 (%dpt)(%d/%d)";

	spyAttributeTable[9].class = CLASS_SPY;
	spyAttributeTable[9].max = 5;
	spyAttributeTable[9].point = 2;
	spyAttributeTable[9].uid = "health regen";
	spyAttributeTable[9].value = float(1);
	spyAttributeTable[9].defaultValue = float(0);
	spyAttributeTable[9].additiveMode = ADDITIVE_NUMBER;
	spyAttributeTable[9].title = "초당 체력 재생 %.0f 증가 (%dpt)(%d/%d)";

	spyAttributeTable[10].class = CLASS_SPY;
	spyAttributeTable[10].max = 5;
	spyAttributeTable[10].point = 2;
	spyAttributeTable[10].uid = "add cloak on hit";
	spyAttributeTable[10].value = float(3);
	spyAttributeTable[10].defaultValue = float(0);
	spyAttributeTable[10].additiveMode = ADDITIVE_NUMBER;
	spyAttributeTable[10].title = "적중시 은폐 에너지 %.0f%% 증가 (%dpt)(%d/%d)";

	spyAttributeTable[11].class = CLASS_SPY;
	spyAttributeTable[11].max = 2;
	spyAttributeTable[11].point = 3;
	spyAttributeTable[11].uid = "speed_boost_on_hit";
	spyAttributeTable[11].value = float(2);
	spyAttributeTable[11].defaultValue = float(0);
	spyAttributeTable[11].additiveMode = ADDITIVE_NUMBER;
	spyAttributeTable[11].title = "적중시 이동속도 %.0f초간 증가 (%dpt)(%d/%d)";

	spyAttributeTable[12].class = CLASS_SPY;
	spyAttributeTable[12].max = 2;
	spyAttributeTable[12].point = 3;
	spyAttributeTable[12].uid = "melee range multiplier";
	spyAttributeTable[12].value = float(25);
	spyAttributeTable[12].defaultValue = float(100);
	spyAttributeTable[12].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[12].title = "근접 공격 범위 %.0f%%증가 (%dpt)(%d/%d)";

	spyAttributeTable[13].class = CLASS_SPY;
	spyAttributeTable[13].max = 1;
	spyAttributeTable[13].point = 4;
	spyAttributeTable[13].uid = "air dash count";
	spyAttributeTable[13].value = float(100);
	spyAttributeTable[13].defaultValue = float(0);
	spyAttributeTable[13].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[13].isDisableDrawValue = true;
	spyAttributeTable[13].title = "2단점프 가능 (%dpt)(%d/%d)";

	spyAttributeTable[14].class = CLASS_SPY;
	spyAttributeTable[14].max = 1;
	spyAttributeTable[14].point = 5;
	spyAttributeTable[14].uid = "SET BONUS: quiet unstealth";
	spyAttributeTable[14].value = float(100);
	spyAttributeTable[14].defaultValue = float(0);
	spyAttributeTable[14].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[14].isDisableDrawValue = true;
	spyAttributeTable[14].title = "은폐 해제 음량감소 (%dpt)(%d/%d)";

	spyAttributeTable[15].class = CLASS_SPY;
	spyAttributeTable[15].max = 1;
	spyAttributeTable[15].point = 5;
	spyAttributeTable[15].uid = "cancel falling damage";
	spyAttributeTable[15].value = float(100);
	spyAttributeTable[15].defaultValue = float(0);
	spyAttributeTable[15].additiveMode = ADDITIVE_PERCENT;
	spyAttributeTable[15].isDisableDrawValue = true;
	spyAttributeTable[15].title = "낙하 피해 무시 (%dpt)(%d/%d)";
	
	haleAttributeTable[0].class = CLASS_HALE;
	haleAttributeTable[0].max = 10;
	haleAttributeTable[0].point = 1;
	haleAttributeTable[0].uid = "move speed bonus";
	haleAttributeTable[0].value = float(3);
	haleAttributeTable[0].defaultValue = float(100);
	haleAttributeTable[0].additiveMode = ADDITIVE_PERCENT;		
	haleAttributeTable[0].title = "이동속도 %.0f%% 증가 (%dpt)(%d/%d)";

	haleAttributeTable[1].class = CLASS_HALE;
	haleAttributeTable[1].max = 5;
	haleAttributeTable[1].point = 2;
	haleAttributeTable[1].uid = "max health additive bonus";
	haleAttributeTable[1].value = float(2000);
	haleAttributeTable[1].defaultValue = float(0);
	haleAttributeTable[1].additiveMode = ADDITIVE_NUMBER;		
	haleAttributeTable[1].title = "최대체력 %.0f증가 (%dpt)(%d/%d)";

	haleAttributeTable[2].class = CLASS_HALE;
	haleAttributeTable[2].max = 2;
	haleAttributeTable[2].point = 2;
	haleAttributeTable[2].uid = "melee range multiplier";
	haleAttributeTable[2].value = float(50);
	haleAttributeTable[2].defaultValue = float(100);
	haleAttributeTable[2].additiveMode = ADDITIVE_PERCENT;		
	haleAttributeTable[2].title = "근접 공격 범위 %.0f%%증가 (%dpt)(%d/%d)";

	sharedAttributeTable[0].class = CLASS_SHARED;
	sharedAttributeTable[0].max = 5;
	sharedAttributeTable[0].point = 1;
	sharedAttributeTable[0].uid = "ammo regen";
	sharedAttributeTable[0].value = float(10);
	sharedAttributeTable[0].defaultValue = float(0);
	sharedAttributeTable[0].additiveMode = ADDITIVE_PERCENT;		
	sharedAttributeTable[0].title = "5초마다 탄약 %.0f%%생성 (%dpt)(%d/%d)";		

	sharedAttributeTable[1].class = CLASS_SHARED;
	sharedAttributeTable[1].max = 5;
	sharedAttributeTable[1].point = 2;
	sharedAttributeTable[1].uid = "damage bonus HIDDEN";
	sharedAttributeTable[1].value = float(1);
	sharedAttributeTable[1].defaultValue = float(100);
	sharedAttributeTable[1].additiveMode = ADDITIVE_PERCENT;	
	sharedAttributeTable[1].title = "피해량 %.0f%% 증가 (%dpt)(%d/%d)";	
	
	weaponAttributeTable[0].class = CLASS_WEAPON;
	weaponAttributeTable[0].max = 15;
	weaponAttributeTable[0].value = float(1);
	weaponAttributeTable[0].defaultValue = float(100);
	weaponAttributeTable[0].additiveMode = ADDITIVE_PERCENT;
	weaponAttributeTable[0].uid = "damage bonus HIDDEN";
	
	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].scoutAttributeData);i2++)
		{
			playerDataList[i].scoutAttributeData[i2].uid = scoutAttributeTable[i2].uid;
			playerDataList[i].scoutAttributeData[i2].id = i2;
			playerDataList[i].scoutAttributeData[i2].class = scoutAttributeTable[i2].class;
			playerDataList[i].scoutAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].medicAttributeData);i2++)
		{
			playerDataList[i].medicAttributeData[i2].uid = medicAttributeTable[i2].uid;
			playerDataList[i].medicAttributeData[i2].id = i2;
			playerDataList[i].medicAttributeData[i2].class = medicAttributeTable[i2].class;
			playerDataList[i].medicAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].soldierAttributeData);i2++)
		{
			playerDataList[i].soldierAttributeData[i2].uid = soldierAttributeTable[i2].uid;
			playerDataList[i].soldierAttributeData[i2].id = i2;
			playerDataList[i].soldierAttributeData[i2].class = soldierAttributeTable[i2].class;
			playerDataList[i].soldierAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].spyAttributeData);i2++)
		{
			playerDataList[i].spyAttributeData[i2].uid = spyAttributeTable[i2].uid;
			playerDataList[i].spyAttributeData[i2].id = i2;
			playerDataList[i].spyAttributeData[i2].class = spyAttributeTable[i2].class;
			playerDataList[i].spyAttributeData[i2].upgrade = 0;
		}
	}	

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].pyroAttributeData);i2++)
		{
			playerDataList[i].pyroAttributeData[i2].uid = pyroAttributeTable[i2].uid;
			playerDataList[i].pyroAttributeData[i2].id = i2;
			playerDataList[i].pyroAttributeData[i2].class = pyroAttributeTable[i2].class;
			playerDataList[i].pyroAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].demomanAttributeData);i2++)
		{
			playerDataList[i].demomanAttributeData[i2].uid = demomanAttributeTable[i2].uid;
			playerDataList[i].demomanAttributeData[i2].id = i2;
			playerDataList[i].demomanAttributeData[i2].class = demomanAttributeTable[i2].class;
			playerDataList[i].demomanAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].sniperAttributeData);i2++)
		{
			playerDataList[i].sniperAttributeData[i2].uid = sniperAttributeTable[i2].uid;
			playerDataList[i].sniperAttributeData[i2].id = i2;
			playerDataList[i].sniperAttributeData[i2].class = sniperAttributeTable[i2].class;
			playerDataList[i].sniperAttributeData[i2].upgrade = 0;
		}
	}	

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].engineerAttributeData);i2++)
		{
			playerDataList[i].engineerAttributeData[i2].uid = engineerAttributeTable[i2].uid;
			playerDataList[i].engineerAttributeData[i2].id = i2;
			playerDataList[i].engineerAttributeData[i2].class = engineerAttributeTable[i2].class;
			playerDataList[i].engineerAttributeData[i2].upgrade = 0;
		}
	}
	
	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].heavyAttributeData);i2++)
		{
			playerDataList[i].heavyAttributeData[i2].uid = heavyAttributeTable[i2].uid;
			playerDataList[i].heavyAttributeData[i2].id = i2;
			playerDataList[i].heavyAttributeData[i2].class = heavyAttributeTable[i2].class;
			playerDataList[i].heavyAttributeData[i2].upgrade = 0;
		}
	}	

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].haleAttributeData);i2++)
		{
			playerDataList[i].haleAttributeData[i2].uid = haleAttributeTable[i2].uid;
			playerDataList[i].haleAttributeData[i2].id = i2;
			playerDataList[i].haleAttributeData[i2].class = haleAttributeTable[i2].class;
			playerDataList[i].haleAttributeData[i2].upgrade = 0;
		}
	}

	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].sharedAttributeData);i2++)
		{
			playerDataList[i].sharedAttributeData[i2].uid = sharedAttributeTable[i2].uid;
			playerDataList[i].sharedAttributeData[i2].id = i2;
			playerDataList[i].sharedAttributeData[i2].class = sharedAttributeTable[i2].class;
			playerDataList[i].sharedAttributeData[i2].upgrade = 0;
		}
	}
	
	for (int i=0;i<sizeof(playerDataList);i++){
		for (int i2=0;i2<sizeof(playerDataList[i].weaponAttributeData);i2++)
		{
			playerDataList[i].weaponAttributeData[i2].uid = weaponAttributeTable[i2].uid;
			playerDataList[i].weaponAttributeData[i2].id = i2;
			playerDataList[i].weaponAttributeData[i2].class = weaponAttributeTable[i2].class;
			playerDataList[i].weaponAttributeData[i2].upgrade = 0;
		}
	}	
}

public Action OnPlayerRegenerate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

	PrintToServer("OnPlayerChangeClass : %d", client);

    if (client == 0 || (!IsClientInGame(client) || IsFakeClient(client)))
        return Plugin_Continue;

	int team = GetClientTeam(client);

	if (team == 2) {
		int value = g_redEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}		
	}
	else if (team == 3){
		int value = g_blueEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}	
	}
	
	TF2Attrib_RemoveAll(client);

    if (TF2_GetPlayerClass(client) == TFClass_Scout)
    {
		for (int i=0; i<sizeof(playerDataList[client].scoutAttributeData);i++)
		{
			int id = playerDataList[client].scoutAttributeData[i].id;
			int upgrade = playerDataList[client].scoutAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}
			
			float result = 0.0;
			
			if (scoutAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) + (float(upgrade) * scoutAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) - (float(upgrade) * scoutAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
		}		
    }
	else if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		for (int i=0; i<sizeof(playerDataList[client].medicAttributeData);i++)
		{
			int id = playerDataList[client].medicAttributeData[i].id;
			int upgrade = playerDataList[client].medicAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (medicAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) + (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) - (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
		}
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		for (int i=0; i<sizeof(playerDataList[client].soldierAttributeData);i++)
		{
			int id = playerDataList[client].soldierAttributeData[i].id;
			int upgrade = playerDataList[client].soldierAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (soldierAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) + (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) - (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
		}
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		for (int i=0; i<sizeof(playerDataList[client].pyroAttributeData);i++)
		{
			int id = playerDataList[client].pyroAttributeData[i].id;
			int upgrade = playerDataList[client].pyroAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (pyroAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) + (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) - (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		for (int i=0; i<sizeof(playerDataList[client].spyAttributeData);i++)
		{
			int id = playerDataList[client].spyAttributeData[i].id;
			int upgrade = playerDataList[client].spyAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (spyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) + (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) - (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
		}
	}
	else if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		for (int i=0; i<sizeof(playerDataList[client].demomanAttributeData);i++)
		{
			int id = playerDataList[client].demomanAttributeData[i].id;
			int upgrade = playerDataList[client].demomanAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (demomanAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) + (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) - (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
		}	
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		for (int i=0; i<sizeof(playerDataList[client].sniperAttributeData);i++)
		{
			int id = playerDataList[client].sniperAttributeData[i].id;
			int upgrade = playerDataList[client].sniperAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (sniperAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) + (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) - (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
		}		
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		for (int i=0; i<sizeof(playerDataList[client].engineerAttributeData);i++)
		{
			int id = playerDataList[client].engineerAttributeData[i].id;
			int upgrade = playerDataList[client].engineerAttributeData[i].upgrade;
			
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (engineerAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) + (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) - (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Heavy)
	{
		for (int i=0; i<sizeof(playerDataList[client].heavyAttributeData);i++)
		{
			int id = playerDataList[client].heavyAttributeData[i].id;
			int upgrade = playerDataList[client].heavyAttributeData[i].upgrade;
			
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (heavyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) + (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) - (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
		}
	}	
	
	CreateTimer(0.5, Timer_ApplySharedAttribute, client);
	
	return Plugin_Continue;
}

public Action Timer_ApplySharedAttribute(Handle timer, any client)
{
	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}
	
	int team = GetClientTeam(client);

	if (team == 2) {
		int value = g_redEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}		
	}
	else if (team == 3){
		int value = g_blueEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}	
	}

    // 무기 슬롯 범위: 0 ~ 5 (필요에 따라 더 늘릴 수 있음)
    for (int slot = 0; slot <= 5; slot++)
    {
        int weapon = GetPlayerWeaponSlot(client, slot);
        if (IsValidEntity(weapon))
        {
			for (int i=0; i<sizeof(playerDataList[client].weaponAttributeData);i++){
				float result = 0.0;
				
				int id = playerDataList[client].weaponAttributeData[i].id;
				int upgrade = playerDataList[client].weaponAttributeData[i].upgrade;
				
				Address attr = TF2Attrib_GetByName(client, playerDataList[client].weaponAttributeData[id].uid);
				
				if (attr == Address_Null){
					result = (weaponAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * weaponAttributeTable[id].value * 0.01);
				}
				else{
					float current = TF2Attrib_GetValue(attr);
				
					result = (current) + (float(upgrade) * weaponAttributeTable[id].value * 0.01);
				}
				
				
				
				TF2Attrib_SetByName(weapon, weaponAttributeTable[id].uid, result);
			}
        }
    }

		for (int i=0; i<sizeof(playerDataList[client].sharedAttributeData);i++)
		{
			int id = playerDataList[client].sharedAttributeData[i].id;
			int upgrade = playerDataList[client].sharedAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			Address attr = TF2Attrib_GetByName(client, sharedAttributeTable[id].uid);
	
			if (attr == Address_Null){
				float result = 0.0;

				if (sharedAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
				{
					result = (sharedAttributeTable[id].defaultValue) + (float(upgrade) * sharedAttributeTable[id].value);
				
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
				{
					result = (sharedAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * sharedAttributeTable[id].value * 0.01);
				
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == MINUS_NUMBER)
				{
					result = (sharedAttributeTable[id].defaultValue) - (float(upgrade) * sharedAttributeTable[id].value);
				
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == MINUS_PERCENT)
				{
					result = (sharedAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * sharedAttributeTable[id].value * 0.01);
					
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}	

				continue;
			}
			else{
				float current = TF2Attrib_GetValue(attr);
				float result = 0.0;

				if (sharedAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
				{
					result = (current) + (float(upgrade) * sharedAttributeTable[id].value);
	
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
				{
					result = (current) + (float(upgrade) * sharedAttributeTable[id].value * 0.01);
				
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == MINUS_NUMBER)
				{
					result = (current) - (float(upgrade) * sharedAttributeTable[id].value);
				
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
				else if (sharedAttributeTable[id].additiveMode == MINUS_PERCENT)
				{
					result = (current) - (float(upgrade) * sharedAttributeTable[id].value * 0.01);
					
					TF2Attrib_SetByName(client, sharedAttributeTable[id].uid, result);
				}
			}
		}
		
		TF2Attrib_ClearCache(client);

	return Plugin_Continue;
}

public Action OnPlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

	PrintToServer("OnPlayerChangeClass : %d", client);

    if (client > 0 && (!IsClientInGame(client) || IsFakeClient(client)))
        return Plugin_Continue;

	int team = GetClientTeam(client);

	if (team == 2) {
		int value = g_redEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}		
	}
	else if (team == 3){
		int value = g_blueEnableStatApply.IntValue;
		
		if (!value){
			TF2Attrib_RemoveAll(client);
			return Plugin_Continue;
		}	
	}
	
	TF2Attrib_RemoveAll(client);

    if (TF2_GetPlayerClass(client) == TFClass_Scout)
    {
		for (int i=0; i<sizeof(playerDataList[client].scoutAttributeData);i++)
		{
			int id = playerDataList[client].scoutAttributeData[i].id;
			int upgrade = playerDataList[client].scoutAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}
			
			float result = 0.0;
			
			if (scoutAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) + (float(upgrade) * scoutAttributeTable[id].value);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (scoutAttributeTable[id].defaultValue) - (float(upgrade) * scoutAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
			else if (scoutAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (scoutAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * scoutAttributeTable[id].value * 0.01);

				TF2Attrib_SetByName(client, scoutAttributeTable[id].uid, result);
			}
		}	
    }
	else if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		for (int i=0; i<sizeof(playerDataList[client].medicAttributeData);i++)
		{
			int id = playerDataList[client].medicAttributeData[i].id;
			int upgrade = playerDataList[client].medicAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (medicAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) + (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (medicAttributeTable[id].defaultValue) - (float(upgrade) * medicAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
			else if (medicAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (medicAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * medicAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, medicAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Soldier)
	{
		for (int i=0; i<sizeof(playerDataList[client].soldierAttributeData);i++)
		{
			int id = playerDataList[client].soldierAttributeData[i].id;
			int upgrade = playerDataList[client].soldierAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (soldierAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) + (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (soldierAttributeTable[id].defaultValue) - (float(upgrade) * soldierAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
			else if (soldierAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (soldierAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * soldierAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, soldierAttributeTable[id].uid, result);
			}
		}
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Pyro)
	{
		for (int i=0; i<sizeof(playerDataList[client].pyroAttributeData);i++)
		{
			int id = playerDataList[client].pyroAttributeData[i].id;
			int upgrade = playerDataList[client].pyroAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (pyroAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) + (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (pyroAttributeTable[id].defaultValue) - (float(upgrade) * pyroAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
			else if (pyroAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (pyroAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * pyroAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, pyroAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		for (int i=0; i<sizeof(playerDataList[client].spyAttributeData);i++)
		{
			int id = playerDataList[client].spyAttributeData[i].id;
			int upgrade = playerDataList[client].spyAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (spyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) + (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (spyAttributeTable[id].defaultValue) - (float(upgrade) * spyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
			else if (spyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (spyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * spyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, spyAttributeTable[id].uid, result);
			}
		}		
	}
	else if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
	{
		for (int i=0; i<sizeof(playerDataList[client].demomanAttributeData);i++)
		{
			int id = playerDataList[client].demomanAttributeData[i].id;
			int upgrade = playerDataList[client].demomanAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (demomanAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) + (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (demomanAttributeTable[id].defaultValue) - (float(upgrade) * demomanAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
			else if (demomanAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (demomanAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * demomanAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, demomanAttributeTable[id].uid, result);
			}
		}
	}	
	else if (TF2_GetPlayerClass(client) == TFClass_Sniper)
	{
		for (int i=0; i<sizeof(playerDataList[client].sniperAttributeData);i++)
		{
			int id = playerDataList[client].sniperAttributeData[i].id;
			int upgrade = playerDataList[client].sniperAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (sniperAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) + (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (sniperAttributeTable[id].defaultValue) - (float(upgrade) * sniperAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
			else if (sniperAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (sniperAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * sniperAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, sniperAttributeTable[id].uid, result);
			}
		}	
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		for (int i=0; i<sizeof(playerDataList[client].engineerAttributeData);i++)
		{
			int id = playerDataList[client].engineerAttributeData[i].id;
			int upgrade = playerDataList[client].engineerAttributeData[i].upgrade;
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (engineerAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) + (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (engineerAttributeTable[id].defaultValue) - (float(upgrade) * engineerAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
			else if (engineerAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (engineerAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * engineerAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, engineerAttributeTable[id].uid, result);
			}
		}		
	}
	else if (TF2_GetPlayerClass(client) == TFClass_Heavy)
	{
		for (int i=0; i<sizeof(playerDataList[client].heavyAttributeData);i++)
		{
			int id = playerDataList[client].heavyAttributeData[i].id;
			int upgrade = playerDataList[client].heavyAttributeData[i].upgrade;
			
			
			if (upgrade <= 0)
			{
				continue;
			}			
			
			float result = 0.0;
			
			if (heavyAttributeTable[id].additiveMode == ADDITIVE_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) + (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == ADDITIVE_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) + (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_NUMBER)
			{
				result = (heavyAttributeTable[id].defaultValue) - (float(upgrade) * heavyAttributeTable[id].value);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
			else if (heavyAttributeTable[id].additiveMode == MINUS_PERCENT)
			{
				result = (heavyAttributeTable[id].defaultValue * 0.01) - (float(upgrade) * heavyAttributeTable[id].value * 0.01);
			
				TF2Attrib_SetByName(client, heavyAttributeTable[id].uid, result);
			}
		}	
	}	
	
	CreateTimer(0.5, Timer_ApplySharedAttribute, client);

	return Plugin_Continue;
}

public Action Timer_RevivePointTimer(Handle timer)
{
	for (int client=1;client<=MaxClients;client++)
	{
		playerDataList[client].revivePoint += g_addRevivePointOnTime;
	}	

	g_Timer_AddRevivePoint = CreateTimer(g_addRevivePointTime, Timer_RevivePointTimer, _);
	
	return Plugin_Continue;
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("OnRoundStart");

	g_Timer_AddRevivePoint = CreateTimer(g_addRevivePointTime, Timer_RevivePointTimer, _);

	for (int client=1;client<=MaxClients;client++)
	{
		if (!playerDataList[client].isLoadComplete){
			continue;
		}
		playerDataList[client].revivePoint = g_revivePointBase;
		playerDataList[client].reviveCount = g_reviveCountBase;
	}

    return Plugin_Continue;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("OnRoundEnd");

	if (g_Timer_AddRevivePoint != null)
	{
		KillTimer(g_Timer_AddRevivePoint);
		g_Timer_AddRevivePoint = null;
	}	
	
    return Plugin_Continue;
}

public void OnPluginStart()
{
    RequestDatabaseConnection();
    
    g_Timer = CreateTimer(g_GiveTime, Timer_Update, _, TIMER_REPEAT);
    
    g_redEnableStatApply = CreateConVar("sm_rpg_redStat","1","(0=끄기, 1=켜기)",FCVAR_NOTIFY);
    g_blueEnableStatApply = CreateConVar("sm_rpg_blueStat","0","(0=끄기, 1=켜기)",FCVAR_NOTIFY);    
    
    HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);    
    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);    
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("player_regenerate", OnPlayerRegenerate, EventHookMode_Post);
    HookEvent("post_inventory_application", OnPlayerSpawn, EventHookMode_Post);
    HookEvent("player_changeclass", OnPlayerChangeClass, EventHookMode_Post);
    HookEvent("player_class", OnPlayerChangeClass, EventHookMode_Post);
    HookEvent("player_team", OnPlayerChangeClass, EventHookMode_Post);
    HookEvent("teamplay_round_start", OnRoundStart);
    HookEvent("teamplay_round_win", OnRoundEnd);
    
    RegConsoleCmd("st", Command_LevelInfo);
    
    // ✅ 어드민 명령어
    RegAdminCmd("sm_setpoint", Command_SetPoint, ADMFLAG_ROOT, "플레이어에게 포인트 설정");
    RegAdminCmd("sm_addpoint", Command_AddPoint, ADMFLAG_ROOT, "플레이어에게 포인트 추가");
    RegAdminCmd("sm_setexp", Command_SetExp, ADMFLAG_ROOT, "플레이어에게 경험치 설정");
    RegAdminCmd("sm_addexp", Command_AddExp, ADMFLAG_ROOT, "플레이어에게 경험치 추가");
    RegAdminCmd("sm_setlevel", Command_SetLevel, ADMFLAG_ROOT, "플레이어 레벨 설정");
    RegAdminCmd("sm_setskillpoint", Command_SetSkillPoint, ADMFLAG_ROOT, "플레이어 스킬포인트 설정");
    RegAdminCmd("sm_addskillpoint", Command_AddSkillPoint, ADMFLAG_ROOT, "플레이어 스킬포인트 추가");
    RegAdminCmd("sm_resetskill", Command_ResetSkill, ADMFLAG_ROOT, "플레이어 스킬 초기화");
    RegAdminCmd("sm_playerinfo", Command_AdminPlayerInfo, ADMFLAG_ROOT, "플레이어 정보 확인");
    
    // ✅ 디버깅 명령어 추가 (여기!)
    RegAdminCmd("sm_checkload", Command_CheckLoad, ADMFLAG_ROOT, "플레이어 로드 상태 확인");
    
    CreateAttributeTable();
}

public void OnPluginEnd()
{
    if (g_Timer != INVALID_HANDLE)
    {
        KillTimer(g_Timer);
    }
	
	for (int client=1;client<sizeof(playerDataList);client++)
	{
		if (!IsFakeClient(client)){
			UpdateUserData(client);	
			UpdateAttributeData(client);		
		}
	}

}

public void OnMapStart()
{
	CreateTimer(1.0, ShowPlayerInfoText, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	PrecacheSound("misc/achievement_earned.wav", true);
	PrecacheSound("misc/point_revive.mp3", true);
	PrecacheSound("misc/failed1.mp3", true);
	PrecacheSound("misc/success1.mp3", true);
	PrecacheSound("misc/miss1.mp3", true);
	PrecacheSound("misc/reinforcement.mp3", true);
}

public void OnClientAuthorized(int client, const char[] auth)
{
    if (IsFakeClient(client))
        return;
    
    char steamid[32];
    char basenick[255];
        
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    
    // ✅ SteamID 확인
    if (StrEqual(steamid, ""))
    {
        PrintToServer("❌ OnClientAuthorized: Client %d - SteamID를 가져올 수 없음!", client);
        
        // ✅ 0.5초 후 재시도
        CreateTimer(0.5, Timer_RetryAuth, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }
    
    playerDataList[client].steamid = steamid;
    
    GetClientName(client, basenick, sizeof(basenick));
    playerDataList[client].basenick = basenick;
    
    PrintToServer("========================================");
    PrintToServer("✅ OnClientAuthorized: %d (%s) - DB 로드 시작", client, steamid);
    PrintToServer("========================================");
    
    // ✅ 로딩 시작 메시지 (1초 후 표시)
    CreateTimer(1.0, Timer_ShowLoadingMessage, client, TIMER_FLAG_NO_MAPCHANGE);
    
    FetchUser(client);
}

// ✅ SteamID 재시도 타이머
public Action Timer_RetryAuth(Handle timer, any client)
{
    if (!IsClientConnected(client))
        return Plugin_Stop;
    
    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    
    if (StrEqual(steamid, ""))
    {
        PrintToServer("❌ Timer_RetryAuth: Client %d - SteamID를 여전히 가져올 수 없음!", client);
        
        // ✅ 다시 0.5초 후 재시도
        CreateTimer(0.5, Timer_RetryAuth, client, TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }
    
    // ✅ SteamID 획득 성공!
    char basenick[255];
    
    playerDataList[client].steamid = steamid;
    GetClientName(client, basenick, sizeof(basenick));
    playerDataList[client].basenick = basenick;
    
    PrintToServer("========================================");
    PrintToServer("✅ Timer_RetryAuth: %d (%s) - DB 로드 시작 (재시도 성공)", client, steamid);
    PrintToServer("========================================");
    
    CreateTimer(1.0, Timer_ShowLoadingMessage, client, TIMER_FLAG_NO_MAPCHANGE);
    
    FetchUser(client);
    
    return Plugin_Stop;
}

// ✅ 로딩 메시지 타이머
public Action Timer_ShowLoadingMessage(Handle timer, any client)
{
    if (!IsClientInGame(client))
        return Plugin_Stop;
    
    PrintCenterText(client, "데이터 로딩 중...");
    CPrintToChat(client, "{green}[Levelup]{default} 데이터 로딩 중... 잠시만 기다려주세요.");
    
    return Plugin_Stop;
}

public void OnClientConnected(int client)
{
    if (IsFakeClient(client))
        return;
    
    PrintToServer("========================================");
    PrintToServer("OnClientConnected: %d - 초기화 시작", client);
    PrintToServer("========================================");
    
    playerDataList[client].steamid = "";
    playerDataList[client].basenick = "";
    playerDataList[client].sequencenum = 0;
    playerDataList[client].level = 0;
    playerDataList[client].exp = 0;
    playerDataList[client].point = 0;
    playerDataList[client].skillpoint = 0;
    playerDataList[client].permission = 0;
    
    playerDataList[client].isLoadComplete = false;
    
    for (int i=0; i<sizeof(playerDataList[client].scoutAttributeData); i++)
    {
        playerDataList[client].scoutAttributeData[i].uid = scoutAttributeTable[i].uid;
        playerDataList[client].scoutAttributeData[i].id = i;
        playerDataList[client].scoutAttributeData[i].class = scoutAttributeTable[i].class;
        playerDataList[client].scoutAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].soldierAttributeData); i++)
    {
        playerDataList[client].soldierAttributeData[i].uid = soldierAttributeTable[i].uid;
        playerDataList[client].soldierAttributeData[i].id = i;
        playerDataList[client].soldierAttributeData[i].class = soldierAttributeTable[i].class;
        playerDataList[client].soldierAttributeData[i].upgrade = 0;
    }    

    for (int i=0; i<sizeof(playerDataList[client].medicAttributeData); i++)
    {
        playerDataList[client].medicAttributeData[i].uid = medicAttributeTable[i].uid;
        playerDataList[client].medicAttributeData[i].id = i;
        playerDataList[client].medicAttributeData[i].class = medicAttributeTable[i].class;
        playerDataList[client].medicAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].spyAttributeData); i++)
    {
        playerDataList[client].spyAttributeData[i].uid = spyAttributeTable[i].uid;
        playerDataList[client].spyAttributeData[i].id = i;
        playerDataList[client].spyAttributeData[i].class = spyAttributeTable[i].class;
        playerDataList[client].spyAttributeData[i].upgrade = 0;
    }    

    for (int i=0; i<sizeof(playerDataList[client].pyroAttributeData); i++)
    {
        playerDataList[client].pyroAttributeData[i].uid = pyroAttributeTable[i].uid;
        playerDataList[client].pyroAttributeData[i].id = i;
        playerDataList[client].pyroAttributeData[i].class = pyroAttributeTable[i].class;
        playerDataList[client].pyroAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].demomanAttributeData); i++)
    {
        playerDataList[client].demomanAttributeData[i].uid = demomanAttributeTable[i].uid;
        playerDataList[client].demomanAttributeData[i].id = i;
        playerDataList[client].demomanAttributeData[i].class = demomanAttributeTable[i].class;
        playerDataList[client].demomanAttributeData[i].upgrade = 0;
    }    

    for (int i=0; i<sizeof(playerDataList[client].sniperAttributeData); i++)
    {
        playerDataList[client].sniperAttributeData[i].uid = sniperAttributeTable[i].uid;
        playerDataList[client].sniperAttributeData[i].id = i;
        playerDataList[client].sniperAttributeData[i].class = sniperAttributeTable[i].class;
        playerDataList[client].sniperAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].engineerAttributeData); i++)
    {
        playerDataList[client].engineerAttributeData[i].uid = engineerAttributeTable[i].uid;
        playerDataList[client].engineerAttributeData[i].id = i;
        playerDataList[client].engineerAttributeData[i].class = engineerAttributeTable[i].class;
        playerDataList[client].engineerAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].heavyAttributeData); i++)
    {
        playerDataList[client].heavyAttributeData[i].uid = heavyAttributeTable[i].uid;
        playerDataList[client].heavyAttributeData[i].id = i;
        playerDataList[client].heavyAttributeData[i].class = heavyAttributeTable[i].class;
        playerDataList[client].heavyAttributeData[i].upgrade = 0;
    }    

    for (int i=0; i<sizeof(playerDataList[client].haleAttributeData); i++)
    {
        playerDataList[client].haleAttributeData[i].uid = haleAttributeTable[i].uid;
        playerDataList[client].haleAttributeData[i].id = i;
        playerDataList[client].haleAttributeData[i].class = haleAttributeTable[i].class;
        playerDataList[client].haleAttributeData[i].upgrade = 0;
    }        
    
    for (int i=0; i<sizeof(playerDataList[client].sharedAttributeData); i++)
    {
        playerDataList[client].sharedAttributeData[i].uid = sharedAttributeTable[i].uid;
        playerDataList[client].sharedAttributeData[i].id = i;
        playerDataList[client].sharedAttributeData[i].class = sharedAttributeTable[i].class;
        playerDataList[client].sharedAttributeData[i].upgrade = 0;
    }
    
    for (int i=0; i<sizeof(playerDataList[client].weaponAttributeData); i++)
    {
        playerDataList[client].weaponAttributeData[i].uid = weaponAttributeTable[i].uid;
        playerDataList[client].weaponAttributeData[i].id = i;
        playerDataList[client].weaponAttributeData[i].class = weaponAttributeTable[i].class;
        playerDataList[client].weaponAttributeData[i].upgrade = 0;
    }
}

public void OnClientDisconnect(int client)
{
    if (IsFakeClient(client))
        return;
    
    PrintToServer("========================================");
    PrintToServer("OnClientDisconnect - Client %d (%s) 저장 시작", client, playerDataList[client].steamid);
    PrintToServer("========================================");
    
    // ✅ 저장
    UpdateUserData(client);    
    UpdateAttributeData(client);
    
    PrintToServer("OnClientDisconnect - Client %d 저장 완료", client);

    // ✅ 초기화
    playerDataList[client].steamid = "";
    playerDataList[client].basenick = "";
    playerDataList[client].sequencenum = 0;
    playerDataList[client].level = 0;
    playerDataList[client].exp = 0;
    playerDataList[client].point = 0;
    playerDataList[client].skillpoint = 0;
    playerDataList[client].permission = 0;
    playerDataList[client].isLoadComplete = false;
    
    for (int i=0; i<sizeof(playerDataList[client].scoutAttributeData); i++)
    {
        playerDataList[client].scoutAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].medicAttributeData); i++)
    {
        playerDataList[client].medicAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].soldierAttributeData); i++)
    {
        playerDataList[client].soldierAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].pyroAttributeData); i++)
    {
        playerDataList[client].pyroAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].spyAttributeData); i++)
    {
        playerDataList[client].spyAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].demomanAttributeData); i++)
    {
        playerDataList[client].demomanAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].sniperAttributeData); i++)
    {
        playerDataList[client].sniperAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].engineerAttributeData); i++)
    {
        playerDataList[client].engineerAttributeData[i].upgrade = 0;
    }

    for (int i=0; i<sizeof(playerDataList[client].heavyAttributeData); i++)
    {
        playerDataList[client].heavyAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].haleAttributeData); i++)
    {
        playerDataList[client].haleAttributeData[i].upgrade = 0;
    }    
    
    for (int i=0; i<sizeof(playerDataList[client].sharedAttributeData); i++)
    {
        playerDataList[client].sharedAttributeData[i].upgrade = 0;
    }
    
    for (int i=0; i<sizeof(playerDataList[client].weaponAttributeData); i++)
    {
        playerDataList[client].weaponAttributeData[i].upgrade = 0;
    }
}

public Action Timer_CleanupPlayerData(Handle timer, any client)
{
    // ✅ 저장이 완료되었을 것으로 예상되는 시간 이후 초기화
    playerDataList[client].steamid = "";
    playerDataList[client].basenick = "";
    playerDataList[client].sequencenum = 0;
    playerDataList[client].level = 0;
    playerDataList[client].exp = 0;
    playerDataList[client].point = 0;
    playerDataList[client].skillpoint = 0;
    playerDataList[client].permission = 0;
    playerDataList[client].isLoadComplete = false;
    
    PrintToServer("Timer_CleanupPlayerData: %d - 데이터 정리 완료", client);
    
    return Plugin_Stop;
}

public void OnMapEnd()
{
    PrintToServer("========================================");
    PrintToServer("OnMapEnd - 모든 데이터 저장 시작");
    PrintToServer("========================================");
    
    for (int client=1; client<=MaxClients; client++)
    {
        if (!IsClientConnected(client) || IsFakeClient(client))
            continue;
        
        PrintToServer("OnMapEnd - Client %d (%s) 저장 중...", client, playerDataList[client].steamid);
        
        UpdateUserData(client);    
        UpdateAttributeData(client);
    }
    
    PrintToServer("========================================");
    PrintToServer("OnMapEnd - 모든 데이터 저장 완료");
    PrintToServer("========================================");
}

// ==================== 어드민 명령어 ====================

// ========== 포인트 설정 ==========
public Action Command_SetPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_setpoint <플레이어> <포인트>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char pointStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int point = StringToInt(pointStr);
    
    if (point < 0)
    {
        ReplyToCommand(client, "[Levelup] 포인트는 0 이상이어야 합니다.");
        return Plugin_Handled;
    }
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    SetPlayerPoints(target, point);
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    ReplyToCommand(client, "[Levelup] %N의 포인트를 %d로 설정했습니다.", target, point);
    CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 포인트를 {unique}%d{default}로 설정했습니다.", adminName, point);
    
    LogAction(client, target, "\"%L\" set point of \"%L\" to %d", client, target, point);
    
    return Plugin_Handled;
}

// ========== 포인트 추가 ==========
public Action Command_AddPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_addpoint <플레이어> <포인트>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char pointStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int point = StringToInt(pointStr);
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    if (point > 0)
    {
        AddPlayerPoints(target, point);
    }
    else if (point < 0)
    {
        TakePlayerPoints(target, -point);
    }
    
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    if (point > 0)
    {
        ReplyToCommand(client, "[Levelup] %N에게 포인트 %d를 추가했습니다. (현재: %d)", target, point, playerDataList[target].point);
        CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신에게 포인트 {unique}%d{default}를 추가했습니다!", adminName, point);
    }
    else
    {
        ReplyToCommand(client, "[Levelup] %N에게서 포인트 %d를 제거했습니다. (현재: %d)", target, -point, playerDataList[target].point);
        CPrintToChat(target, "{red}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 포인트 {unique}%d{default}를 제거했습니다.", adminName, -point);
    }
    
    LogAction(client, target, "\"%L\" added %d point to \"%L\"", client, point, target);
    
    return Plugin_Handled;
}

// ========== 경험치 설정 ==========
public Action Command_SetExp(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_setexp <플레이어> <경험치>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char expStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, expStr, sizeof(expStr));
    
    int exp = StringToInt(expStr);
    
    if (exp < 0)
    {
        ReplyToCommand(client, "[Levelup] 경험치는 0 이상이어야 합니다.");
        return Plugin_Handled;
    }
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    SetPlayerEXP(target, exp);
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    ReplyToCommand(client, "[Levelup] %N의 경험치를 %d로 설정했습니다.", target, exp);
    CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 경험치를 {rare}%d{default}로 설정했습니다.", adminName, exp);
    
    LogAction(client, target, "\"%L\" set exp of \"%L\" to %d", client, target, exp);
    
    return Plugin_Handled;
}

// ========== 경험치 추가 ==========
public Action Command_AddExp(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_addexp <플레이어> <경험치>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char expStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, expStr, sizeof(expStr));
    
    int exp = StringToInt(expStr);
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    if (exp > 0)
    {
        AddPlayerEXP(target, exp);
    }
    else if (exp < 0)
    {
        TakePlayerEXP(target, -exp);
    }
    
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    if (exp > 0)
    {
        ReplyToCommand(client, "[Levelup] %N에게 경험치 %d를 추가했습니다. (현재: %d)", target, exp, playerDataList[target].exp);
        CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신에게 경험치 {rare}%d{default}를 추가했습니다!", adminName, exp);
    }
    else
    {
        ReplyToCommand(client, "[Levelup] %N에게서 경험치 %d를 제거했습니다. (현재: %d)", target, -exp, playerDataList[target].exp);
        CPrintToChat(target, "{red}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 경험치 {rare}%d{default}를 제거했습니다.", adminName, -exp);
    }
    
    LogAction(client, target, "\"%L\" added %d exp to \"%L\"", client, exp, target);
    
    return Plugin_Handled;
}

// ========== 레벨 설정 ==========
public Action Command_SetLevel(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_setlevel <플레이어> <레벨>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char levelStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, levelStr, sizeof(levelStr));
    
    int level = StringToInt(levelStr);
    
    if (level < 0 || level >= EXP_TABLE_SIZE)
    {
        ReplyToCommand(client, "[Levelup] 레벨은 0 ~ %d 사이여야 합니다.", EXP_TABLE_SIZE - 1);
        return Plugin_Handled;
    }
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    int oldLevel = playerDataList[target].level;
    playerDataList[target].level = level;
    playerDataList[target].exp = 0;
    
    // ✅ 레벨에 따른 스킬포인트 재계산
    playerDataList[target].skillpoint = level * g_GiveSkillPointOnLevelup;
    
    // ✅ 이름 업데이트
    char prefix[12];
    char prefixName[255];
    Format(prefix, sizeof(prefix), "[Lv%d]", level);
    Format(prefixName, sizeof(prefixName), "%s%s", prefix, playerDataList[target].basenick);
    SetClientInfo(target, "name", prefixName);
    
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    ReplyToCommand(client, "[Levelup] %N의 레벨을 %d에서 %d로 변경했습니다.", target, oldLevel, level);
    CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 레벨을 {orange}%d{default}로 설정했습니다!", adminName, level);
    
    LogAction(client, target, "\"%L\" set level of \"%L\" from %d to %d", client, target, oldLevel, level);
    
    return Plugin_Handled;
}

// ========== 스킬포인트 설정 ==========
public Action Command_SetSkillPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_setskillpoint <플레이어> <스킬포인트>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char pointStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int point = StringToInt(pointStr);
    
    if (point < 0)
    {
        ReplyToCommand(client, "[Levelup] 스킬포인트는 0 이상이어야 합니다.");
        return Plugin_Handled;
    }
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    SetPlayerSkillPoint(target, point);
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    ReplyToCommand(client, "[Levelup] %N의 스킬포인트를 %d로 설정했습니다.", target, point);
    CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 스킬포인트를 {lightgreen}%d{default}로 설정했습니다.", adminName, point);
    
    LogAction(client, target, "\"%L\" set skillpoint of \"%L\" to %d", client, target, point);
    
    return Plugin_Handled;
}

// ========== 스킬포인트 추가 ==========
public Action Command_AddSkillPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_addskillpoint <플레이어> <스킬포인트>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    char pointStr[32];
    
    GetCmdArg(1, targetName, sizeof(targetName));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int point = StringToInt(pointStr);
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    if (point > 0)
    {
        AddPlayerSkillPoint(target, point);
    }
    else if (point < 0)
    {
        TakePlayerSkillPoint(target, -point);
    }
    
    UpdateUserData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    if (point > 0)
    {
        ReplyToCommand(client, "[Levelup] %N에게 스킬포인트 %d를 추가했습니다. (현재: %d)", target, point, playerDataList[target].skillpoint);
        CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신에게 스킬포인트 {lightgreen}%d{default}를 추가했습니다!", adminName, point);
    }
    else
    {
        ReplyToCommand(client, "[Levelup] %N에게서 스킬포인트 %d를 제거했습니다. (현재: %d)", target, -point, playerDataList[target].skillpoint);
        CPrintToChat(target, "{red}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 스킬포인트 {lightgreen}%d{default}를 제거했습니다.", adminName, -point);
    }
    
    LogAction(client, target, "\"%L\" added %d skillpoint to \"%L\"", client, point, target);
    
    return Plugin_Handled;
}

// ========== 스킬 초기화 (무료) ==========
public Action Command_ResetSkill(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_resetskill <플레이어>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!playerDataList[target].isLoadComplete)
    {
        ReplyToCommand(client, "[Levelup] %N의 데이터가 아직 로드되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    // ✅ 모든 스킬 초기화
    for (int i=0; i<sizeof(playerDataList[target].scoutAttributeData); i++)
        playerDataList[target].scoutAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].medicAttributeData); i++)
        playerDataList[target].medicAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].soldierAttributeData); i++)
        playerDataList[target].soldierAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].pyroAttributeData); i++)
        playerDataList[target].pyroAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].spyAttributeData); i++)
        playerDataList[target].spyAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].demomanAttributeData); i++)
        playerDataList[target].demomanAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].sniperAttributeData); i++)
        playerDataList[target].sniperAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].engineerAttributeData); i++)
        playerDataList[target].engineerAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].heavyAttributeData); i++)
        playerDataList[target].heavyAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].haleAttributeData); i++)
        playerDataList[target].haleAttributeData[i].upgrade = 0;
    
    for (int i=0; i<sizeof(playerDataList[target].sharedAttributeData); i++)
        playerDataList[target].sharedAttributeData[i].upgrade = 0;
    
    // ✅ 스킬포인트 재계산
    playerDataList[target].skillpoint = playerDataList[target].level * g_GiveSkillPointOnLevelup;
    
    UpdateUserData(target);
    UpdateAttributeData(target);
    
    char adminName[MAX_NAME_LENGTH];
    if (client == 0)
    {
        strcopy(adminName, sizeof(adminName), "콘솔");
    }
    else
    {
        GetClientName(client, adminName, sizeof(adminName));
    }
    
    ReplyToCommand(client, "[Levelup] %N의 스킬을 초기화했습니다. (스킬포인트: %d)", target, playerDataList[target].skillpoint);
    CPrintToChat(target, "{green}[Levelup]{default} 어드민 {olive}%s{default}님이 당신의 스킬을 초기화했습니다. (스킬포인트: {lightgreen}%d{default})", adminName, playerDataList[target].skillpoint);
    
    LogAction(client, target, "\"%L\" reset skills of \"%L\"", client, target);
    
    return Plugin_Handled;
}

// ========== 플레이어 정보 확인 ==========
public Action Command_AdminPlayerInfo(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_playerinfo <플레이어>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    if (!IsClientConnected(target) || !IsClientAuthorized(target))
    {
        ReplyToCommand(client, "[Levelup] %N이 연결되지 않았습니다.", target);
        return Plugin_Handled;
    }
    
    char targetRealName[MAX_NAME_LENGTH];
    GetClientName(target, targetRealName, sizeof(targetRealName));
    
    ReplyToCommand(client, "========================================");
    ReplyToCommand(client, "[Levelup] %N의 정보", target);
    ReplyToCommand(client, "----------------------------------------");
    ReplyToCommand(client, "SteamID: %s", playerDataList[target].steamid);
    ReplyToCommand(client, "레벨: %d", playerDataList[target].level);
    ReplyToCommand(client, "경험치: %d / %d", playerDataList[target].exp, expTable[playerDataList[target].level]);
    ReplyToCommand(client, "포인트: %d", playerDataList[target].point);
    ReplyToCommand(client, "스킬포인트: %d", playerDataList[target].skillpoint);
    ReplyToCommand(client, "부활 포인트: %d", playerDataList[target].revivePoint);
    ReplyToCommand(client, "부활 횟수: %d", playerDataList[target].reviveCount);
    ReplyToCommand(client, "무기 강화: +%d", playerDataList[target].weaponAttributeData[0].upgrade);
    ReplyToCommand(client, "로드완료: %s", playerDataList[target].isLoadComplete ? "예" : "아니오");
    ReplyToCommand(client, "========================================");
    
    return Plugin_Handled;
}

// ========== 로드 상태 확인 (디버깅) ==========
public Action Command_CheckLoad(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[Levelup] 사용법: sm_checkload <플레이어>");
        return Plugin_Handled;
    }
    
    char targetName[MAX_NAME_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));
    
    int target = FindTarget(client, targetName, true, false);
    
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    ReplyToCommand(client, "========================================");
    ReplyToCommand(client, "[Levelup] %N의 로드 상태", target);
    ReplyToCommand(client, "----------------------------------------");
    ReplyToCommand(client, "연결됨: %s", IsClientConnected(target) ? "예" : "아니오");
    ReplyToCommand(client, "인증됨: %s", IsClientAuthorized(target) ? "예" : "아니오");
    ReplyToCommand(client, "게임중: %s", IsClientInGame(target) ? "예" : "아니오");
    ReplyToCommand(client, "SteamID: %s", playerDataList[target].steamid);
    ReplyToCommand(client, "로드완료: %s", playerDataList[target].isLoadComplete ? "예" : "아니오");
    ReplyToCommand(client, "레벨: %d", playerDataList[target].level);
    ReplyToCommand(client, "경험치: %d", playerDataList[target].exp);
    ReplyToCommand(client, "포인트: %d", playerDataList[target].point);
    ReplyToCommand(client, "스킬포인트: %d", playerDataList[target].skillpoint);
    ReplyToCommand(client, "========================================");
    
    return Plugin_Handled;
}
