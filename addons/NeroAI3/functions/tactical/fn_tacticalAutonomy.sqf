/* NeroAI 4.5.0 [Vanilla Command]: capability-driven autonomy for untouched
 * vanilla groups. Between LLM calls the units are plain vanilla AI; the LLM
 * periodically chooses a grounded multi-action plan and the radio voice.
 * Player orders always suspend autonomy. */
if (!isServer) exitWith {};

private _now = diag_tickTime;
private _ttl = missionNamespace getVariable ["NeroAI_intelTtlSeconds", 180];
private _updates = [];
{
    _updates pushBack [_x, _y select {(_now - (_x # 3)) <= _ttl}];
} forEach NeroAI_sharedIntel;
{ NeroAI_sharedIntel set [_x # 0, _x # 1]; } forEach _updates;

private _maxParallel = if (NeroAI_rulesMode) then {missionNamespace getVariable ["NeroAI_rulesMaxParallelPlans",4]} else {missionNamespace getVariable ["NeroAI_autonomyMaxParallelPlans",3]};
private _pendingBudget = missionNamespace getVariable ["NeroAI_maxPendingAutonomy", 3];
private _planCandidates = [];

{
    private _group = _y;
    if ([_group] call NeroAI_fnc_validateGroup) then {
        private _leader = leader _group;
        private _friendlySide = side _leader;
        private _living = (units _group) select {alive _x};
        private _contacts = [];
        {
            private _target = _x param [4, objNull];
            private _combatObject = !isNull _target && {
                _target isKindOf "Man" || {_target isKindOf "LandVehicle"} ||
                {_target isKindOf "Air"} || {_target isKindOf "Ship"} ||
                {_target isKindOf "StaticWeapon"}
            };
            if (_combatObject && {alive _target} && {(_friendlySide getFriend (side _target)) < 0.6}) then {
                _contacts pushBackUnique _target;
            };
        } forEach (_leader nearTargets (missionNamespace getVariable ['NeroAI_enemyMaxDistanceMeters', 4000]));

        private _intel = [];
        {
            private _pos = _leader getHideFrom _x;
            if !(_pos isEqualTo [0,0,0]) then {
                _intel pushBack [typeOf _x, [round (_pos # 0), round (_pos # 1)], round ((_leader knowsAbout _x) * 10), netId _x];
            };
        } forEach _contacts;
        _intel resize ((count _intel) min 12);
        _group setVariable ["NeroAI_intel", _intel, true];
        _group setVariable ["NeroAI_capabilities", [_group] call NeroAI_fnc_analyzeGroupCapabilities, true];

        private _manualHold = _group getVariable ["NeroAI_playerHold", false];
        private _manualBusy = _now < (_group getVariable ["NeroAI_manualOrderUntil", 0]);
        private _support = _group getVariable ["NeroAI_supporting",[]];
        private _supportBusy = (_group getVariable ["NeroWL_vehicleService",false]) || {NeroAI_rulesMode && {count _support >= 3} && {_now - (_support # 2) < 180}};
        private _readinessChanged = false;
        private _readinessLost = false;
        if (NeroAI_rulesMode) then {
            _group setVariable ["NeroWL_rulesObservedAt",_now];
            private _combat = [_group] call NeroAI_fnc_rulesCombatFacts;
            private _fingerprint = [_combat # 0,_combat # 2,_combat # 3,_combat # 4,_combat # 5];
            _readinessChanged = !(_fingerprint isEqualTo (_group getVariable ["NeroWL_rulesLastReadiness",[]]));
            _group setVariable ["NeroWL_rulesLastReadiness",_fingerprint];
            /* Revoke an ongoing autonomous assault as soon as readiness is lost.
             * Manual, logistics and support orders retain their priority. */
            private _phase = _group getVariable ["NeroWL_rulesPhase",[]];
            _readinessLost = !(_combat # 2) && {(_phase param [0,""]) isEqualTo "ASSAULT"};
            if (_readinessLost && {!_manualHold} && {!_manualBusy} && {!_supportBusy}
                && {_now >= (_group getVariable ["NeroWL_logisticsUntil",0])}
                && {_now >= (_group getVariable ["NeroAI_purchaseHoldUntil",0])}) then {
                [_group,"HOLD",getPosATL _leader,"DEFEND","AUTONOMY"] call NeroAI_fnc_executeMacro;
                _group setVariable ["NeroWL_rulesPhase",["REASSESS",_now,_phase param [2,""]]];
                _group setVariable ["NeroAI_forcePlan",true,true];
            };
        };
        /* 4.5.0: own-vehicle-first and spend-the-purse policies (deterministic). */
        if (!_manualBusy && {!_manualHold} && {!_supportBusy}) then { [_group] call NeroAI_fnc_autoRequisition; };
        private _currentStrength = count _living;
        private _previousStrength = _group getVariable ["NeroAI_lastKnownStrength", _currentStrength];
        private _contactIds = _contacts apply {netId _x};
        _contactIds sort true;
        private _previousContacts = +(_group getVariable ["NeroAI_lastContactIds", []]);
        _previousContacts sort true;
        private _contactChanged = !(_contactIds isEqualTo _previousContacts);
        _group setVariable ["NeroAI_lastContactIds", _contactIds, true];
        _group setVariable ["NeroAI_lastKnownStrength", _currentStrength, true];

        if !(_contacts isEqualTo []) then {
            private _roe = _group getVariable ["NeroAI_playerROE", ""];
            [_group, "подтверждённый контакт"] call NeroAI_fnc_shareIntel;
            private _initial = _group getVariable ["NeroAI_initialStrength", _currentStrength];
            private _heavyLosses = _initial > 0 && {_currentStrength <= ceil (_initial * 0.5)};
            if (!_manualBusy && {!_manualHold} && {!_supportBusy} && {_heavyLosses || {count _contacts > (_currentStrength * 1.5)}}) then {
                [_group, getPosATL _leader, "потери или численное превосходство противника"] call NeroAI_fnc_requestSupport;
            };
        } else {
            /* Keep the mission's current sector objective and native waypoints. */
            /* 11.10: a squad tasked by the tactical-AI strategist keeps its task
             * (staging, defence, reserve) instead of resuming the native waypoint. */
            private _rulesTasked = NeroAI_rulesMode && {!(((_group getVariable ["NeroWL_rulesMission", []]) param [0, "NONE"]) isEqualTo "NONE")};
            if (!_manualBusy && {!_manualHold} && {!_supportBusy} && {!_rulesTasked} && {_now >= (_group getVariable ["NeroAI_purchaseHoldUntil",0])} && {_now >= (_group getVariable ["NeroWL_logisticsUntil",0])}) then {
                [_group] call NeroAI_fnc_warlordsAutonomy;
            };
        };

        private _mobility = _group getVariable ["NeroAI_mobility", ["UNKNOWN", [], 0, 0, 0, [0, false]]];
        private _stalled = _mobility isEqualType [] && {count _mobility > 0} && {(_mobility # 0) in ["STALLED", "COLLISION_RISK"]};
        private _forced = _group getVariable ["NeroAI_forcePlan", false];
        private _ambush = _group getVariable ["NeroAI_ambushPending", false];
        private _lastPlan = _group getVariable ["NeroAI_lastAutonomyPlan", -120];
        private _interval = if (NeroAI_rulesMode) then {missionNamespace getVariable ["NeroAI_rulesPlanIntervalSeconds",15]} else {missionNamespace getVariable ["NeroAI_autonomyPlanIntervalSeconds",28]};

        /* Anti-loop back-off: a real event always resets the idle streak and
         * replans now; a group that keeps producing pure comms/recon plans for an
         * unchanged situation stretches its scheduled interval up to 6x. */
        private _event = _forced || {_ambush} || {_contactChanged} || {_currentStrength < _previousStrength} || {_stalled} || {_readinessChanged};
        if (_event) then { _group setVariable ["NeroAI_idlePlanStreak", 0, true]; };
        private _idleStreak = _group getVariable ["NeroAI_idlePlanStreak", 0];
        private _backoffAfter = missionNamespace getVariable ["NeroAI_idlePlanBackoffAfter", 3];
        private _dueInterval = if (NeroAI_rulesMode) then {_interval} else {_interval * (1 + (((_idleStreak - _backoffAfter + 1) max 0) min 5))};
        private _due = (_now - _lastPlan) >= _dueInterval;
        /* 4.4.0 token economy: a scheduled (non-event) plan for a group whose
         * cheap state fingerprint is identical to the last one it planned on is
         * not sent at all — nothing changed, so the answer would not either. */
        /* 4.5.1 (live 23:00: 46 requests/min, org 429s): a group still marching to
         * its last autonomous ADVANCE/ASSAULT target — target > 120 m away, ordered
         * within the last 4 min — needs no scheduled replan; events still replan. */
        if (!NeroAI_rulesMode && {_due} && {!_event}) then {
            private _lm = _group getVariable ["NeroAI_lastAutonomyMove", ["", [], -1e6]];
            if ((_lm # 0) in ["ADVANCE", "ASSAULT"] && {(_lm # 1) isEqualType []} && {(count (_lm # 1)) >= 2}
                && {(_now - (_lm # 2)) < 240} && {(_leader distance2D (_lm # 1)) > 120}) then {
                _due = false;
                _group setVariable ["NeroAI_lastAutonomyPlan", _now - (_dueInterval / 2), true];
            };
        };
        /* 8.10: a group executing a behaviour template needs no scheduled replan for 4 min;
         * losses, new contacts, stalls and forced plans still replan at once. */
        if (!NeroAI_rulesMode && {_due} && {!_event}) then {
            private _tpl = _group getVariable ["NeroWL_tactic", []];
            if (((_tpl param [3, ""]) isEqualTo "EXEC") && {(_now - (_tpl param [2, 0])) < (missionNamespace getVariable ["NeroAI_tacticReplanSeconds", 240])}) then {
                _due = false;
                _group setVariable ["NeroAI_lastAutonomyPlan", _now - (_dueInterval / 2), true];
            };
        };
        if (!NeroAI_rulesMode && {_due} && {!_event} && {missionNamespace getVariable ["NeroAI_planSkipUnchanged", true]}) then {
            private _lp = getPosATL _leader;
            private _fp = format ["%1|%2|%3|%4", round ((_lp # 0) / 50), round ((_lp # 1) / 50), _currentStrength, count _contacts];
            if (_fp isEqualTo (_group getVariable ["NeroAI_planFingerprint", ""])) then {
                _due = false;
                _group setVariable ["NeroAI_lastAutonomyPlan", _now - (_dueInterval / 2), true];
            } else {
                _group setVariable ["NeroAI_planFingerprint", _fp, true];
            };
        };
        if (
            (NeroAI_rulesMode || {(count _planCandidates) < _maxParallel}) && {NeroAI_rulesMode || {NeroAI_transportReady}} &&
            {NeroAI_rulesMode || {(count NeroAI_pending) < _pendingBudget}} &&
            {!_manualBusy} && {!_manualHold} && {!_supportBusy} && {_due || {_event}}
            && {_now >= (_group getVariable ["NeroAI_purchaseHoldUntil", 0])}
            && {_now >= (_group getVariable ["NeroWL_logisticsUntil", 0])}
        ) then {
            private _reason = if (_ambush) then {"ЗАСАДА"} else {
                if (_event) then {"изменение боевой обстановки"} else {
                    if (_idleStreak >= _backoffAfter) then {"застой: несколько циклов без манёвра — выдвигайся, штурмуй или HOLD, не повторяй запросы"} else {"плановый тактический цикл"}
                }
            };
            _planCandidates pushBack [_group, _reason, _intel,if (_readinessLost) then {-1e9} else {if (_forced) then {-1e8 + _lastPlan} else {_lastPlan}}];
        };
    };
} forEach NeroAI_activeGroups;

/* Fair scheduling: oldest plan first; revoking an unsafe assault is urgent.
 * Do not starve late entries in the active-groups map when contacts persist. */
if (NeroAI_rulesMode) then {
    private _pool = +_planCandidates;_planCandidates = [];
    while {count _pool > 0 && {count _planCandidates < (_maxParallel max 1)}} do {
        private _best = 0;
        {if ((_x # 3) < ((_pool # _best) # 3)) then {_best = _forEachIndex;};} forEach _pool;
        _planCandidates pushBack (_pool deleteAt _best);
    };
};
private _fnc_sideCommand = {
    params ["_grp", "_reason", "_intelRows"];
    private _ldr = leader _grp;
    private _facts = "";
    if !(_intelRows isEqualTo []) then {
        private _row = _intelRows # 0;
        private _cpos = _row # 1;
        private _bearing = round (_ldr getDir _cpos);
        private _dist = round ((getPosATL _ldr) distance2D _cpos);
        _facts = format [" Ближайший контакт: азимут %1, дистанция %2 м, координаты %3 %4.", _bearing, _dist, _cpos # 0, _cpos # 1];
    };
    /* The native Warlords objective is authoritative; never substitute the
     * nearest neutral/enemy sector, which may not be capturable. */
    private _mySideKey = switch (side _grp) do { case east: {"RED"}; case resistance: {"GREEN"}; default {"BLUE"} };
    private _objective = if(_grp getVariable["NeroWL_garrison",false])then{_grp getVariable["NeroWL_garrisonSector",objNull]}else{missionNamespace getVariable [format ["BIS_WL_currentSector_%1", side _grp], objNull]};
    if (_objective isEqualType objNull && {!isNull _objective}) then {
        private _pos = getPosATL _objective;
        _facts = _facts + format [" ЦЕЛЬ WARLORDS: текущий сектор %1 в %2 м, азимут %3, координаты %4 %5.",
            _objective, round (_ldr distance2D _objective), round (_ldr getDir _objective), round (_pos # 0), round (_pos # 1)];
    };
    private _amb = _grp getVariable ["NeroAI_ambushState", []];
    if (_amb isEqualType [] && {count _amb >= 2} && {_reason isEqualTo "ЗАСАДА"}) then {
        _facts = _facts + format [" ЗАСАДА: внезапный близкий контакт, азимут %1, дистанция %2 м.", _amb param [1, 0], _amb param [2, 0]];
    };
    /* 4.4.0 token economy: the order carries FACTS only. Doctrine per side and
     * terrain live once in the system prompt (bridge/system-prompt.js) and the
     * snapshot already names side and terrain — repeating ~500 Cyrillic chars
     * of doctrine here cost ~250 tokens on every one of ~11 requests/min and
     * said nothing the model did not already have. */
    format ["АВТОНОМИЯ %1: %2.%3", _mySideKey, _reason, _facts]
};

{
    _x params ["_planGroup", "_reason", "_intelRows"];
    _planGroup setVariable ["NeroAI_forcePlan", false, true];
    _planGroup setVariable ["NeroAI_ambushPending", false, true];
    _planGroup setVariable ["NeroAI_lastAutonomyPlan", _now, true];
    if (NeroAI_rulesMode) then {
        /* 11.10: tactical AI without LLM — the same candidate decides locally. */
        [_planGroup, _reason, _intelRows] call NeroAI_fnc_rulesGroupPlan;
    } else {
        private _command = [_planGroup, _reason, _intelRows] call _fnc_sideCommand;
        private _result = [[_planGroup], objNull, "AUTONOMY", _command, "AUTONOMY"] call NeroAI_fnc_sendBridgeRequest;
        if !(_result # 0) then {
            _planGroup setVariable ["NeroAI_lastAutonomyPlan", _now - 12, true];
        };
    };
} forEach _planCandidates;
