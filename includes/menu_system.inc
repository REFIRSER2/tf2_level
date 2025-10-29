/**
 * =============================================================================
 * TF2 Level System - Menu/UI Module
 * =============================================================================
 *
 * 메뉴 시스템 및 UI 표시를 담당하는 모듈
 * - 메인 메뉴, 플레이어 정보, 클래스 스탯 메뉴
 * - 부활, 스킬 초기화, 무기 강화 메뉴
 * - HUD 표시 (레드팀만)
 */

#if defined _menu_system_included
  #endinput
#endif
#define _menu_system_included

// ============================================================================
// 전역 변수
// ============================================================================

// 메뉴 페이지 네비게이션용
int g_prevOpenMenuPage = -1;

// ============================================================================
// HUD 표시 함수
// ============================================================================

/**
 * HUD 텍스트를 주기적으로 표시 (레드팀만)
 * 타이머로 1초마다 호출됨
 */
public Action Menu_ShowHUD(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }

        // 블루팀(3번)은 HUD 표시 안함
        int team = GetClientTeam(client);
        if (team == 3)  // 블루팀
        {
            continue;
        }

        // 레드팀(2번)만 HUD 표시
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

// ============================================================================
// 메인 메뉴
// ============================================================================

/**
 * 메인 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowMain(int client)
{
    Menu menu = CreateMenu(MenuHandler_Main);
    menu.SetTitle("<< 수상한 거래 서버에 오신걸 환영합니다 >>");

    menu.AddItem("info",        "내정보");
    menu.AddItem("classStat",   "클래스 스탯");
    menu.AddItem("shop",        "상점");
    menu.AddItem("weaponStat",  "무기 강화");
    menu.AddItem("revive",      "부활권");
    menu.AddItem("inventory",   "인벤토리");
    menu.AddItem("skillReset",  "스킬초기화");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * 메인 메뉴 핸들러
 */
public int MenuHandler_Main(Menu menu, MenuAction action, int client, int item)
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
        Menu_ShowPlayerInfo(client);
    }
    else if (StrEqual(info, "classStat"))
    {
        Menu_ShowClassStat(client);
    }
    else if (StrEqual(info, "revive"))
    {
        Menu_ShowRevive(client);
    }
    else if (StrEqual(info, "skillReset"))
    {
        Menu_ShowSkillReset(client);
    }
    else if (StrEqual(info, "weaponStat"))
    {
        Menu_ShowWeaponUpgrade(client);
    }
    else
    {
        PrintToChat(client, "아직 구현되지 않은 메뉴입니다: %s", info);
    }

    return 0;
}

// ============================================================================
// 플레이어 정보 메뉴
// ============================================================================

/**
 * 플레이어 정보 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowPlayerInfo(int client)
{
    Menu menu = CreateMenu(MenuHandler_PlayerInfo);

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

/**
 * 플레이어 정보 메뉴 핸들러
 */
public int MenuHandler_PlayerInfo(Menu menu, MenuAction action, int client, int item)
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
            Menu_ShowMain(client);
        }
    }

    return 0;
}

// ============================================================================
// 클래스 스탯 메뉴
// ============================================================================

/**
 * 클래스 선택 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowClassStat(int client)
{
    Menu menu = CreateMenu(MenuHandler_ClassStat);
    menu.SetTitle("클래스 스탯");

    menu.AddItem("scout",       "스카웃");
    menu.AddItem("soldier",     "솔져");
    menu.AddItem("pyro",        "파이로");
    menu.AddItem("demoman",     "데모맨");
    menu.AddItem("heavy",       "헤비");
    menu.AddItem("engineer",    "엔지니어");
    menu.AddItem("medic",       "메딕");
    menu.AddItem("sniper",      "스나이퍼");
    menu.AddItem("spy",         "스파이");
    menu.AddItem("hale",        "헤일(사용불가)");
    menu.AddItem("shared",      "공용");

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * 클래스 선택 메뉴 핸들러
 */
public int MenuHandler_ClassStat(Menu menu, MenuAction action, int client, int item)
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
            Menu_ShowMain(client);
        }
        else
        {
            // 선택한 클래스의 상세 스탯 메뉴 표시
            Menu_ShowClassStatDetail(client, info);
        }
    }

    return 0;
}

/**
 * 클래스 상세 스탯 메뉴를 표시
 * @param client    클라이언트 인덱스
 * @param classID   클래스 ID (예: "scout", "soldier", etc.)
 */
void Menu_ShowClassStatDetail(int client, const char[] classID)
{
    Menu menu = CreateMenu(MenuHandler_ClassStatDetail);

    // 클래스별로 메뉴 구성
    if (StrEqual(classID, "scout"))
    {
        menu.SetTitle("스카웃");

        for (int i = 0; i < sizeof(scoutAttributeTable); i++)
        {
            if (!StrEqual(scoutAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", scoutAttributeTable[i].title);

                if (scoutAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, scoutAttributeTable[i].point,
                           playerDataList[client].scoutAttributeData[i].upgrade, scoutAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, scoutAttributeTable[i].value, scoutAttributeTable[i].point,
                           playerDataList[client].scoutAttributeData[i].upgrade, scoutAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(medicAttributeTable); i++)
        {
            if (!StrEqual(medicAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", medicAttributeTable[i].title);

                if (medicAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, medicAttributeTable[i].point,
                           playerDataList[client].medicAttributeData[i].upgrade, medicAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, medicAttributeTable[i].value, medicAttributeTable[i].point,
                           playerDataList[client].medicAttributeData[i].upgrade, medicAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(soldierAttributeTable); i++)
        {
            if (!StrEqual(soldierAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", soldierAttributeTable[i].title);

                if (soldierAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, soldierAttributeTable[i].point,
                           playerDataList[client].soldierAttributeData[i].upgrade, soldierAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, soldierAttributeTable[i].value, soldierAttributeTable[i].point,
                           playerDataList[client].soldierAttributeData[i].upgrade, soldierAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(pyroAttributeTable); i++)
        {
            if (!StrEqual(pyroAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", pyroAttributeTable[i].title);

                if (pyroAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, pyroAttributeTable[i].point,
                           playerDataList[client].pyroAttributeData[i].upgrade, pyroAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, pyroAttributeTable[i].value, pyroAttributeTable[i].point,
                           playerDataList[client].pyroAttributeData[i].upgrade, pyroAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(spyAttributeTable); i++)
        {
            if (!StrEqual(spyAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", spyAttributeTable[i].title);

                if (spyAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, spyAttributeTable[i].point,
                           playerDataList[client].spyAttributeData[i].upgrade, spyAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, spyAttributeTable[i].value, spyAttributeTable[i].point,
                           playerDataList[client].spyAttributeData[i].upgrade, spyAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(demomanAttributeTable); i++)
        {
            if (!StrEqual(demomanAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", demomanAttributeTable[i].title);

                if (demomanAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, demomanAttributeTable[i].point,
                           playerDataList[client].demomanAttributeData[i].upgrade, demomanAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, demomanAttributeTable[i].value, demomanAttributeTable[i].point,
                           playerDataList[client].demomanAttributeData[i].upgrade, demomanAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(sniperAttributeTable); i++)
        {
            if (!StrEqual(sniperAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", sniperAttributeTable[i].title);

                if (sniperAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, sniperAttributeTable[i].point,
                           playerDataList[client].sniperAttributeData[i].upgrade, sniperAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, sniperAttributeTable[i].value, sniperAttributeTable[i].point,
                           playerDataList[client].sniperAttributeData[i].upgrade, sniperAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(engineerAttributeTable); i++)
        {
            if (!StrEqual(engineerAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", engineerAttributeTable[i].title);

                if (engineerAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, engineerAttributeTable[i].point,
                           playerDataList[client].engineerAttributeData[i].upgrade, engineerAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, engineerAttributeTable[i].value, engineerAttributeTable[i].point,
                           playerDataList[client].engineerAttributeData[i].upgrade, engineerAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(heavyAttributeTable); i++)
        {
            if (!StrEqual(heavyAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", heavyAttributeTable[i].title);

                if (heavyAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, heavyAttributeTable[i].point,
                           playerDataList[client].heavyAttributeData[i].upgrade, heavyAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, heavyAttributeTable[i].value, heavyAttributeTable[i].point,
                           playerDataList[client].heavyAttributeData[i].upgrade, heavyAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(haleAttributeTable); i++)
        {
            if (!StrEqual(haleAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", haleAttributeTable[i].title);

                if (haleAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, haleAttributeTable[i].point,
                           playerDataList[client].haleAttributeData[i].upgrade, haleAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, haleAttributeTable[i].value, haleAttributeTable[i].point,
                           playerDataList[client].haleAttributeData[i].upgrade, haleAttributeTable[i].max);
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

        for (int i = 0; i < sizeof(sharedAttributeTable); i++)
        {
            if (!StrEqual(sharedAttributeTable[i].uid, ""))
            {
                char buffer[128];
                Format(buffer, sizeof(buffer), "%s", sharedAttributeTable[i].title);

                if (sharedAttributeTable[i].isDisableDrawValue)
                {
                    Format(buffer, sizeof(buffer), buffer, sharedAttributeTable[i].point,
                           playerDataList[client].sharedAttributeData[i].upgrade, sharedAttributeTable[i].max);
                }
                else
                {
                    Format(buffer, sizeof(buffer), buffer, sharedAttributeTable[i].value, sharedAttributeTable[i].point,
                           playerDataList[client].sharedAttributeData[i].upgrade, sharedAttributeTable[i].max);
                }

                char key[64];
                Format(key, sizeof(key), "shared_%s", sharedAttributeTable[i].uid);
                menu.AddItem(key, buffer);
            }
        }
    }

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;

    // 메뉴 페이지 복원
    if (g_prevOpenMenuPage == -1)
    {
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        DisplayMenuAtItem(menu, client, g_prevOpenMenuPage, MENU_TIME_FOREVER);
    }

    g_prevOpenMenuPage = -1;
}

/**
 * 클래스 상세 스탯 메뉴 핸들러
 */
public int MenuHandler_ClassStatDetail(Menu menu, MenuAction action, int client, int item)
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
            Menu_ShowClassStat(client);
        }
        else if (StrContains(info, "scout") != -1)
        {
            if (scoutAttributeTable[item].max > playerDataList[client].scoutAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= scoutAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= scoutAttributeTable[item].point;
                    playerDataList[client].scoutAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Scout[%d] upgrade=%d",
                                 client, item, playerDataList[client].scoutAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "scout");
        }
        else if (StrContains(info, "medic") != -1)
        {
            if (medicAttributeTable[item].max > playerDataList[client].medicAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= medicAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= medicAttributeTable[item].point;
                    playerDataList[client].medicAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Medic[%d] upgrade=%d",
                                 client, item, playerDataList[client].medicAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "medic");
        }
        else if (StrContains(info, "soldier") != -1)
        {
            if (soldierAttributeTable[item].max > playerDataList[client].soldierAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= soldierAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= soldierAttributeTable[item].point;
                    playerDataList[client].soldierAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Soldier[%d] upgrade=%d",
                                 client, item, playerDataList[client].soldierAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "soldier");
        }
        else if (StrContains(info, "pyro") != -1)
        {
            if (pyroAttributeTable[item].max > playerDataList[client].pyroAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= pyroAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= pyroAttributeTable[item].point;
                    playerDataList[client].pyroAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Pyro[%d] upgrade=%d",
                                 client, item, playerDataList[client].pyroAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "pyro");
        }
        else if (StrContains(info, "spy") != -1)
        {
            if (spyAttributeTable[item].max > playerDataList[client].spyAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= spyAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= spyAttributeTable[item].point;
                    playerDataList[client].spyAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Spy[%d] upgrade=%d",
                                 client, item, playerDataList[client].spyAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "spy");
        }
        else if (StrContains(info, "demoman") != -1)
        {
            if (demomanAttributeTable[item].max > playerDataList[client].demomanAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= demomanAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= demomanAttributeTable[item].point;
                    playerDataList[client].demomanAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Demoman[%d] upgrade=%d",
                                 client, item, playerDataList[client].demomanAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "demoman");
        }
        else if (StrContains(info, "sniper") != -1)
        {
            if (sniperAttributeTable[item].max > playerDataList[client].sniperAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= sniperAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= sniperAttributeTable[item].point;
                    playerDataList[client].sniperAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Sniper[%d] upgrade=%d",
                                 client, item, playerDataList[client].sniperAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "sniper");
        }
        else if (StrContains(info, "engineer") != -1)
        {
            if (engineerAttributeTable[item].max > playerDataList[client].engineerAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= engineerAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= engineerAttributeTable[item].point;
                    playerDataList[client].engineerAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Engineer[%d] upgrade=%d",
                                 client, item, playerDataList[client].engineerAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "engineer");
        }
        else if (StrContains(info, "heavy") != -1)
        {
            if (heavyAttributeTable[item].max > playerDataList[client].heavyAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= heavyAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= heavyAttributeTable[item].point;
                    playerDataList[client].heavyAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Heavy[%d] upgrade=%d",
                                 client, item, playerDataList[client].heavyAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "heavy");
        }
        else if (StrContains(info, "hale") != -1)
        {
            if (haleAttributeTable[item].max > playerDataList[client].haleAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= haleAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= haleAttributeTable[item].point;
                    playerDataList[client].haleAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Hale[%d] upgrade=%d",
                                 client, item, playerDataList[client].haleAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "hale");
        }
        else if (StrContains(info, "shared") != -1)
        {
            if (sharedAttributeTable[item].max > playerDataList[client].sharedAttributeData[item].upgrade)
            {
                if (playerDataList[client].skillpoint >= sharedAttributeTable[item].point)
                {
                    playerDataList[client].skillpoint -= sharedAttributeTable[item].point;
                    playerDataList[client].sharedAttributeData[item].upgrade++;

                    // 즉시 저장
                    UpdateUserData(client);
                    UpdateAttributeData(client);

                    PrintToServer("스탯 찍음: Client %d - Shared[%d] upgrade=%d",
                                 client, item, playerDataList[client].sharedAttributeData[item].upgrade);
                }
                else
                {
                    PrintToChat(client, "스킬 포인트가 모자라 강화할 수 없습니다.");
                }
            }

            g_prevOpenMenuPage = GetMenuSelectionPosition();
            Menu_ShowClassStatDetail(client, "shared");
        }
    }

    return 0;
}

// ============================================================================
// 부활 메뉴
// ============================================================================

/**
 * 부활 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowRevive(int client)
{
    int team = GetClientTeam(client);

    if (team == 3)
    {
        CPrintToChat(client, "{red}[경고]{default} 블루팀은 리스폰 메뉴를 사용할 수 없습니다!");
        return;
    }

    Menu menu = CreateMenu(MenuHandler_Revive);

    char titleBuffer[512];
    Format(titleBuffer, sizeof(titleBuffer),
           "헤일 모드 - 부활 메뉴\n―――――――――――――――――\n현재 사용가능한 포인트 : %d\n―――――――――――――――――\n포인트를 사용하면 즉시 부활합니다.\n라운드 시간이 지나거나 부활하면 가격이 비싸집니다.",
           playerDataList[client].point);
    menu.SetTitle(titleBuffer);

    char pointBuffer[128];
    Format(pointBuffer, sizeof(pointBuffer), "%d원으로 부활합니다.(%d회 남음)",
           playerDataList[client].revivePoint, playerDataList[client].reviveCount);

    menu.AddItem("accept", pointBuffer);
    menu.AddItem("cancel", "부활하지 않습니다.");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * 부활 메뉴 핸들러
 */
public int MenuHandler_Revive(Menu menu, MenuAction action, int client, int item)
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

            // 블루팀 모두 체력 회복
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && GetClientTeam(i) == 3)
                {
                    HealClient(i, g_healOnRevive);
                }
            }

            // 모든 플레이어에게 알림
            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || IsFakeClient(i))
                {
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

// ============================================================================
// 스킬 초기화 메뉴
// ============================================================================

/**
 * 스킬 초기화 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowSkillReset(int client)
{
    Menu menu = CreateMenu(MenuHandler_SkillReset);

    char titleBuffer[512];
    Format(titleBuffer, sizeof(titleBuffer),
           "헤일 모드 - 스킬 초기화\n―――――――――――――――――\n―――――――――――――――――\n포인트를 사용하면 스킬을 초기화합니다.\n",
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

/**
 * 스킬 초기화 메뉴 핸들러
 */
public int MenuHandler_SkillReset(Menu menu, MenuAction action, int client, int item)
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
                PrintToChat(client, "포인트가 부족합니다!");
                return 0;
            }

            TakePlayerPoints(client, g_skillResetPoint);

            // 모든 클래스의 스탯 초기화
            for (int i = 0; i < sizeof(playerDataList[client].scoutAttributeData); i++)
            {
                playerDataList[client].scoutAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].medicAttributeData); i++)
            {
                playerDataList[client].medicAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].soldierAttributeData); i++)
            {
                playerDataList[client].soldierAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].pyroAttributeData); i++)
            {
                playerDataList[client].pyroAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].spyAttributeData); i++)
            {
                playerDataList[client].spyAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].demomanAttributeData); i++)
            {
                playerDataList[client].demomanAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].sniperAttributeData); i++)
            {
                playerDataList[client].sniperAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].engineerAttributeData); i++)
            {
                playerDataList[client].engineerAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].heavyAttributeData); i++)
            {
                playerDataList[client].heavyAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].haleAttributeData); i++)
            {
                playerDataList[client].haleAttributeData[i].upgrade = 0;
            }

            for (int i = 0; i < sizeof(playerDataList[client].sharedAttributeData); i++)
            {
                playerDataList[client].sharedAttributeData[i].upgrade = 0;
            }

            // 스킬 포인트 재계산
            playerDataList[client].skillpoint = 0;
            playerDataList[client].skillpoint += playerDataList[client].level * 3;

            PrintToChat(client, "스킬이 초기화되었습니다!");
        }
        else if (StrEqual(info, "cancel"))
        {
            // 아무것도 하지 않음
        }
    }

    return 0;
}

// ============================================================================
// 무기 강화 메뉴
// ============================================================================

/**
 * 무기 강화 메뉴를 표시
 * @param client    클라이언트 인덱스
 */
void Menu_ShowWeaponUpgrade(int client)
{
    Menu menu = CreateMenu(MenuHandler_WeaponUpgrade);

    char titleBuffer[1024];
    Format(titleBuffer, sizeof(titleBuffer),
           "헤일 모드 - 강화 메뉴\n―――――――――――――――――\n현재 사용가능한 포인트 : %d\n―――――――――――――――――\n현재 강화 %d -> %d로 강화\n강화 성공 %.0f%%\n강화 실패 %.0f%%\n강화 파괴 %.0f%%\n―――――――――――――――――\n강화 하시겠습니까?",
           playerDataList[client].point,
           playerDataList[client].weaponAttributeData[0].upgrade,
           playerDataList[client].weaponAttributeData[0].upgrade + 1,
           weaponUpgradeSuccessTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100),
           weaponUpgradeMissTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100),
           weaponUpgradeResetTable[playerDataList[client].weaponAttributeData[0].upgrade] * float(100));
    menu.SetTitle(titleBuffer);

    char yesBuffer[128];
    Format(yesBuffer, sizeof(yesBuffer), "예(%d)",
           weaponUpgradeCostTable[playerDataList[client].weaponAttributeData[0].upgrade]);

    menu.AddItem("accept", yesBuffer);
    menu.AddItem("cancel", "아니오");

    menu.AddItem("back", "상위 메뉴로 돌아가기");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

/**
 * 무기 강화 메뉴 핸들러
 */
public int MenuHandler_WeaponUpgrade(Menu menu, MenuAction action, int client, int item)
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
            Menu_ShowMain(client);
        }
    }

    return 0;
}

/**
 * 무기 강화 타이머 콜백
 */
public Action Timer_WeaponUpgrade(Handle timer, any client)
{
    if (!IsClientInGame(client))
    {
        return Plugin_Continue;
    }

    int upgrade = playerDataList[client].weaponAttributeData[0].upgrade;
    int random = GetRandomInt(1, 100);

    int successPercent = RoundToFloor(weaponUpgradeSuccessTable[upgrade] * float(100));
    int missPercent = RoundToFloor(weaponUpgradeMissTable[upgrade] * float(100));
    int resetPercent = RoundToFloor(weaponUpgradeResetTable[upgrade] * float(100));

    TakePlayerPoints(client, weaponUpgradeCostTable[upgrade]);

    char upgradeText[256];

    if (random <= successPercent)
    {
        // 성공
        Format(upgradeText, sizeof(upgradeText),
               "%d번째 강화에 성공하였습니다.", upgrade + 1);
        PrintToChat(client, upgradeText);
        PrintCenterText(client, upgradeText);

        if (upgrade + 1 >= 7)
        {
            Format(upgradeText, sizeof(upgradeText),
                   "%s님이 %d번째 강화에 성공했습니다.", playerDataList[client].basenick, upgrade + 1);
            PrintToChat(client, upgradeText);

            for (int i = 1; i <= MaxClients; i++)
            {
                if (!IsClientInGame(i) || IsFakeClient(i))
                {
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
    else
    {
        random -= successPercent;

        if (random <= missPercent)
        {
            // 실패
            Format(upgradeText, sizeof(upgradeText),
                   "%d번째 강화에 실패했습니다.", upgrade + 1);
            PrintToChat(client, upgradeText);
            PrintCenterText(client, upgradeText);

            if (upgrade + 1 >= 7)
            {
                Format(upgradeText, sizeof(upgradeText),
                       "%s님이 %d번째 강화에 실패했습니다.", playerDataList[client].basenick, upgrade + 1);

                for (int i = 1; i <= MaxClients; i++)
                {
                    if (!IsClientInGame(i) || IsFakeClient(i))
                    {
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
        else
        {
            // 대실패 (파괴)
            if (resetPercent > 0)
            {
                Format(upgradeText, sizeof(upgradeText),
                       "%d번째 강화에 대실패했습니다.", upgrade + 1);
                PrintToChat(client, upgradeText);
                PrintCenterText(client, upgradeText);

                if (upgrade + 1 >= 7)
                {
                    Format(upgradeText, sizeof(upgradeText),
                           "%s님이 %d번째 강화에 대실패했습니다.", playerDataList[client].basenick, upgrade + 1);

                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (!IsClientInGame(i) || IsFakeClient(i))
                        {
                            continue;
                        }

                        PrintCenterText(i, upgradeText);
                    }

                    EmitSoundToAll("misc/reset1.mp3");
                }
                else
                {
                    EmitSoundToClient(client, "misc/reset1.mp3", _, _, SNDLEVEL_RAIDSIREN);
                }

                // 강화 레벨 초기화
                playerDataList[client].weaponAttributeData[0].upgrade = 0;
            }
        }
    }

    return Plugin_Continue;
}
