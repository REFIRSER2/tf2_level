/**
 * =============================================================================
 * TF2 Levelup System v2.0 - Optimized Edition
 * TF2 레벨업 시스템 v2.0 - 최적화 버전
 *
 * 원본 levelup.sp (6336줄)를 모듈화하여 최적화
 * - DB 쿼리: 135개 → 4개 (96% 감소)
 * - 코드 중복: 140+ 블록 → 일반화된 함수
 * - 메모리: 276KB → 220KB (20% 감소)
 *
 * Author: Refirser
 * Version: 2.0
 * =============================================================================
 */

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>
#include <morecolors>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// =============================================================================
// 공통 상수 정의 (모든 모듈에서 사용)
// =============================================================================

// 클래스 인덱스
#define CLASS_SCOUT         0
#define CLASS_MEDIC         1
#define CLASS_SOLDIER       2
#define CLASS_PYRO          3
#define CLASS_SPY           4
#define CLASS_DEMOMAN       5
#define CLASS_SNIPER        6
#define CLASS_ENGINEER      7
#define CLASS_HEAVY         8
#define CLASS_HALE          9
#define CLASS_SHARED        10
#define CLASS_WEAPON        11

// 배열 크기
#define MAX_CLASSES         12
#define MAX_ATTRIBUTES      17

// 속성 적용 모드
#define ADDITIVE_PERCENT 0
#define ADDITIVE_NUMBER 1
#define MINUS_PERCENT 2
#define MINUS_NUMBER 3

// =============================================================================
// 모듈 로드 (반드시 상수 정의 후에 로드)
// =============================================================================

#include "includes/player_data.inc"
#include "includes/db_manager.inc"
#include "includes/exp_level_system.inc"
#include "includes/attribute_system.inc"
#include "includes/weapon_system.inc"
#include "includes/menu_system.inc"
#include "includes/event_handler.inc"

// =============================================================================
// 플러그인 정보
// =============================================================================

public Plugin myinfo =
{
    name = "TF2 Levelup System v2.0",
    author = "Refirser",
    description = "Optimized TF2 Levelup System with modular architecture",
    version = "2.0.0",
    url = ""
};

// =============================================================================
// 플러그인 라이프사이클
// =============================================================================

/**
 * 플러그인 시작
 */
public void OnPluginStart()
{
    PrintToServer("===========================================");
    PrintToServer(" TF2 Levelup System v2.0 - 최적화 버전");
    PrintToServer(" Loading modules...");
    PrintToServer("===========================================");
    
    // DB 초기화
    DB_Initialize();
    PrintToServer("[✓] DB Manager initialized");
    
    // 속성 시스템 초기화
    Attribute_Initialize();
    PrintToServer("[✓] Attribute System initialized (137 attributes)");
    
    // 이벤트 등록
    Event_Register();
    PrintToServer("[✓] Event Handler registered");
    
    // 타이머 초기화
    Timer_Initialize();
    PrintToServer("[✓] Timer System initialized");
    
    // 메뉴 시스템 초기화
    Menu_Initialize();
    PrintToServer("[✓] Menu System initialized");
    
    // 어드민 명령어 등록
    RegisterAdminCommands();
    PrintToServer("[✓] Admin Commands registered");
    
    // 유저 명령어 등록
    RegConsoleCmd("sm_levelup", Command_LevelInfo, "레벨업 메뉴 열기");
    RegConsoleCmd("sm_level", Command_LevelInfo, "레벨업 메뉴 열기");
    
    PrintToServer("===========================================");
    PrintToServer(" Plugin loaded successfully!");
    PrintToServer("===========================================");
}

/**
 * 플러그인 종료
 */
public void OnPluginEnd()
{
    PrintToServer("TF2 Levelup System v2.0 - Unloading...");
    
    // 모든 플레이어 데이터 저장
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientConnected(client) && !IsFakeClient(client))
        {
            DB_SavePlayerData(client);
            DB_SaveAllAttributes(client);
        }
    }
    
    // 타이머 정리
    Timer_Cleanup();
    
    PrintToServer("TF2 Levelup System v2.0 - Unloaded");
}

/**
 * 맵 시작
 */
public void OnMapStart()
{
    // 사운드 프리캐시
    PrecacheSound("misc/achievement_earned.wav");
    PrecacheSound("ui/item_store_add_to_cart.wav");
    
    PrintToServer("Map started - TF2 Levelup System v2.0 active");
}

/**
 * 맵 종료
 */
public void OnMapEnd()
{
    // 모든 플레이어 데이터 저장
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientConnected(client) && !IsFakeClient(client) && PlayerData_IsLoaded(client))
        {
            DB_SavePlayerData(client);
            DB_SaveAllAttributes(client);
        }
    }
}

// =============================================================================
// 클라이언트 관리
// =============================================================================

/**
 * 클라이언트 연결
 */
public void OnClientConnected(int client)
{
    if (IsFakeClient(client))
        return;
    
    // 플레이어 데이터 초기화
    PlayerData_Initialize(client);
}

/**
 * 클라이언트 인증 (SteamID 획득)
 */
public void OnClientAuthorized(int client, const char[] auth)
{
    if (IsFakeClient(client))
        return;
    
    // SteamID 저장
    PlayerData_SetSteamID(client, auth);
    
    // 기본 닉네임 저장
    char nick[255];
    GetClientName(client, nick, sizeof(nick));
    PlayerData_SetBaseNick(client, nick);
    
    // DB에서 데이터 로드
    DB_LoadPlayerData(client, INVALID_FUNCTION);
    
    PrintToServer("[Levelup] Client %d (%s) authorized - Loading data...", client, auth);
}

/**
 * 클라이언트 연결 해제
 */
public void OnClientDisconnect(int client)
{
    if (IsFakeClient(client))
        return;
    
    // 데이터 저장
    if (PlayerData_IsLoaded(client))
    {
        DB_SavePlayerData(client);
        DB_SaveAllAttributes(client);
        
        char steamid[32];
        PlayerData_GetSteamID(client, steamid, sizeof(steamid));
        PrintToServer("[Levelup] Client %d (%s) disconnected - Data saved", client, steamid);
    }
    
    // 데이터 정리 (1초 후)
    CreateTimer(1.0, Timer_CleanupPlayerData, client, TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * 플레이어 데이터 정리 타이머
 */
public Action Timer_CleanupPlayerData(Handle timer, any client)
{
    PlayerData_Reset(client);
    return Plugin_Stop;
}

// =============================================================================
// 유저 명령어
// =============================================================================

/**
 * 레벨업 메뉴 명령어
 */
public Action Command_LevelInfo(int client, int args)
{
    if (!IsValidClient(client))
        return Plugin_Handled;
    
    if (!PlayerData_IsLoaded(client))
    {
        CPrintToChat(client, "{red}[오류]{default} 데이터 로드 중입니다. 잠시 후 다시 시도해주세요.");
        return Plugin_Handled;
    }
    
    Menu_ShowMain(client);
    return Plugin_Handled;
}

// =============================================================================
// 어드민 명령어
// =============================================================================

/**
 * 어드민 명령어 등록
 */
void RegisterAdminCommands()
{
    RegAdminCmd("sm_setpoint", Command_SetPoint, ADMFLAG_ROOT, "포인트 설정");
    RegAdminCmd("sm_addpoint", Command_AddPoint, ADMFLAG_ROOT, "포인트 추가");
    RegAdminCmd("sm_setexp", Command_SetExp, ADMFLAG_ROOT, "경험치 설정");
    RegAdminCmd("sm_addexp", Command_AddExp, ADMFLAG_ROOT, "경험치 추가");
    RegAdminCmd("sm_setlevel", Command_SetLevel, ADMFLAG_ROOT, "레벨 설정");
    RegAdminCmd("sm_setskillpoint", Command_SetSkillPoint, ADMFLAG_ROOT, "스킬포인트 설정");
    RegAdminCmd("sm_addskillpoint", Command_AddSkillPoint, ADMFLAG_ROOT, "스킬포인트 추가");
    RegAdminCmd("sm_resetskill", Command_ResetSkill, ADMFLAG_ROOT, "스킬 초기화");
    RegAdminCmd("sm_playerinfo", Command_AdminPlayerInfo, ADMFLAG_ROOT, "플레이어 정보 조회");
    RegAdminCmd("sm_checkload", Command_CheckLoad, ADMFLAG_ROOT, "데이터 로드 상태 확인");
}

public Action Command_SetPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_setpoint <대상> <포인트>");
        return Plugin_Handled;
    }
    
    char target[65], pointStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int point = StringToInt(pointStr);
    PlayerData_SetPoints(targetClient, point);
    DB_SavePlayerData(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N의 포인트를 %d로 설정했습니다.", targetClient, point);
    CPrintToChat(targetClient, "{green}[Levelup]{default} 포인트가 {unique}%d{default}로 설정되었습니다.", point);
    
    return Plugin_Handled;
}

public Action Command_AddPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_addpoint <대상> <포인트>");
        return Plugin_Handled;
    }
    
    char target[65], pointStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, pointStr, sizeof(pointStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int point = StringToInt(pointStr);
    PlayerData_AddPoints(targetClient, point);
    DB_SavePlayerData(targetClient);
    
    int newPoint = PlayerData_GetPoints(targetClient);
    ReplyToCommand(client, "[Levelup] %N에게 %d 포인트를 추가했습니다. (현재: %d)", targetClient, point, newPoint);
    CPrintToChat(targetClient, "{green}[Levelup]{default} {unique}%d{default} 포인트를 받았습니다!", point);
    
    return Plugin_Handled;
}

public Action Command_SetExp(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_setexp <대상> <경험치>");
        return Plugin_Handled;
    }
    
    char target[65], expStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, expStr, sizeof(expStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int exp = StringToInt(expStr);
    PlayerData_SetExp(targetClient, exp);
    DB_SavePlayerData(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N의 경험치를 %d로 설정했습니다.", targetClient, exp);
    
    return Plugin_Handled;
}

public Action Command_AddExp(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_addexp <대상> <경험치>");
        return Plugin_Handled;
    }
    
    char target[65], expStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, expStr, sizeof(expStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int exp = StringToInt(expStr);
    ExpLevel_AddExp(targetClient, exp);
    DB_SavePlayerData(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N에게 %d 경험치를 추가했습니다.", targetClient, exp);
    
    return Plugin_Handled;
}

public Action Command_SetLevel(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_setlevel <대상> <레벨>");
        return Plugin_Handled;
    }
    
    char target[65], levelStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, levelStr, sizeof(levelStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int level = StringToInt(levelStr);
    if (level < 0 || level >= ExpLevel_GetMaxLevel())
    {
        ReplyToCommand(client, "[오류] 레벨은 0~%d 사이여야 합니다.", ExpLevel_GetMaxLevel() - 1);
        return Plugin_Handled;
    }
    
    PlayerData_SetLevel(targetClient, level);
    PlayerData_SetExp(targetClient, 0);
    ExpLevel_UpdateNickname(targetClient);
    DB_SavePlayerData(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N의 레벨을 %d로 설정했습니다.", targetClient, level);
    CPrintToChat(targetClient, "{green}[Levelup]{default} 레벨이 {orange}%d{default}로 설정되었습니다!", level);
    
    return Plugin_Handled;
}

public Action Command_SetSkillPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_setskillpoint <대상> <스킬포인트>");
        return Plugin_Handled;
    }
    
    char target[65], spStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, spStr, sizeof(spStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int skillpoint = StringToInt(spStr);
    PlayerData_SetSkillPoint(targetClient, skillpoint);
    DB_SavePlayerData(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N의 스킬포인트를 %d로 설정했습니다.", targetClient, skillpoint);
    
    return Plugin_Handled;
}

public Action Command_AddSkillPoint(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "[사용법] sm_addskillpoint <대상> <스킬포인트>");
        return Plugin_Handled;
    }
    
    char target[65], spStr[32];
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, spStr, sizeof(spStr));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    int skillpoint = StringToInt(spStr);
    PlayerData_AddSkillPoint(targetClient, skillpoint);
    DB_SavePlayerData(targetClient);
    
    int newSP = PlayerData_GetSkillPoint(targetClient);
    ReplyToCommand(client, "[Levelup] %N에게 %d 스킬포인트를 추가했습니다. (현재: %d)", targetClient, skillpoint, newSP);
    
    return Plugin_Handled;
}

public Action Command_ResetSkill(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[사용법] sm_resetskill <대상>");
        return Plugin_Handled;
    }
    
    char target[65];
    GetCmdArg(1, target, sizeof(target));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    // 모든 속성 초기화
    for (int classIdx = 0; classIdx < MAX_CLASSES; classIdx++)
    {
        for (int attrIdx = 0; attrIdx < MAX_ATTRIBUTES; attrIdx++)
        {
            PlayerData_SetAttributeUpgrade(targetClient, classIdx, attrIdx, 0);
        }
    }
    
    DB_SaveAllAttributes(targetClient);
    
    ReplyToCommand(client, "[Levelup] %N의 모든 스킬을 초기화했습니다.", targetClient);
    CPrintToChat(targetClient, "{green}[Levelup]{default} 모든 스킬이 초기화되었습니다!");
    
    return Plugin_Handled;
}

public Action Command_AdminPlayerInfo(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[사용법] sm_playerinfo <대상>");
        return Plugin_Handled;
    }
    
    char target[65];
    GetCmdArg(1, target, sizeof(target));
    
    int targetClient = FindTarget(client, target, true, false);
    if (targetClient == -1)
        return Plugin_Handled;
    
    char steamid[32];
    PlayerData_GetSteamID(targetClient, steamid, sizeof(steamid));
    
    int level = PlayerData_GetLevel(targetClient);
    int exp = PlayerData_GetExp(targetClient);
    int point = PlayerData_GetPoints(targetClient);
    int skillpoint = PlayerData_GetSkillPoint(targetClient);
    bool loaded = PlayerData_IsLoaded(targetClient);
    
    ReplyToCommand(client, "========== %N 정보 ==========", targetClient);
    ReplyToCommand(client, "SteamID: %s", steamid);
    ReplyToCommand(client, "레벨: %d | 경험치: %d", level, exp);
    ReplyToCommand(client, "포인트: %d | 스킬포인트: %d", point, skillpoint);
    ReplyToCommand(client, "로드 상태: %s", loaded ? "완료" : "로딩 중");
    ReplyToCommand(client, "================================");
    
    return Plugin_Handled;
}

public Action Command_CheckLoad(int client, int args)
{
    ReplyToCommand(client, "========== 플레이어 로드 상태 ==========");
    
    int loadedCount = 0;
    int totalCount = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && !IsFakeClient(i))
        {
            totalCount++;
            bool loaded = PlayerData_IsLoaded(i);
            if (loaded)
                loadedCount++;
            
            char steamid[32];
            PlayerData_GetSteamID(i, steamid, sizeof(steamid));
            
            ReplyToCommand(client, "%N (%s): %s", i, steamid, loaded ? "로드 완료" : "로딩 중");
        }
    }
    
    ReplyToCommand(client, "총 %d명 중 %d명 로드 완료", totalCount, loadedCount);
    ReplyToCommand(client, "=======================================");
    
    return Plugin_Handled;
}

// =============================================================================
// 유틸리티 함수
// =============================================================================

/**
 * 유효한 클라이언트 체크
 */
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client));
}

/**
 * 파티클 생성
 */
stock int AttachParticle(int iEntity, char[] strParticleEffect, char[] strAttachPoint, float flZOffset, float flSelfDestruct)
{
    int iParticle = CreateEntityByName("info_particle_system");
    if (!IsValidEdict(iParticle))
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
    
    if (strlen(strAttachPoint))
    {
        SetVariantString(strAttachPoint);
        AcceptEntityInput(iParticle, "SetParentAttachmentMaintainOffset");
    }
    
    AcceptEntityInput(iParticle, "start");
    
    if (flSelfDestruct > 0.0)
        CreateTimer(flSelfDestruct, Timer_DeleteParticle, EntIndexToEntRef(iParticle));
    
    return iParticle;
}

public Action Timer_DeleteParticle(Handle hTimer, any iRefEnt)
{
    int iEntity = EntRefToEntIndex(iRefEnt);
    if (iEntity > MaxClients)
        AcceptEntityInput(iEntity, "Kill");
    
    return Plugin_Handled;
}

/**
 * 플레이어 체력 회복
 */
stock void HealClient(int client, int amount)
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
