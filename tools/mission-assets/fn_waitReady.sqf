/* Show readiness rather than a seemingly empty map while native Warlords
 * enumerates the loaded mod catalogs. No second initialization or timer restart. */
[] spawn {
    disableSerialization;
    private _started = diag_tickTime;
    private _nextLog = _started;
    private _ready = false;
    private _observerMission = getNumber (missionConfigFile >> "NeroWL_observer") == 1;
    while {!_ready} do {
        // 9.10: only the Civilian observer is an observer; a WEST/EAST slot gets the normal Warlords UI.
        private _observer = _observerMission && {missionNamespace getVariable ["NeroWL_localObserver", isNull player || {!((side group player) in [WEST, EAST])}]};
        private _sectors = missionNamespace getVariable ["BIS_WL_sectors",[]];
        private _west = missionNamespace getVariable ["BIS_WL_base_WEST",objNull];
        private _east = missionNamespace getVariable ["BIS_WL_base_EAST",objNull];
        private _serverReady = count _sectors >= 3 && {!isNull _west} && {!isNull _east} && {!isNil "BIS_WL_sectorsArrayWEST"} && {!isNil "BIS_WL_sectorsArrayEAST"};
        // Sector objects exist before ClientInit can fail. Require actual map
        // markers, native selection FSM, funds and menu initialization as well.
        private _clientReady = !hasInterface || {_observer && {missionNamespace getVariable ["NeroWL_observerReady",false]}} || {!_observer && {
            !isNull player && {!isNil "BIS_WL_selectionFSM"} &&
            {!isNil {player getVariable "BIS_WL_funds"}} &&
            {markerShape "BIS_WL_sectorMrkr_0" == "RECTANGLE"} &&
            {!isNil "BIS_WL_sectorsArrayFriendly"} &&
            {!(isNil {missionNamespace getVariable "BIS_WL_purchaseMenuVisible"})} &&
            {!isNull ((findDisplay 46) displayCtrl 9989999)}
        }};
        _ready = _serverReady && _clientReady;
        if (diag_tickTime >= _nextLog) then {
            _nextLog = diag_tickTime + 30;
            diag_log format ["[NeroWL Ready] elapsed=%1 sectors=%2 bases=%3/%4 server=%5 client=%6",round (diag_tickTime-_started),count _sectors,!isNull _west,!isNull _east,_serverReady,_clientReady];
            if (hasInterface && {!_ready}) then {titleText [if (diag_tickTime-_started > 120) then {"Запуск Warlords задерживается: проверьте журнал NeroAI. Ожидание LLM не блокирует загрузку миссии."} else {"Подготовка Warlords: сектора, базы и каталог техники. Пожалуйста, подождите."},"PLAIN DOWN",0.5];};
        };
        sleep 2;
    };
    diag_log format ["[NeroWL Ready] READY elapsed=%1 warlords=%2 clientMarkers=%3",round (diag_tickTime-_started),count (missionNamespace getVariable ["BIS_WL_allWarlords",[]]),markerShape "BIS_WL_sectorMrkr_0"];
    if (hasInterface) then {titleText [format ["Warlords готов. RHS, покупки за CP, Зевс: Y. %1.",if (missionNamespace getVariable ["NeroAI_vanillaMode",false]) then {"Ботами командует штатный ИИ Arma"} else {if (missionNamespace getVariable ["NeroAI_rulesMode",false]) then {"Ботами командует тактический ИИ NeroAI (без LLM)"} else {if (missionNamespace getVariable ["NeroAI_enemyAIEnabled",true]) then {"Управление LLM: включено"} else {"Управление LLM: выключено"}}}],"PLAIN DOWN",0.5];};
};
