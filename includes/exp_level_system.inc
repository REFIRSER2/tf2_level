/**
 * =============================================================================
 * TF2 Level System - 경험치/레벨업 시스템 모듈
 * =============================================================================
 *
 * 설명: 플레이어의 경험치 획득, 레벨업 처리, 보상 지급 등을 관리하는 핵심 모듈
 *
 * 주요 기능:
 * - 경험치 획득 및 레벨업 처리
 * - 데미지 누적 추적 및 보상
 * - 타이머 기반 보상
 * - 레벨업 이펙트 및 사운드
 */

#if defined _exp_level_system_included
  #endinput
#endif
#define _exp_level_system_included

// =============================================================================
// 경험치 테이블 (레벨당 필요 경험치)
// =============================================================================

const int EXP_TABLE_SIZE = 80;

// 경험치 테이블 (80 레벨)
const int EXP_TABLE[EXP_TABLE_SIZE] = {
    25, 60, 110, 175, 250, 350, 475, 625, 800, 1000,
    1225, 1475, 1750, 2050, 2375, 2725, 3100, 3500, 3925, 4375,
    4850, 5350, 5875, 6425, 7000, 7600, 8225, 8875, 9550, 10250,
    10975, 11725, 12500, 13300, 14125, 14975, 15850, 16750, 17675, 18625,
    19600, 20600, 21625, 22675, 23750, 24850, 25975, 27125, 28300, 29500,
    30750, 32050, 33400, 34800, 36250, 37750, 39300, 40900, 42550, 44250,
    46000, 47800, 49650, 51550, 53500, 55500, 57550, 59650, 61800, 64000,
    66250, 68550, 70900, 73300, 75750, 78250, 80800, 83400, 86050, 88750
};

// =============================================================================
// 보상 상수
// =============================================================================

// 타이머 보상 (10분마다)
const float REWARD_TIMER_INTERVAL = 600.0;
const int REWARD_POINT_TIMER = 100;
const int REWARD_EXP_TIMER = 50;

// 데미지 누적 보상 (2000 데미지마다)
const int REWARD_DAMAGE_THRESHOLD = 2000;
const int REWARD_POINT_DAMAGE = 40;
const int REWARD_EXP_DAMAGE = 20;

// 처치 보상
const int REWARD_POINT_KILL = 20;
const int REWARD_EXP_KILL = 20;

// 레벨업 보상
const int REWARD_SKILLPOINT_LEVELUP = 3;

// =============================================================================
// 레벨/경험치 관리 함수
// =============================================================================

/**
 * 플레이어에게 경험치를 추가하고 레벨업을 처리합니다.
 *
 * @param client    클라이언트 인덱스
 * @param exp       추가할 경험치
 * @noreturn
 */
stock void ExpLevel_AddExp(int client, int exp)
{
    if (!IsValidClient(client))
        return;

    playerDataList[client].exp += exp;

    // 레벨업 체크
    if (playerDataList[client].level < (EXP_TABLE_SIZE - 1) &&
        playerDataList[client].exp >= EXP_TABLE[playerDataList[client].level])
    {
        // 남은 경험치 계산
        int delta = playerDataList[client].exp - EXP_TABLE[playerDataList[client].level];

        // 현재 레벨 경험치 소모
        playerDataList[client].exp -= EXP_TABLE[playerDataList[client].level];

        // 레벨업 처리
        ExpLevel_ProcessLevelUp(client);

        // 남은 경험치로 재귀 호출 (연속 레벨업 처리)
        if (delta > 0)
        {
            ExpLevel_AddExp(client, delta);
        }
    }
}

/**
 * 플레이어의 레벨업을 처리합니다.
 *
 * @param client    클라이언트 인덱스
 * @noreturn
 */
stock void ExpLevel_ProcessLevelUp(int client)
{
    if (!IsValidClient(client))
        return;

    // 레벨 증가
    playerDataList[client].level++;

    // 스킬포인트 보상
    playerDataList[client].skillpoint += REWARD_SKILLPOINT_LEVELUP;

    // 닉네임 업데이트
    ExpLevel_UpdateNickname(client);

    // 이펙트 및 사운드
    ExpLevel_ShowLevelUpEffect(client);
    ExpLevel_PlayLevelUpSound(client);

    // 채팅 메시지
    CPrintToChat(client, "{green}[레벨업]{default} 축하합니다! 레벨이 올라 {orange}%d{default} 레벨이 되었습니다!",
                 playerDataList[client].level);
}

/**
 * 플레이어에게 포인트를 추가합니다.
 *
 * @param client    클라이언트 인덱스
 * @param points    추가할 포인트
 * @noreturn
 */
stock void ExpLevel_AddPoints(int client, int points)
{
    if (!IsValidClient(client))
        return;

    playerDataList[client].point += points;
}

/**
 * 특정 레벨에 필요한 경험치를 반환합니다.
 *
 * @param level     레벨 (0~79)
 * @return          필요 경험치
 */
stock int ExpLevel_GetExpForLevel(int level)
{
    if (level < 0 || level >= EXP_TABLE_SIZE)
        return 0;

    return EXP_TABLE[level];
}

/**
 * 최대 레벨을 반환합니다.
 *
 * @return          최대 레벨
 */
stock int ExpLevel_GetMaxLevel()
{
    return EXP_TABLE_SIZE;
}

// =============================================================================
// 데미지 추적 및 보상
// =============================================================================

/**
 * 플레이어의 데미지를 추적하고 임계값 도달 시 보상을 지급합니다.
 *
 * @param client    클라이언트 인덱스
 * @param damage    가한 데미지
 * @noreturn
 */
stock void ExpLevel_TrackDamage(int client, int damage)
{
    if (!IsValidClient(client))
        return;

    playerDataList[client].damage += damage;

    // 데미지 임계값 도달 체크
    if (playerDataList[client].damage >= REWARD_DAMAGE_THRESHOLD)
    {
        // 달성 횟수 계산 (여러 번 달성 가능)
        int multiple = playerDataList[client].damage / REWARD_DAMAGE_THRESHOLD;

        // 보상 지급
        ExpLevel_AddExp(client, REWARD_EXP_DAMAGE * multiple);
        ExpLevel_AddPoints(client, REWARD_POINT_DAMAGE * multiple);

        // 채팅 메시지
        CPrintToChat(client, "{olive}[EXP&Point]{default} 데미지 누적 달성! {rare}[%d 경험치]{default} {unique}[%d 포인트]{default} 획득!",
                     REWARD_EXP_DAMAGE * multiple, REWARD_POINT_DAMAGE * multiple);

        // 사용한 데미지 차감
        playerDataList[client].damage -= multiple * REWARD_DAMAGE_THRESHOLD;
    }
}

// =============================================================================
// 닉네임 업데이트
// =============================================================================

/**
 * 플레이어의 닉네임을 현재 레벨로 업데이트합니다.
 *
 * @param client    클라이언트 인덱스
 * @noreturn
 */
stock void ExpLevel_UpdateNickname(int client)
{
    if (!IsValidClient(client))
        return;

    char prefix[12];
    char prefixName[255];

    Format(prefix, sizeof(prefix), "[Lv%d]", playerDataList[client].level);
    Format(prefixName, sizeof(prefixName), "%s%s", prefix, playerDataList[client].basenick);

    SetClientInfo(client, "name", prefixName);
}

// =============================================================================
// 레벨업 이펙트
// =============================================================================

/**
 * 레벨업 시각 효과를 표시합니다.
 *
 * @param client    클라이언트 인덱스
 * @noreturn
 */
stock void ExpLevel_ShowLevelUpEffect(int client)
{
    if (!IsValidClient(client))
        return;

    if (!IsClientInGame(client) || !IsPlayerAlive(client))
        return;

    // 파티클 효과 표시
    AttachParticle(client, "bl_killtaunt", "head", 0.0, 0.5);
    AttachParticle(client, "achieved", "head", 0.0, 0.5);
}

/**
 * 레벨업 사운드를 재생합니다.
 *
 * @param client    클라이언트 인덱스
 * @noreturn
 */
stock void ExpLevel_PlayLevelUpSound(int client)
{
    if (!IsValidClient(client))
        return;

    if (!IsClientInGame(client))
        return;

    EmitSoundToClient(client, "misc/achievement_earned.wav", _, _, SNDLEVEL_RAIDSIREN);
}

// =============================================================================
// 유틸리티 함수
// =============================================================================

/**
 * 클라이언트가 유효한지 확인합니다.
 *
 * @param client    클라이언트 인덱스
 * @return          유효하면 true
 */
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
