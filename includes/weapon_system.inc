/**
 * ============================================================================
 * TF2 Level System - Weapon Upgrade Module
 * ============================================================================
 *
 * 무기 강화 시스템을 관리하는 모듈
 * - 강화 성공/실패/초기화 확률 테이블 관리
 * - 강화 비용 및 결과 처리
 * - 확률 기반 강화 로직
 *
 * ============================================================================
 */

#if defined _weapon_system_included
 #endinput
#endif
#define _weapon_system_included

// ============================================================================
// 상수 정의
// ============================================================================

/**
 * 최대 무기 강화 레벨
 */
#define MAX_WEAPON_UPGRADE 15

/**
 * 무기 강화 결과 타입
 */
enum WeaponUpgradeResult
{
    WEAPON_UPGRADE_SUCCESS = 0,     // 강화 성공
    WEAPON_UPGRADE_FAIL = 1,        // 강화 실패 (레벨 유지)
    WEAPON_UPGRADE_RESET = 2        // 강화 초기화 (레벨 0으로)
}

// ============================================================================
// 강화 확률 및 비용 테이블
// ============================================================================

/**
 * 무기 강화 성공 확률 테이블 (레벨별)
 * 인덱스 0~14: 0→1강 ~ 14→15강
 */
static const float WEAPON_SUCCESS_TABLE[15] = {
    1.0, 0.85, 0.85, 0.70, 0.70, 0.70, 0.45, 0.45,
    0.30, 0.30, 0.30, 0.15, 0.15, 0.10, 0.05
};

/**
 * 무기 강화 실패 확률 테이블 (레벨별)
 * 실패 시 강화 레벨 유지
 */
static const float WEAPON_MISS_TABLE[15] = {
    0.0, 0.15, 0.15, 0.30, 0.30, 0.30, 0.30, 0.30,
    0.40, 0.40, 0.40, 0.50, 0.50, 0.50, 0.50
};

/**
 * 무기 강화 초기화 확률 테이블 (레벨별)
 * 초기화 시 강화 레벨 0으로 리셋
 */
static const float WEAPON_RESET_TABLE[15] = {
    0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.25, 0.25,
    0.30, 0.30, 0.30, 0.35, 0.35, 0.40, 0.45
};

/**
 * 무기 강화 비용 테이블 (레벨별)
 * 포인트 단위
 */
static const int WEAPON_COST_TABLE[15] = {
    200, 400, 600, 1200, 2000, 3500, 7000, 12000,
    20000, 35000, 50000, 100000, 150000, 250000, 400000
};

// ============================================================================
// 무기 강화 메인 로직
// ============================================================================

/**
 * 무기 강화 시도
 *
 * @param client        클라이언트 인덱스
 * @param currentLevel  현재 강화 레벨
 * @return              강화 결과 (WeaponUpgradeResult)
 */
WeaponUpgradeResult Weapon_TryUpgrade(int client, int currentLevel)
{
    // 레벨 범위 검증
    if (currentLevel < 0 || currentLevel >= MAX_WEAPON_UPGRADE)
    {
        LogError("[WeaponSystem] Invalid weapon level: %d (client: %d)", currentLevel, client);
        return WEAPON_UPGRADE_FAIL;
    }

    // 1~100 사이의 랜덤 값 생성
    int random = GetRandomInt(1, 100);

    // 확률 계산 (백분율로 변환)
    int successPercent = RoundToFloor(WEAPON_SUCCESS_TABLE[currentLevel] * 100.0);
    int missPercent = RoundToFloor(WEAPON_MISS_TABLE[currentLevel] * 100.0);
    int resetPercent = RoundToFloor(WEAPON_RESET_TABLE[currentLevel] * 100.0);

    // 디버그 로그
    PrintToServer("[WeaponSystem] Upgrade attempt - Level: %d, Random: %d, Success: %d%%, Miss: %d%%, Reset: %d%%",
                  currentLevel, random, successPercent, missPercent, resetPercent);

    // 강화 성공 판정
    if (random <= successPercent)
    {
        return WEAPON_UPGRADE_SUCCESS;
    }

    // 성공 범위를 제외한 랜덤 값 재계산
    random -= successPercent;

    // 강화 실패 판정 (레벨 유지)
    if (random <= missPercent)
    {
        return WEAPON_UPGRADE_FAIL;
    }

    // 강화 초기화 판정
    return WEAPON_UPGRADE_RESET;
}

/**
 * 무기 강화 비용 조회
 *
 * @param level     강화 레벨
 * @return          필요한 포인트
 */
int Weapon_GetUpgradeCost(int level)
{
    if (level < 0 || level >= MAX_WEAPON_UPGRADE)
    {
        return 0;
    }

    return WEAPON_COST_TABLE[level];
}

/**
 * 무기에 강화 효과 적용
 *
 * @param client    클라이언트 인덱스
 * @param weapon    무기 엔티티 인덱스
 * @param level     강화 레벨
 * @note 실제 속성 적용은 메인 플러그인에서 처리
 */
void Weapon_ApplyUpgrade(int client, int weapon, int level)
{
    if (!IsValidClient(client) || !IsValidEntity(weapon))
    {
        return;
    }

    // 무기 속성 적용은 메인 플러그인의
    // OnPlayerRegenerate 또는 무기 변경 이벤트에서 처리됨
    PrintToServer("[WeaponSystem] Applied upgrade - Client: %d, Weapon: %d, Level: %d",
                  client, weapon, level);
}

// ============================================================================
// 확률 조회 함수
// ============================================================================

/**
 * 강화 성공 확률 조회
 *
 * @param level     강화 레벨
 * @return          성공 확률 (0.0 ~ 1.0)
 */
float Weapon_GetSuccessChance(int level)
{
    if (level < 0 || level >= MAX_WEAPON_UPGRADE)
    {
        return 0.0;
    }

    return WEAPON_SUCCESS_TABLE[level];
}

/**
 * 강화 실패 확률 조회
 *
 * @param level     강화 레벨
 * @return          실패 확률 (0.0 ~ 1.0)
 */
float Weapon_GetMissChance(int level)
{
    if (level < 0 || level >= MAX_WEAPON_UPGRADE)
    {
        return 0.0;
    }

    return WEAPON_MISS_TABLE[level];
}

/**
 * 강화 초기화 확률 조회
 *
 * @param level     강화 레벨
 * @return          초기화 확률 (0.0 ~ 1.0)
 */
float Weapon_GetResetChance(int level)
{
    if (level < 0 || level >= MAX_WEAPON_UPGRADE)
    {
        return 0.0;
    }

    return WEAPON_RESET_TABLE[level];
}

// ============================================================================
// 유틸리티 함수
// ============================================================================

/**
 * 클라이언트가 강화 비용을 지불할 수 있는지 확인
 *
 * @param client    클라이언트 인덱스
 * @param level     강화 레벨
 * @param points    플레이어의 현재 포인트
 * @return          지불 가능 여부
 */
bool Weapon_CanAffordUpgrade(int client, int level, int points)
{
    if (!IsValidClient(client))
    {
        return false;
    }

    if (level < 0 || level >= MAX_WEAPON_UPGRADE)
    {
        return false;
    }

    int cost = Weapon_GetUpgradeCost(level);
    return points >= cost;
}

/**
 * 강화 결과를 클라이언트에게 표시
 *
 * @param client    클라이언트 인덱스
 * @param result    강화 결과
 * @param oldLevel  이전 레벨
 * @param newLevel  새 레벨
 */
void Weapon_ShowUpgradeResult(int client, WeaponUpgradeResult result, int oldLevel, int newLevel)
{
    if (!IsValidClient(client))
    {
        return;
    }

    char message[256];
    char centerText[256];

    switch (result)
    {
        case WEAPON_UPGRADE_SUCCESS:
        {
            Format(message, sizeof(message),
                   "%d번째 강화에 성공하였습니다.", newLevel);
            Format(centerText, sizeof(centerText),
                   "강화 성공! +%d → +%d", oldLevel, newLevel);

            PrintToChat(client, message);
            PrintCenterText(client, centerText);

            // 10강 이상 성공 시 전체 공지
            if (newLevel >= 10)
            {
                for (int i = 1; i <= MaxClients; i++)
                {
                    if (IsValidClient(i))
                    {
                        char name[MAX_NAME_LENGTH];
                        GetClientName(client, name, sizeof(name));
                        PrintToChat(i, "[알림] %s님이 무기 +%d 강화에 성공했습니다!", name, newLevel);
                        PrintCenterText(i, "[알림] %s님 무기 +%d 강화 성공!", name, newLevel);
                    }
                }
                EmitSoundToAll("misc/success1.mp3");
            }
            else
            {
                EmitSoundToClient(client, "misc/success1.mp3", _, _, SNDLEVEL_RAIDSIREN);
            }
        }

        case WEAPON_UPGRADE_FAIL:
        {
            Format(message, sizeof(message),
                   "%d번째 강화에 실패했습니다.", oldLevel + 1);
            Format(centerText, sizeof(centerText),
                   "강화 실패... +%d 유지", oldLevel);

            PrintToChat(client, message);
            PrintCenterText(client, centerText);
            EmitSoundToClient(client, "misc/failed1.mp3", _, _, SNDLEVEL_RAIDSIREN);
        }

        case WEAPON_UPGRADE_RESET:
        {
            Format(message, sizeof(message),
                   "%d번째 강화가 파괴되었습니다!", oldLevel + 1);
            Format(centerText, sizeof(centerText),
                   "강화 파괴! +%d → +0", oldLevel);

            PrintToChat(client, message);
            PrintCenterText(client, centerText);

            // 10강 이상 파괴 시 전체 공지
            if (oldLevel >= 10)
            {
                for (int i = 1; i <= MaxClients; i++)
                {
                    if (IsValidClient(i))
                    {
                        char name[MAX_NAME_LENGTH];
                        GetClientName(client, name, sizeof(name));
                        PrintToChat(i, "[알림] %s님의 무기 +%d가 파괴되었습니다...", name, oldLevel);
                        PrintCenterText(i, "[알림] %s님 무기 +%d 파괴...", name, oldLevel);
                    }
                }
                EmitSoundToAll("misc/failed1.mp3");
            }
            else
            {
                EmitSoundToClient(client, "misc/failed1.mp3", _, _, SNDLEVEL_RAIDSIREN);
            }
        }
    }
}

/**
 * 강화 가능 여부 확인
 *
 * @param level     현재 강화 레벨
 * @return          강화 가능 여부
 */
bool Weapon_CanUpgrade(int level)
{
    return (level >= 0 && level < MAX_WEAPON_UPGRADE);
}

/**
 * 강화 레벨 유효성 검사
 *
 * @param level     강화 레벨
 * @return          유효한 레벨인지 여부
 */
bool Weapon_IsValidLevel(int level)
{
    return (level >= 0 && level <= MAX_WEAPON_UPGRADE);
}

/**
 * 클라이언트 유효성 검사
 *
 * @param client    클라이언트 인덱스
 * @return          유효한 클라이언트인지 여부
 */
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

// ============================================================================
// 강화 통계 함수
// ============================================================================

/**
 * 특정 레벨까지 강화하는데 필요한 총 비용 계산
 *
 * @param targetLevel   목표 레벨
 * @return              총 필요 포인트
 */
int Weapon_GetTotalCost(int targetLevel)
{
    if (targetLevel < 0 || targetLevel > MAX_WEAPON_UPGRADE)
    {
        return 0;
    }

    int totalCost = 0;
    for (int i = 0; i < targetLevel; i++)
    {
        totalCost += WEAPON_COST_TABLE[i];
    }

    return totalCost;
}

/**
 * 강화 정보를 문자열로 포맷팅
 *
 * @param buffer        출력 버퍼
 * @param maxlen        버퍼 크기
 * @param level         현재 레벨
 * @param points        현재 포인트
 */
void Weapon_FormatUpgradeInfo(char[] buffer, int maxlen, int level, int points)
{
    if (level >= MAX_WEAPON_UPGRADE)
    {
        Format(buffer, maxlen, "무기 강화가 최대 레벨에 도달했습니다! (+%d)", level);
        return;
    }

    int cost = Weapon_GetUpgradeCost(level);
    float successChance = Weapon_GetSuccessChance(level) * 100.0;
    float missChance = Weapon_GetMissChance(level) * 100.0;
    float resetChance = Weapon_GetResetChance(level) * 100.0;

    Format(buffer, maxlen,
           "현재 강화: +%d → +%d\n비용: %d 포인트 (보유: %d)\n성공: %.0f%% | 실패: %.0f%% | 파괴: %.0f%%",
           level, level + 1, cost, points, successChance, missChance, resetChance);
}

// ============================================================================
// 모듈 정보
// ============================================================================

/**
 * 무기 시스템 모듈 버전
 */
#define WEAPON_SYSTEM_VERSION "1.0.0"

/**
 * 모듈 버전 정보 출력
 */
void Weapon_PrintVersion()
{
    PrintToServer("[WeaponSystem] Module Version: %s", WEAPON_SYSTEM_VERSION);
    PrintToServer("[WeaponSystem] Max Upgrade Level: %d", MAX_WEAPON_UPGRADE);
}
