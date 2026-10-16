if (!isServer) exitWith {};
if (NeroAI_serverInitStarted) exitWith {};
NeroAI_serverInitStarted = true;

/* Authority belongs to the mission/server, not to the LLM.  Capture it while
   the old player object is alive, then freeze the snapshot across respawn. */
addMissionEventHandler ["EntityKilled", {
    params ["_unit"];
    if (isPlayer _unit) then {
        [_unit, true] call NeroAI_fnc_capturePlayerAuthority;
    };
}];

addMissionEventHandler ["EntityRespawned", {
    params ["_newEntity"];
    if (isPlayer _newEntity) then {
        [_newEntity] spawn {
            params ["_player"];
            private _deadline = diag_tickTime + 8;
            waitUntil {
                uiSleep 0.1;
                (!isNull _player && {isPlayer _player} && {owner _player > 0}) ||
                {diag_tickTime >= _deadline}
            };
            if (!isNull _player && {isPlayer _player}) then {
                [_player] call NeroAI_fnc_restorePlayerAuthority;
            };
        };
    };
}];

[] spawn {
    while {true} do {
        {
            if (alive _x) then {[_x, false] call NeroAI_fnc_capturePlayerAuthority;};
        } forEach allPlayers;
        uiSleep 2;
    };
};

[] spawn {
    /* 9.10: the mission applies its lobby settings in initServer.sqf; wait for them
     * (bounded) so the standard-AI mode is known before anything is started. */
    private _settingsDeadline = diag_tickTime + 20;
    waitUntil {uiSleep 0.5; (missionNamespace getVariable ["NeroWL_settingsApplied", false]) || {diag_tickTime >= _settingsDeadline}};
    if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {
        NeroAI_enemyAIEnabled = false; NeroAI_friendlyLLMEnabled = false; NeroAI_friendlyAutoEnrollEnabled = false;
        {publicVariable _x;} forEach ["NeroAI_enemyAIEnabled","NeroAI_friendlyLLMEnabled","NeroAI_friendlyAutoEnrollEnabled"];
        ["INFO", "Standard Arma AI mode: NeroAI bridge, planner and group control are not started; Warlords AI commands every group."] call NeroAI_fnc_log;
    };
    /* 11.10: tactical AI without LLM needs no INIDBI transport and no bridge. */
    private _rules = missionNamespace getVariable ["NeroAI_rulesMode", false];
    if (!_rules) then {
        private _deadline = diag_tickTime + 30;
        waitUntil {
            if (!isNil "OO_INIDBI") exitWith {true};
            uiSleep 0.5;
            diag_tickTime >= _deadline
        };
    };
    if (!_rules && {isNil "OO_INIDBI"}) exitWith {
        ["ERROR", "INIDBI2 API OO_INIDBI is unavailable after 30 seconds. NeroAI bridge is disabled for this mission."] call NeroAI_fnc_log;
    };
    if (_rules) then {
        /* Plans are local and free: more squads per tick, a shorter cycle, no
         * "unchanged snapshot" skip (a staging squad must notice its partners),
         * templates re-checked after a minute, no LLM radio relay. */
        NeroAI_autonomyMaxParallelPlans = 6;
        NeroAI_autonomyPlanIntervalSeconds = 20;
        NeroAI_planSkipUnchanged = false;
        NeroAI_tacticReplanSeconds = 60;
        NeroAI_intergroupEnabled = false;
        ["INFO", format ["Tactical AI without LLM: side strategist every %1 s, squad rules, AI sector vote; no bridge, no INIDBI, no models. LAMBS templates: %2.",
            NeroAI_rulesCommanderSeconds, if (isNil "lambs_wp_fnc_taskCQB") then {"not loaded — plain orders"} else {"loaded"}]] call NeroAI_fnc_log;
    };

    /* Community missions can finish Warlords initialization after the first
       spawn or even after a respawn. Keep waiting for the real mission API;
       this script is automatically terminated when the mission ends. */
    private _nextReadinessLog = diag_tickTime + 90;
    private _warlordsReady = false;
    while {!_warlordsReady} do {
        uiSleep 2;
        private _warlords = missionNamespace getVariable ["BIS_WL_allWarlords", []];
        private _sectors = missionNamespace getVariable ["BIS_WL_sectors", []];
        _warlordsReady = !isNil "BIS_WL_allWarlords" &&
            {!isNil "BIS_WL_sectors"} &&
            {count _warlords > 0} &&
            {count _sectors > 0} &&
            {!isNil "BIS_fnc_WLAirdrop"};
        if (!_warlordsReady && {diag_tickTime >= _nextReadinessLog}) then {
            ["WARN", format ["Waiting for Warlords mission API: warlords=%1 sectors=%2 airdrop=%3 westBase=%4 eastBase=%5",
                count _warlords, count _sectors, !isNil "BIS_fnc_WLAirdrop",
                !isNil "BIS_WL_base_WEST", !isNil "BIS_WL_base_EAST"]] call NeroAI_fnc_log;
            _nextReadinessLog = diag_tickTime + 90;
        };
    };

    NeroAI_transportReady = true;
    if (isNil "NeroAI_warlordsIdleSeconds") then {NeroAI_warlordsIdleSeconds = 180;};
    ["INFO", "NeroAI 4.7.0 [Any Warlords] autonomous server initialized; vanilla groups are preserved."] call NeroAI_fnc_log;
    [] spawn NeroAI_fnc_serverLoop;
    /* Road distances between linked sectors on the live road network
     * (background; warms the route cache, feeds the planner snapshot). */
    [] spawn {sleep 20; [] call NeroAI_fnc_roadSurvey;};

    /* Stand up each side's base drone and apply scenario tuning (start CP top-up,
     * UAV terminals) once players are in. */
    [] spawn {
        private _deadline = diag_tickTime + 90;
        waitUntil { uiSleep 2; !((allPlayers select {alive _x}) isEqualTo []) || {diag_tickTime > _deadline} };
        /* Wait (bounded) for the Warlords module to publish its faction pool and
         * base hubs; the profile also works without them (unit clusters, markers). */
        private _wlDeadline = diag_tickTime + 60;
        waitUntil { uiSleep 1; (!isNil "BIS_WL_factionsPool" && {!isNil "BIS_WL_base_WEST"} && {!isNil "BIS_WL_base_EAST"}) || {diag_tickTime > _wlDeadline} };
        [] call NeroAI_fnc_scenarioProfile;
        /* No free assets or CP top-up in the dedicated Warlords mode. */
    };

    /* Bring the adversary under NeroAI immediately instead of waiting a full
     * 8 s manage tick. The first pass runs as a wide start seed (see
     * fn_manageEnemyAI) so RED / GREEN are controlled from match start even
     * while still across the map. Retried briefly in case players are not
     * fully in yet. */
    if (missionNamespace getVariable ["NeroAI_enemyAIEnabled", true]) then {
        [] spawn {
            private _tries = 0;
            while {_tries < 10 && {!(missionNamespace getVariable ["NeroAI_enemySeeded", false])}} do {
                [] call NeroAI_fnc_manageEnemyAI;
                _tries = _tries + 1;
                uiSleep 2;
            };
        };
    };
};
