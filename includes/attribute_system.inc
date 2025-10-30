/**
 * =============================================================================
 * TF2 Level System - Attribute System Module
 * 속성 시스템 모듈
 *
 * 원본 levelup.sp의 140+ 중복 코드 블록을 일반화된 함수로 최적화
 * 12개 개별 AttributeTable 배열을 2차원 배열로 통합하여 메모리 효율 개선
 * =============================================================================
 */

#if defined _tf2level_attribute_system_included
    #endinput
#endif
#define _tf2level_attribute_system_included

// =============================================================================
// 상수 정의 (공통 상수는 메인 파일에 정의)
// =============================================================================
// CLASS_SCOUT, CLASS_MEDIC 등의 클래스 상수는 메인 파일에 정의
// ADDITIVE_PERCENT 등의 모드 상수도 메인 파일에 정의
// MAX_CLASSES, MAX_ATTRIBUTES도 메인 파일에 정의

// =============================================================================
// 데이터 구조체
// =============================================================================

/**
 * 속성 테이블 구조체
 * 각 클래스의 스킬/속성 정의를 저장
 */
enum struct AttributeTable
{
    char uid[64];           // TF2 속성 고유 ID
    char title[80];         // 메뉴에 표시될 제목
    int class;              // 클래스 ID
    int max;                // 최대 업그레이드 레벨
    int point;              // 업그레이드당 필요 포인트
    float value;            // 업그레이드당 증가값
    float defaultValue;     // 기본값
    int additiveMode;       // 적용 모드
    bool isDisableDrawValue; // 값 표시 비활성화 (ON/OFF 스킬용)
}

// =============================================================================
// 전역 변수
// =============================================================================

// 속성 테이블 (2차원 배열로 통합)
AttributeTable g_attributeTable[MAX_CLASSES][MAX_ATTRIBUTES];

// 클래스별 속성 개수
int g_attributeCount[MAX_CLASSES] = {
    13, // Scout
    14, // Medic
    13, // Soldier
    13, // Pyro
    16, // Spy
    16, // Demoman
    15, // Sniper
    17, // Engineer
    14, // Heavy
    3,  // Hale
    2,  // Shared
    1   // Weapon
};

// ConVar
ConVar g_redEnableStatApply;
ConVar g_blueEnableStatApply;

// =============================================================================
// 초기화 함수
// =============================================================================

/**
 * 속성 시스템 초기화
 * OnPluginStart()에서 호출
 */
stock void Attribute_Initialize()
{
    // ConVar 등록
    g_redEnableStatApply = CreateConVar("levelup_red_enable_stat", "1", "레드팀 속성 적용 활성화");
    g_blueEnableStatApply = CreateConVar("levelup_blue_enable_stat", "0", "블루팀 속성 적용 활성화");
    
    // 속성 테이블 생성
    CreateAttributeTable();
}

/**
 * 속성 계산 함수
 * 업그레이드 레벨에 따라 최종 속성값 계산
 *
 * @param attr          속성 테이블
 * @param upgrade       업그레이드 레벨
 * @return              계산된 속성값
 */
stock float Attribute_Calculate(AttributeTable attr, int upgrade)
{
    if (upgrade <= 0)
        return attr.defaultValue;
    
    float result = 0.0;
    
    switch (attr.additiveMode)
    {
        case ADDITIVE_NUMBER:
        {
            // 고정값 더하기: defaultValue + (upgrade * value)
            result = attr.defaultValue + (float(upgrade) * attr.value);
        }
        case ADDITIVE_PERCENT:
        {
            // 퍼센트 더하기: (defaultValue * 0.01) + (upgrade * value * 0.01)
            result = (attr.defaultValue * 0.01) + (float(upgrade) * attr.value * 0.01);
        }
        case MINUS_NUMBER:
        {
            // 고정값 빼기: defaultValue - (upgrade * value)
            result = attr.defaultValue - (float(upgrade) * attr.value);
        }
        case MINUS_PERCENT:
        {
            // 퍼센트 빼기: (defaultValue * 0.01) - (upgrade * value * 0.01)
            result = (attr.defaultValue * 0.01) - (float(upgrade) * attr.value * 0.01);
        }
        default:
        {
            result = attr.defaultValue;
        }
    }
    
    return result;
}

/**
 * 플레이어에게 속성 적용
 * OnPlayerSpawn 이벤트에서 호출
 *
 * @param client        플레이어 인덱스
 * @param tfClass       TF2 클래스 (TFClass_Scout, TFClass_Soldier 등)
 */
stock void Attribute_ApplyToPlayer(int client, TFClassType tfClass)
{
    if (!IsValidClient(client))
        return;
    
    // 팀 확인
    int team = GetClientTeam(client);
    if (team == 2) // 레드팀
    {
        if (!g_redEnableStatApply.BoolValue)
        {
            TF2Attrib_RemoveAll(client);
            return;
        }
    }
    else if (team == 3) // 블루팀
    {
        if (!g_blueEnableStatApply.BoolValue)
        {
            TF2Attrib_RemoveAll(client);
            return;
        }
    }
    
    // 기존 속성 제거
    TF2Attrib_RemoveAll(client);
    
    // TFClassType을 CLASS_ 인덱스로 변환
    int classIdx = TFClassToIndex(tfClass);
    if (classIdx < 0)
        return;
    
    // 해당 클래스의 모든 속성 적용
    int attrCount = g_attributeCount[classIdx];
    for (int i = 0; i < attrCount; i++)
    {
        // 플레이어의 업그레이드 레벨 가져오기 (외부 player_data.inc에서)
        int upgrade = PlayerData_GetAttributeUpgrade(client, classIdx, i);
        
        if (upgrade <= 0)
            continue;
        
        // 속성값 계산
        float result = Attribute_Calculate(g_attributeTable[classIdx][i], upgrade);
        
        // TF2 속성 적용
        TF2Attrib_SetByName(client, g_attributeTable[classIdx][i].uid, result);
    }
    
    // 공용 속성은 0.5초 후 적용 (타이머 사용)
    CreateTimer(0.5, Timer_ApplySharedAttribute, client, TIMER_FLAG_NO_MAPCHANGE);
}

/**
 * 공용 속성 적용 타이머
 */
public Action Timer_ApplySharedAttribute(Handle timer, any client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    // SHARED 클래스 속성 적용
    int sharedCount = g_attributeCount[CLASS_SHARED];
    for (int i = 0; i < sharedCount; i++)
    {
        int upgrade = PlayerData_GetAttributeUpgrade(client, CLASS_SHARED, i);
        if (upgrade <= 0)
            continue;
        
        float result = Attribute_Calculate(g_attributeTable[CLASS_SHARED][i], upgrade);
        TF2Attrib_SetByName(client, g_attributeTable[CLASS_SHARED][i].uid, result);
    }
    
    // 무기 속성 적용
    Attribute_ApplyToWeapons(client);
    
    return Plugin_Stop;
}

/**
 * 플레이어의 모든 무기에 속성 적용
 */
stock void Attribute_ApplyToWeapons(int client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
        return;
    
    int weaponCount = g_attributeCount[CLASS_WEAPON];
    
    // 모든 무기 슬롯 순회
    for (int slot = 0; slot < 6; slot++)
    {
        int weapon = GetPlayerWeaponSlot(client, slot);
        if (!IsValidEntity(weapon))
            continue;
        
        // 무기에 속성 적용
        for (int i = 0; i < weaponCount; i++)
        {
            int upgrade = PlayerData_GetAttributeUpgrade(client, CLASS_WEAPON, i);
            if (upgrade <= 0)
                continue;
            
            float result = Attribute_Calculate(g_attributeTable[CLASS_WEAPON][i], upgrade);
            TF2Attrib_SetByName(weapon, g_attributeTable[CLASS_WEAPON][i].uid, result);
        }
    }
}

/**
 * TFClassType을 CLASS_ 인덱스로 변환
 */
stock int TFClassToIndex(TFClassType tfClass)
{
    switch (tfClass)
    {
        case TFClass_Scout:     return CLASS_SCOUT;
        case TFClass_Medic:     return CLASS_MEDIC;
        case TFClass_Soldier:   return CLASS_SOLDIER;
        case TFClass_Pyro:      return CLASS_PYRO;
        case TFClass_Spy:       return CLASS_SPY;
        case TFClass_DemoMan:   return CLASS_DEMOMAN;
        case TFClass_Sniper:    return CLASS_SNIPER;
        case TFClass_Engineer:  return CLASS_ENGINEER;
        case TFClass_Heavy:     return CLASS_HEAVY;
        default:                return -1;
    }
}

/**
 * 속성 테이블 접근 함수
 */
stock AttributeTable Attribute_GetTable(int classIdx, int attrIdx)
{
    return g_attributeTable[classIdx][attrIdx];
}

stock int Attribute_GetCount(int classIdx)
{
    return g_attributeCount[classIdx];
}

/**
 * 유효한 클라이언트 체크
 */
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}

// =============================================================================
// 속성 테이블 생성
// 원본 levelup.sp의 CreateAttributeTable() 함수를 그대로 이식
// =============================================================================

void CreateAttributeTable()
{
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

