/**
 * =============================================================================
 * TF2 Level System - Player Data Module
 * 플레이어 데이터 관리 모듈
 *
 * 원본 levelup.sp의 11개 개별 배열을 3차원 배열로 통합하여 메모리 효율 개선
 * Getter/Setter 패턴으로 안전한 데이터 접근 제공
 * =============================================================================
 */

#if defined _tf2level_player_data_included
    #endinput
#endif
#define _tf2level_player_data_included

// =============================================================================
// 상수 정의
// =============================================================================

// 클래스 인덱스 상수
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

// 배열 크기 상수
#define MAX_CLASSES         12      // 총 클래스 수
#define MAX_ATTRIBUTES      17      // 클래스당 최대 속성 수 (Engineer 기준)

// 클래스별 실제 속성 개수
#define SCOUT_ATTR_COUNT    13
#define MEDIC_ATTR_COUNT    14
#define SOLDIER_ATTR_COUNT  13
#define PYRO_ATTR_COUNT     13
#define SPY_ATTR_COUNT      16
#define DEMOMAN_ATTR_COUNT  16
#define SNIPER_ATTR_COUNT   15
#define ENGINEER_ATTR_COUNT 17
#define HEAVY_ATTR_COUNT    14
#define HALE_ATTR_COUNT     3
#define SHARED_ATTR_COUNT   2
#define WEAPON_ATTR_COUNT   1

// 로드 상태 상수
#define LOAD_NONE           0
#define LOAD_PLAYERDATA     1
#define LOAD_CLASSATTRIBUTEDATA 2

// =============================================================================
// 데이터 구조체
// =============================================================================

/**
 * 속성 데이터 구조체
 * 각 클래스의 스킬/속성 정보를 저장
 */
enum struct AttributeData
{
    char uid[64];       // 속성 고유 ID
    int id;             // 속성 배열 인덱스
    int class;          // 클래스 ID
    int upgrade;        // 현재 업그레이드 레벨
}

/**
 * 플레이어 데이터 구조체
 * 플레이어의 레벨, 경험치, 포인트 등 기본 정보 저장
 */
enum struct PlayerData
{
    char steamid[32];           // Steam ID
    char basenick[255];         // 기본 닉네임 (접두사 제외)

    int sequencenum;            // 데이터베이스 동기화용 시퀀스 번호
    int level;                  // 현재 레벨
    int exp;                    // 현재 경험치
    int point;                  // 스킬 포인트
    int skillpoint;             // 추가 스킬 포인트

    int permission;             // 권한 레벨
    int damage;                 // 누적 데미지

    int revivePoint;            // 부활 포인트
    int reviveCount;            // 부활 횟수

    bool isLoadComplete;        // 데이터 로드 완료 여부
    int loadStatus;             // 현재 로드 상태 (LOAD_NONE, LOAD_PLAYERDATA, LOAD_CLASSATTRIBUTEDATA)
}

// =============================================================================
// 전역 변수
// =============================================================================

// 플레이어 기본 데이터 (원본 유지)
PlayerData g_playerDataList[MAXPLAYERS+1];

// 속성 데이터 - 3차원 배열로 통합 [플레이어][클래스][속성ID]
// 기존: 각 플레이어마다 11개 개별 배열 (scoutAttributeData[], medicAttributeData[], ...)
// 개선: 하나의 통합 3차원 배열로 메모리 효율성 향상
AttributeData g_playerAttributes[MAXPLAYERS+1][MAX_CLASSES][MAX_ATTRIBUTES];

// =============================================================================
// 초기화 및 리셋 함수
// =============================================================================

/**
 * 플레이어 데이터 초기화
 * 클라이언트 연결 시 호출
 *
 * @param client    플레이어 인덱스
 */
stock void PlayerData_Initialize(int client)
{
    if (!IsValidClient(client))
        return;

    // 기본 데이터 초기화
    g_playerDataList[client].steamid[0] = '\0';
    g_playerDataList[client].basenick[0] = '\0';
    g_playerDataList[client].sequencenum = 0;
    g_playerDataList[client].level = 0;
    g_playerDataList[client].exp = 0;
    g_playerDataList[client].point = 0;
    g_playerDataList[client].skillpoint = 0;
    g_playerDataList[client].permission = 0;
    g_playerDataList[client].damage = 0;
    g_playerDataList[client].revivePoint = 0;
    g_playerDataList[client].reviveCount = 0;
    g_playerDataList[client].isLoadComplete = false;
    g_playerDataList[client].loadStatus = LOAD_NONE;

    // 모든 클래스의 속성 데이터 초기화
    for (int classIdx = 0; classIdx < MAX_CLASSES; classIdx++)
    {
        for (int attrIdx = 0; attrIdx < MAX_ATTRIBUTES; attrIdx++)
        {
            g_playerAttributes[client][classIdx][attrIdx].uid[0] = '\0';
            g_playerAttributes[client][classIdx][attrIdx].id = attrIdx;
            g_playerAttributes[client][classIdx][attrIdx].class = classIdx;
            g_playerAttributes[client][classIdx][attrIdx].upgrade = 0;
        }
    }
}

/**
 * 플레이어 데이터 리셋
 * 연결 해제 또는 데이터 초기화 시 호출
 *
 * @param client    플레이어 인덱스
 */
stock void PlayerData_Reset(int client)
{
    PlayerData_Initialize(client);
}

/**
 * 플레이어 데이터 복사
 * 봇 교체 등의 상황에서 사용
 *
 * @param from      원본 플레이어 인덱스
 * @param to        대상 플레이어 인덱스
 */
stock void PlayerData_Copy(int from, int to)
{
    if (!IsValidClient(from) || !IsValidClient(to))
        return;

    // 기본 데이터 복사
    g_playerDataList[to] = g_playerDataList[from];

    // 속성 데이터 복사
    for (int classIdx = 0; classIdx < MAX_CLASSES; classIdx++)
    {
        for (int attrIdx = 0; attrIdx < MAX_ATTRIBUTES; attrIdx++)
        {
            g_playerAttributes[to][classIdx][attrIdx] = g_playerAttributes[from][classIdx][attrIdx];
        }
    }
}

// =============================================================================
// 기본 정보 Getter/Setter
// =============================================================================

/**
 * Steam ID 가져오기
 *
 * @param client    플레이어 인덱스
 * @param buffer    저장할 버퍼
 * @param maxlen    버퍼 최대 길이
 */
stock void PlayerData_GetSteamID(int client, char[] buffer, int maxlen)
{
    if (!IsValidClient(client))
    {
        buffer[0] = '\0';
        return;
    }
    strcopy(buffer, maxlen, g_playerDataList[client].steamid);
}

/**
 * Steam ID 설정
 *
 * @param client    플레이어 인덱스
 * @param steamid   Steam ID
 */
stock void PlayerData_SetSteamID(int client, const char[] steamid)
{
    if (!IsValidClient(client))
        return;
    strcopy(g_playerDataList[client].steamid, sizeof(g_playerDataList[].steamid), steamid);
}

/**
 * 기본 닉네임 가져오기
 *
 * @param client    플레이어 인덱스
 * @param buffer    저장할 버퍼
 * @param maxlen    버퍼 최대 길이
 */
stock void PlayerData_GetBaseNick(int client, char[] buffer, int maxlen)
{
    if (!IsValidClient(client))
    {
        buffer[0] = '\0';
        return;
    }
    strcopy(buffer, maxlen, g_playerDataList[client].basenick);
}

/**
 * 기본 닉네임 설정
 *
 * @param client    플레이어 인덱스
 * @param nick      닉네임
 */
stock void PlayerData_SetBaseNick(int client, const char[] nick)
{
    if (!IsValidClient(client))
        return;
    strcopy(g_playerDataList[client].basenick, sizeof(g_playerDataList[].basenick), nick);
}

// =============================================================================
// 레벨 & 경험치 Getter/Setter
// =============================================================================

/**
 * 레벨 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          현재 레벨
 */
stock int PlayerData_GetLevel(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].level;
}

/**
 * 레벨 설정
 *
 * @param client    플레이어 인덱스
 * @param level     설정할 레벨
 */
stock void PlayerData_SetLevel(int client, int level)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].level = level;
}

/**
 * 레벨 증가
 *
 * @param client    플레이어 인덱스
 * @param amount    증가량 (기본값: 1)
 */
stock void PlayerData_AddLevel(int client, int amount = 1)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].level += amount;
}

/**
 * 경험치 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          현재 경험치
 */
stock int PlayerData_GetExp(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].exp;
}

/**
 * 경험치 설정
 *
 * @param client    플레이어 인덱스
 * @param exp       설정할 경험치
 */
stock void PlayerData_SetExp(int client, int exp)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].exp = exp;
}

/**
 * 경험치 추가
 *
 * @param client    플레이어 인덱스
 * @param exp       추가할 경험치
 */
stock void PlayerData_AddExp(int client, int exp)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].exp += exp;
}

// =============================================================================
// 포인트 Getter/Setter
// =============================================================================

/**
 * 스킬 포인트 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          현재 스킬 포인트
 */
stock int PlayerData_GetPoint(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].point;
}

/**
 * 스킬 포인트 설정
 *
 * @param client    플레이어 인덱스
 * @param point     설정할 스킬 포인트
 */
stock void PlayerData_SetPoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].point = point;
}

/**
 * 스킬 포인트 추가
 *
 * @param client    플레이어 인덱스
 * @param point     추가할 스킬 포인트
 */
stock void PlayerData_AddPoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].point += point;
}

/**
 * 추가 스킬 포인트 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          현재 추가 스킬 포인트
 */
stock int PlayerData_GetSkillPoint(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].skillpoint;
}

/**
 * 추가 스킬 포인트 설정
 *
 * @param client    플레이어 인덱스
 * @param point     설정할 추가 스킬 포인트
 */
stock void PlayerData_SetSkillPoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].skillpoint = point;
}

/**
 * 추가 스킬 포인트 추가
 *
 * @param client    플레이어 인덱스
 * @param point     추가할 스킬 포인트
 */
stock void PlayerData_AddSkillPoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].skillpoint += point;
}

// =============================================================================
// 기타 데이터 Getter/Setter
// =============================================================================

/**
 * 권한 레벨 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          권한 레벨
 */
stock int PlayerData_GetPermission(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].permission;
}

/**
 * 권한 레벨 설정
 *
 * @param client    플레이어 인덱스
 * @param perm      권한 레벨
 */
stock void PlayerData_SetPermission(int client, int perm)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].permission = perm;
}

/**
 * 누적 데미지 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          누적 데미지
 */
stock int PlayerData_GetDamage(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].damage;
}

/**
 * 누적 데미지 설정
 *
 * @param client    플레이어 인덱스
 * @param damage    누적 데미지
 */
stock void PlayerData_SetDamage(int client, int damage)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].damage = damage;
}

/**
 * 데미지 추가
 *
 * @param client    플레이어 인덱스
 * @param damage    추가할 데미지
 */
stock void PlayerData_AddDamage(int client, int damage)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].damage += damage;
}

/**
 * 부활 포인트 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          부활 포인트
 */
stock int PlayerData_GetRevivePoint(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].revivePoint;
}

/**
 * 부활 포인트 설정
 *
 * @param client    플레이어 인덱스
 * @param point     부활 포인트
 */
stock void PlayerData_SetRevivePoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].revivePoint = point;
}

/**
 * 부활 포인트 추가
 *
 * @param client    플레이어 인덱스
 * @param point     추가할 포인트
 */
stock void PlayerData_AddRevivePoint(int client, int point)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].revivePoint += point;
}

/**
 * 부활 횟수 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          부활 횟수
 */
stock int PlayerData_GetReviveCount(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].reviveCount;
}

/**
 * 부활 횟수 설정
 *
 * @param client    플레이어 인덱스
 * @param count     부활 횟수
 */
stock void PlayerData_SetReviveCount(int client, int count)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].reviveCount = count;
}

/**
 * 부활 횟수 증가
 *
 * @param client    플레이어 인덱스
 * @param amount    증가량 (기본값: 1)
 */
stock void PlayerData_AddReviveCount(int client, int amount = 1)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].reviveCount += amount;
}

/**
 * 시퀀스 번호 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          시퀀스 번호
 */
stock int PlayerData_GetSequenceNum(int client)
{
    if (!IsValidClient(client))
        return 0;
    return g_playerDataList[client].sequencenum;
}

/**
 * 시퀀스 번호 설정
 *
 * @param client    플레이어 인덱스
 * @param num       시퀀스 번호
 */
stock void PlayerData_SetSequenceNum(int client, int num)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].sequencenum = num;
}

// =============================================================================
// 로드 상태 Getter/Setter
// =============================================================================

/**
 * 데이터 로드 완료 여부 확인
 *
 * @param client    플레이어 인덱스
 * @return          로드 완료 여부
 */
stock bool PlayerData_IsLoaded(int client)
{
    if (!IsValidClient(client))
        return false;
    return g_playerDataList[client].isLoadComplete;
}

/**
 * 데이터 로드 완료 여부 설정
 *
 * @param client    플레이어 인덱스
 * @param loaded    로드 완료 여부
 */
stock void PlayerData_SetLoaded(int client, bool loaded)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].isLoadComplete = loaded;
}

/**
 * 로드 상태 가져오기
 *
 * @param client    플레이어 인덱스
 * @return          로드 상태 (LOAD_NONE, LOAD_PLAYERDATA, LOAD_CLASSATTRIBUTEDATA)
 */
stock int PlayerData_GetLoadStatus(int client)
{
    if (!IsValidClient(client))
        return LOAD_NONE;
    return g_playerDataList[client].loadStatus;
}

/**
 * 로드 상태 설정
 *
 * @param client    플레이어 인덱스
 * @param status    로드 상태
 */
stock void PlayerData_SetLoadStatus(int client, int status)
{
    if (!IsValidClient(client))
        return;
    g_playerDataList[client].loadStatus = status;
}

// =============================================================================
// 속성 데이터 접근 함수
// =============================================================================

/**
 * 클래스의 속성 개수 가져오기
 *
 * @param classIdx  클래스 인덱스
 * @return          속성 개수
 */
stock int PlayerData_GetAttributeCount(int classIdx)
{
    switch (classIdx)
    {
        case CLASS_SCOUT:       return SCOUT_ATTR_COUNT;
        case CLASS_MEDIC:       return MEDIC_ATTR_COUNT;
        case CLASS_SOLDIER:     return SOLDIER_ATTR_COUNT;
        case CLASS_PYRO:        return PYRO_ATTR_COUNT;
        case CLASS_SPY:         return SPY_ATTR_COUNT;
        case CLASS_DEMOMAN:     return DEMOMAN_ATTR_COUNT;
        case CLASS_SNIPER:      return SNIPER_ATTR_COUNT;
        case CLASS_ENGINEER:    return ENGINEER_ATTR_COUNT;
        case CLASS_HEAVY:       return HEAVY_ATTR_COUNT;
        case CLASS_HALE:        return HALE_ATTR_COUNT;
        case CLASS_SHARED:      return SHARED_ATTR_COUNT;
        case CLASS_WEAPON:      return WEAPON_ATTR_COUNT;
    }
    return 0;
}

/**
 * 속성 업그레이드 레벨 가져오기
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스 (CLASS_SCOUT ~ CLASS_WEAPON)
 * @param attrId    속성 ID (0 ~ 최대 속성 개수)
 * @return          업그레이드 레벨
 */
stock int PlayerData_GetAttributeUpgrade(int client, int classIdx, int attrId)
{
    if (!IsValidClient(client))
        return 0;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return 0;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return 0;

    return g_playerAttributes[client][classIdx][attrId].upgrade;
}

/**
 * 속성 업그레이드 레벨 설정
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param upgrade   업그레이드 레벨
 */
stock void PlayerData_SetAttributeUpgrade(int client, int classIdx, int attrId, int upgrade)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return;

    g_playerAttributes[client][classIdx][attrId].upgrade = upgrade;
}

/**
 * 속성 업그레이드 레벨 증가
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param amount    증가량 (기본값: 1)
 */
stock void PlayerData_AddAttributeUpgrade(int client, int classIdx, int attrId, int amount = 1)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return;

    g_playerAttributes[client][classIdx][attrId].upgrade += amount;
}

/**
 * 속성 UID 가져오기
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param buffer    저장할 버퍼
 * @param maxlen    버퍼 최대 길이
 */
stock void PlayerData_GetAttributeUID(int client, int classIdx, int attrId, char[] buffer, int maxlen)
{
    if (!IsValidClient(client))
    {
        buffer[0] = '\0';
        return;
    }

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
    {
        buffer[0] = '\0';
        return;
    }

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
    {
        buffer[0] = '\0';
        return;
    }

    strcopy(buffer, maxlen, g_playerAttributes[client][classIdx][attrId].uid);
}

/**
 * 속성 UID 설정
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param uid       고유 ID
 */
stock void PlayerData_SetAttributeUID(int client, int classIdx, int attrId, const char[] uid)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return;

    strcopy(g_playerAttributes[client][classIdx][attrId].uid,
            sizeof(g_playerAttributes[][][].uid), uid);
}

/**
 * 속성 데이터 구조체 전체 가져오기
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param data      저장할 AttributeData 구조체
 */
stock void PlayerData_GetAttributeData(int client, int classIdx, int attrId, AttributeData data)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return;

    data = g_playerAttributes[client][classIdx][attrId];
}

/**
 * 속성 데이터 구조체 전체 설정
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @param data      설정할 AttributeData 구조체
 */
stock void PlayerData_SetAttributeData(int client, int classIdx, int attrId, const AttributeData data)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    if (attrId < 0 || attrId >= MAX_ATTRIBUTES)
        return;

    g_playerAttributes[client][classIdx][attrId] = data;
}

/**
 * 클래스의 모든 속성 리셋 (업그레이드 레벨만 0으로)
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 */
stock void PlayerData_ResetClassAttributes(int client, int classIdx)
{
    if (!IsValidClient(client))
        return;

    if (classIdx < 0 || classIdx >= MAX_CLASSES)
        return;

    int attrCount = PlayerData_GetAttributeCount(classIdx);
    for (int i = 0; i < attrCount; i++)
    {
        g_playerAttributes[client][classIdx][i].upgrade = 0;
    }
}

/**
 * 모든 클래스의 속성 리셋
 *
 * @param client    플레이어 인덱스
 */
stock void PlayerData_ResetAllAttributes(int client)
{
    if (!IsValidClient(client))
        return;

    for (int classIdx = 0; classIdx < MAX_CLASSES; classIdx++)
    {
        PlayerData_ResetClassAttributes(client, classIdx);
    }
}

// =============================================================================
// 유틸리티 함수
// =============================================================================

/**
 * 유효한 클라이언트인지 확인
 *
 * @param client    플레이어 인덱스
 * @return          유효 여부
 */
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients);
}

/**
 * 플레이어 데이터 전체 구조체 포인터 가져오기 (읽기 전용)
 * 외부 모듈에서 직접 접근이 필요한 경우 사용
 *
 * @param client    플레이어 인덱스
 * @return          PlayerData 구조체
 */
stock PlayerData PlayerData_GetPlayerData(int client)
{
    return g_playerDataList[client];
}

/**
 * 속성 데이터 배열 포인터 가져오기 (읽기 전용)
 * 대량 작업이 필요한 경우 직접 접근
 *
 * @param client    플레이어 인덱스
 * @param classIdx  클래스 인덱스
 * @param attrId    속성 ID
 * @return          AttributeData 구조체
 */
stock AttributeData PlayerData_GetRawAttribute(int client, int classIdx, int attrId)
{
    return g_playerAttributes[client][classIdx][attrId];
}
