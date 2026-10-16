/* 11.10 Tactical AI without LLM — side strategist (server, every
 * NeroAI_rulesCommanderSeconds; the vote watcher calls it with _voteOnly).
 *
 * Per regular army (WEST / EAST):
 *   1. POSTURE from the lobby aggression, the public sector income of both
 *      sides and the army's own attrition (fn_rulesPosture);
 *   2. TARGET: scores every sector Warlords lets the side attack
 *      (BIS_WL_sectorsArray<side> # 1) with fn_rulesScoreSector and stores the
 *      winner; fn_rulesVoteWatch casts it as the AI commanders' vote. The native
 *      AI votes at random (or always for the enemy HQ) — this replaces only that;
 *   3. ALLOCATION: owned sectors the enemy has voted / is fighting in become
 *      threats; fn_rulesAllocate splits the NeroAI squads into DEFEND / RESERVE /
 *      ATTACK and gives each attacker its own approach bearing (envelopment);
 *   4. ROLES: a fighter role appears once enemy aircraft are seen.
 * Partisans (GREEN) and sector garrisons hold their own ground.
 *
 * Knowledge is the side's own: shared intel of its squads, the public map
 * (sector owners / income / the enemy's announced target), its own losses. */
params [["_sides", [west, east], [[]]], ["_voteOnly", false, [false]]];
if (!isServer || {!(missionNamespace getVariable ["NeroAI_rulesMode", false])}) exitWith {};
private _now = diag_tickTime;
private _sectors = missionNamespace getVariable ["BIS_WL_sectors", []];
if !(_sectors isEqualType []) exitWith {};
_sectors = _sectors select {_x isEqualType objNull && {!isNull _x}};
if (_sectors isEqualTo []) exitWith {};
private _threeSides = getNumber (missionConfigFile >> "NeroWL_threeSides") == 1;
private _baseW = missionNamespace getVariable ["BIS_WL_base_WEST", objNull];
private _baseE = missionNamespace getVariable ["BIS_WL_base_EAST", objNull];
private _aggression = missionNamespace getVariable ["NeroWL_aggression", 1];
if !(_aggression isEqualType 0) then {_aggression = 1;};
private _intelTtl = missionNamespace getVariable ["NeroAI_rulesSectorIntelSeconds", 600];

private _fnc_radius = {
    params ["_s"];
    private _size = _s getVariable ["Size", 300];
    if !(_size isEqualType 0) then {_size = 300;};
    ((_size / 2) max 75) min 400
};
private _fnc_value = {
    params ["_s"];
    private _v = _s getVariable ["BIS_WL_value", 10];
    if (_v isEqualType 0) then {_v} else {10}
};
private _fnc_name = {
    params ["_s"];
    private _n = _s getVariable ["Name", ""];
    if !(_n isEqualType "") then {_n = "";};
    if ((toUpper _n) select [0, 4] isEqualTo "STR_") then {_n = localize _n;};
    if (_n isEqualTo "") then {_n = _s getVariable ["BIS_WL_sectorName", mapGridPosition _s];};
    _n
};
private _fnc_income = {
    params ["_side"];
    private _sum = 0;
    { if ((_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _side) then {_sum = _sum + ([_x] call _fnc_value);}; } forEach _sectors;
    _sum
};
/* Hostiles this side has seen at a sector: fresh shared intel refreshes a
 * per-side memory that fades after _intelTtl (the snapshot TTL is 3 min). */
private _memory = missionNamespace getVariable ["NeroWL_rulesSectorIntel", createHashMap];
private _fnc_known = {
    params ["_side", "_s"];
    private _key = format ["%1|%2", _side, netId _s];
    private _rows = (NeroAI_sharedIntel getOrDefault [str _side, []]) select {(_now - (_x param [3, -1e6])) <= 120};
    _rows = [_rows] call NeroAI_fnc_rulesUniqueIntel;
    private _r = ([_s] call _fnc_radius) + 400;
    private _seen = {((_x param [1, [0, 0]]) distance2D _s) <= _r} count _rows;
    if (_seen > 0) then {_memory set [_key, [_seen, _now]];};
    private _entry = _memory getOrDefault [_key, [0, -1e6]];
    if ((_now - (_entry # 1)) > _intelTtl) then {_memory deleteAt _key; 0} else {_entry # 0}
};

{
    private _side = _x;
    private _enemy = if (_side isEqualTo west) then {east} else {west};
    private _tag = str _side;
    private _base = if (_side isEqualTo west) then {_baseW} else {_baseE};
    private _enemyBase = if (_side isEqualTo west) then {_baseE} else {_baseW};
    private _groups = [];
    { if ((side _y) isEqualTo _side && {[_y] call NeroAI_fnc_validateGroup}) then {_groups pushBack _y;}; } forEach NeroAI_activeGroups;

    /* 1. Posture. */
    private _alive = {alive _x && {!isPlayer _x} && {(side group _x) isEqualTo _side}} count allUnits;
    private _peak = (missionNamespace getVariable ["NeroWL_rulesPeak_" + _tag, 0]) max _alive;
    missionNamespace setVariable ["NeroWL_rulesPeak_" + _tag, _peak];
    private _attrition = if (_peak > 0) then {_alive / _peak} else {1};
    private _incomeRatio = ([_side] call _fnc_income) / (([_enemy] call _fnc_income) max 1);
    private _enemyTarget = missionNamespace getVariable [format ["BIS_WL_currentSector_%1", _enemy], objNull];
    private _hqThreat = !isNull _base && {_enemyTarget isEqualTo _base};
    private _counterTarget = if (_threeSides) then {objNull} else {[_side] call NeroAI_fnc_wlCounterTarget};
    private _posture = [_aggression, _incomeRatio, _attrition, _hqThreat] call NeroAI_fnc_rulesPosture;
    private _oldPosture = missionNamespace getVariable ["NeroWL_rulesPosture_" + _tag, -1];
    missionNamespace setVariable ["NeroWL_rulesPosture_" + _tag, _posture, true];
    if (_posture != _oldPosture) then {
        ["INFO", format ["RULES %1 posture %2 (income x%3, attrition %4%5).", _tag, ["DEFENSIVE", "BALANCED", "OFFENSIVE"] # _posture,
            (round (_incomeRatio * 100)) / 100, round (_attrition * 100), "%"]] call NeroAI_fnc_log;
    };

    /* Force centre: the squads in the field, else the HQ. */
    private _field = _groups select {!(_x getVariable ["NeroWL_garrison", false]) && {!([_x] call NeroAI_fnc_isAirCrewGroup)}};
    private _centre = if (isNull _base) then {[0, 0, 0]} else {getPosATL _base};
    if (_field isNotEqualTo []) then {
        private _sx = 0; private _sy = 0;
        { private _p = getPosATL (leader _x); _sx = _sx + (_p # 0); _sy = _sy + (_p # 1); } forEach _field;
        _centre = [_sx / (count _field), _sy / (count _field), 0];
    };

    /* 2. Target selection (two-army native voting only). */
    if (!_threeSides) then {
        private _available = ([_side] call NeroAI_fnc_wlSnapshot) param [1, []];
        if !(_available isEqualType []) then {_available = [];};
        private _incumbent = missionNamespace getVariable ["NeroWL_rulesVote_" + _tag, objNull];
        private _best = objNull;
        private _bestScore = -1e9;
        private _table = [];
        {
            private _s = _x;
            private _links = _s getVariable ["BIS_WL_connectedSectors", []];
            if !(_links isEqualType []) then {_links = [];};
            private _front = {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _enemy} count _links;
            private _ownerKind = if ((_s getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _enemy) then {1} else {0};
            private _score = [[_s] call _fnc_value, _centre distance2D _s, [_side, _s] call _fnc_known, _ownerKind,
                _s isEqualTo _enemyBase, count _links, _front, _posture, _s isEqualTo _incumbent, _attrition] call NeroAI_fnc_rulesScoreSector;
            if (_s isEqualTo _counterTarget) then {_score = _score+100000;};
            _table pushBack format ["%1=%2", [_s] call _fnc_name, _score];
            if (_score > _bestScore) then {_bestScore = _score; _best = _s;};
        } forEach _available;
        missionNamespace setVariable ["NeroWL_rulesVote_" + _tag, _best];
        if (!isNull _best && {!(_best isEqualTo _incumbent)}) then {
            ["INFO", format ["RULES %1 target choice %2 (score %3; %4).", _tag, [_best] call _fnc_name, _bestScore, _table joinString ", "]] call NeroAI_fnc_log;
        };
    };
    /* Allocation and roles are skipped by the fast vote watcher. */
    if (!_voteOnly) then {

        /* 3. Threats to own sectors, HQ first. */
        private _threats = [];
        private _threatSectors = [];
        if (!isNull _enemyTarget && {(_enemyTarget getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _side}) then {
            private _known = [_side, _enemyTarget] call _fnc_known;
            private _isHq = _enemyTarget isEqualTo _base;
            _threats pushBack [netId _enemyTarget, if (_isHq) then {3} else {((ceil (_known / 5)) max 1) min 3}, if (_isHq) then {-1} else {3500}];
            _threatSectors pushBack _enemyTarget;
        };
        {
            private _s = _x;
            if ((_s getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _side && {!(_s in _threatSectors)}) then {
                private _rows = (NeroAI_sharedIntel getOrDefault [_tag, []]) select {(_now - (_x param [3, -1e6])) <= 120};
                _rows = [_rows] call NeroAI_fnc_rulesUniqueIntel;
                private _r = ([_s] call _fnc_radius) + 150;
                private _inside = {((_x param [1, [0, 0]]) distance2D _s) <= _r} count _rows;
                if (_inside >= 3) then {
                    _threats pushBack [netId _s, if (_inside >= 8) then {2} else {1}, 2500];
                    _threatSectors pushBack _s;
                };
            };
        } forEach _sectors;
        private _hqIdx = _threatSectors find _base;
        if (_hqIdx > 0) then {
            private _t = _threats deleteAt _hqIdx; _threats = [_t] + _threats;
            private _ts = _threatSectors deleteAt _hqIdx; _threatSectors = [_ts] + _threatSectors;
        };

        /* 4. Allocation for squads in the field. */
        private _rows = _field apply {
            private _g = _x;
            private _facts = [_g] call NeroAI_fnc_rulesCombatFacts;
            private _living = if (_facts # 3) then {_facts param [9,1]} else {_facts # 0};
            private _cur = _g getVariable ["NeroWL_rulesMission", []];
            private _curSector = _cur param [1, objNull];
            [netId _g, _living, _threatSectors apply {(leader _g) distance2D _x}, _cur param [0, ""],
                if (_curSector isEqualType objNull && {!isNull _curSector}) then {_threatSectors find _curSector} else {-1},
                !(_facts # 2),_facts # 2,
                !(_g getVariable ["NeroAI_playerHold",false]) && {!(_g getVariable ["NeroWL_vehicleService",false])} && {_now >= (_g getVariable ["NeroAI_manualOrderUntil",0])} &&
                {_now >= (_g getVariable ["NeroWL_logisticsUntil",0])} && {_now >= (_g getVariable ["NeroAI_purchaseHoldUntil",0])} &&
                {private _supporting = _g getVariable ["NeroAI_supporting",[]];count _supporting < 3 || {_now - (_supporting # 2) >= 180}},
                if (isNull _counterTarget) then {1e9} else {(leader _g) distance2D _counterTarget},(_facts # 2) && {!(_facts # 3)}]
        };
        private _plan = [_rows, _threats, _posture,!isNull _counterTarget] call NeroAI_fnc_rulesAllocate;
        private _target = missionNamespace getVariable [format ["BIS_WL_currentSector_%1", _side], objNull];
        if (!isNull _counterTarget) then {_target = _counterTarget;};
        /* Reserve point: the own sector nearest the current objective (behind the
         * front), else the HQ. */
        private _reserveSector = _base;
        private _ownNonBase = _sectors select {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _side && {!(_x in [_baseW, _baseE])}};
        if (_ownNonBase isNotEqualTo []) then {
            private _ref = if (isNull _target) then {_centre} else {getPosATL _target};
            _reserveSector = _ownNonBase # 0;
            { if ((_x distance2D _ref) < (_reserveSector distance2D _ref)) then {_reserveSector = _x;}; } forEach _ownNonBase;
        };

        /* A newly captured sector gets a real holding group. Initial ownership
         * is a baseline, not a capture event. Losing it cancels the hold. */
        private _ownersKey = "NeroWL_rulesOwners_" + _tag;
        private _oldOwners = missionNamespace getVariable [_ownersKey,[]];
        private _owners = _ownNonBase apply {netId _x};
        private _holdKey = "NeroWL_rulesCaptureHold_" + _tag;
        private _hold = missionNamespace getVariable [_holdKey,[objNull,-1]];
        if (missionNamespace getVariable [_ownersKey + "_ready",false]) then {
            private _new = _ownNonBase select {!((netId _x) in _oldOwners)};
            if (_new isNotEqualTo []) then {
                _hold = [_new # 0,_now + (missionNamespace getVariable ["NeroAI_rulesConsolidateSeconds",120])];
                ["INFO",format ["OPERATION %1 CONSOLIDATE %2.",_tag,[_hold # 0] call _fnc_name]] call NeroAI_fnc_log;
            };
        };
        missionNamespace setVariable [_ownersKey,_owners];
        missionNamespace setVariable [_ownersKey + "_ready",true];
        private _holdSector = _hold # 0;
        private _captureHold = !_hqThreat && {!isNull _holdSector} && {_now < (_hold # 1)} && {(_holdSector getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side};
        if (!_captureHold) then {_hold = [objNull,-1];};
        missionNamespace setVariable [_holdKey,_hold];
        if (_captureHold) then {
            private _best = -1;private _distance = 1e12;
            {
                if ((_x # 1) != "MANUAL" && {(_x # 1) != "DEFEND" || {(_threatSectors param [_x # 2,objNull]) isEqualTo _holdSector}}) then {
                    private _d = (leader (_field # _forEachIndex)) distance2D _holdSector;
                    if ((_x # 1) isEqualTo "DEFEND" && {(_threatSectors param [_x # 2,objNull]) isEqualTo _holdSector}) then {_d = _d - 1000;};
                    if (_d < _distance) then {_distance = _d;_best = _forEachIndex;};
                };
            } forEach _plan;
            if (_best >= 0) then {_plan set [_best,[(_plan # _best) # 0,"CONSOLIDATE",-1]];};
        };
        private _attackers = [];
        {
            _x params ["_key", "_kind", "_ti"];
            private _g = _field # _forEachIndex;
            if (_kind != "MANUAL") then {_g setVariable ["NeroWL_counterObjective",if (_kind isEqualTo "ATTACK") then {_counterTarget} else {objNull}];};
            private _sector = switch (_kind) do {
                case "DEFEND": {_threatSectors # _ti};
                case "RESERVE": {_reserveSector};
                case "CONSOLIDATE": {_holdSector};
                default {_target};
            };
            if (_kind isEqualTo "ATTACK") then {_attackers pushBack [if (isNull _target) then {0} else {(leader _g) distance2D _target}, _g];};
            private _old = _g getVariable ["NeroWL_rulesMission", []];
            if (_kind != "MANUAL" && {(!((_old param [0, ""]) isEqualTo _kind) || {!((_old param [1, objNull]) isEqualTo _sector)})}) then {
                /* Assignment changes must not leave the old CQB loop attacking
                 * while the fair planning queue has not reached this group yet. */
                if (((_g getVariable ["NeroWL_rulesPhase",[]]) param [0,""]) isEqualTo "ASSAULT") then {
                    [_g,"HOLD",getPosATL (leader _g),"DEFEND","AUTONOMY"] call NeroAI_fnc_executeMacro;
                };
                _g setVariable ["NeroWL_rulesMission", [_kind, _sector, if (isNull _sector) then {[]} else {getPosATL _sector}, _now]];
                _g setVariable ["NeroWL_rulesPhase", nil];
                _g setVariable ["NeroAI_forcePlan", true, true];
                ["INFO", format ["RULES %1 %2 -> %3 %4.", _tag, _g getVariable ["NeroAI_callsign", groupId _g], _kind,
                    if (isNull _sector) then {"(ждёт цель Warlords)"} else {[_sector] call _fnc_name}]] call NeroAI_fnc_log;
            };
        } forEach _plan;

        /* Envelopment: attackers ordered by distance get alternating approach
         * bearings; about half of them must gather before the assault (max 3). */
        private _offsets = [0, -45, 45, -80, 80];
        private _ordered = [];
        private _pool = +_attackers;
        while {_pool isNotEqualTo []} do {
            private _bi = 0;
            { if ((_x # 0) < ((_pool # _bi) # 0)) then {_bi = _forEachIndex;}; } forEach _pool;
            _ordered pushBack ((_pool deleteAt _bi) # 1);
        };
        { _x setVariable ["NeroWL_rulesApproach", _offsets # (_forEachIndex mod 5)]; } forEach _ordered;
        private _readyFoot = 0;private _staged = 0;private _readyAT = 0;private _stagedStrength = 0;
        private _stageReach = if (isNull _target) then {480} else {(([_target] call _fnc_radius) + 300) min 480};
        private _sideIntel = (NeroAI_sharedIntel getOrDefault [_tag,[]]) select {(_now - (_x param [3,-1e6])) <= 120};
        _sideIntel = [_sideIntel] call NeroAI_fnc_rulesUniqueIntel;
        private _knownArmour = !isNull _target && {(_sideIntel findIf {
            private _type = _x param [0,""];
            _type isEqualType "" && {(_x param [1,[0,0]]) distance2D _target <= 900} &&
            {_type isKindOf "Tank" || {_type isKindOf "Wheeled_APC_F"} || {_type isKindOf "Tracked_APC_F"}}
        }) >= 0};
        private _knownHeavy = _knownArmour && {(_sideIntel findIf {
            private _type = _x param [0,""];
            (_x param [1,[0,0]]) distance2D _target <= 900 && {_type isKindOf "Tank"}
                && {getNumber (configFile >> "CfgVehicles" >> _type >> "transportSoldier") < 4}
        }) >= 0};
        private _atIndex = if (_knownHeavy) then {5} else {4};
        private _freshRecon = false;
        private _opKey = "NeroWL_rulesOperation_" + _tag;
        private _previous = missionNamespace getVariable [_opKey,["","",_now]];
        private _targetId = if (isNull _target) then {""} else {netId _target};
        private _started = if ((_previous # 0) isEqualTo _targetId) then {_previous # 2} else {_now};
        private _slotsKey = "NeroWL_rulesSlots_" + _tag;
        private _slots = if ((_previous # 0) isEqualTo _targetId) then {missionNamespace getVariable [_slotsKey,createHashMap]} else {createHashMap};
        private _ids = _ordered apply {netId _x};
        {if (!(_x in _ids)) then {_slots deleteAt _x;};} forEach (keys _slots);
        {
            private _g = _x;private _facts = [_g] call NeroAI_fnc_rulesCombatFacts;
            private _role = if (_facts # 3) then {if ((_facts # _atIndex) > 0 && {_knownArmour}) then {"ANTI_TANK"} else {"FIRE_SUPPORT"}} else {"ASSAULT"};
            _g setVariable ["NeroWL_rulesCombatRole",_role];
            if (_facts # 2 && {_role isEqualTo "ASSAULT"}) then {
                _readyFoot = _readyFoot + 1;
                if (!isNull _target && {(leader _g) distance2D _target <= _stageReach + 150}) then {
                    _staged = _staged + 1;_stagedStrength = _stagedStrength + (_facts # 0);
                    if (_now - (_g getVariable ["NeroWL_rulesObservedAt",-1e6]) <= 30) then {_freshRecon = true;};
                };
            };
            if (!isNull _target && {(leader _g) distance2D _target <= _stageReach + 300}) then {_readyAT = _readyAT + (_facts # _atIndex);};
            private _id = netId _g;
            if ((_slots getOrDefault [_id,-1]) < 0) then {
                private _slot = 0;private _taken = (keys _slots) apply {_slots get _x};
                while {_slot in _taken} do {_slot = _slot + 1;};
                _slots set [_id,_slot];
            };
            _g setVariable ["NeroWL_rulesAssaultSlot",_slots get _id];
        } forEach _ordered;
        /* A dispatched responder is reserved from reallocation, but its actual
         * nearby AT capacity can still support this operation. */
        {
            private _g = _x;private _support = _g getVariable ["NeroAI_supporting",[]];
            if (count _support >= 3 && {_now - (_support # 2) < 180}
                && {!(_g getVariable ["NeroAI_playerHold",false])} && {_now >= (_g getVariable ["NeroAI_manualOrderUntil",0])}
                && {_now >= (_g getVariable ["NeroWL_logisticsUntil",0])} && {_now >= (_g getVariable ["NeroAI_purchaseHoldUntil",0])}
                && {!isNull _target} && {(leader _g) distance2D _target <= _stageReach + 300}
                && {(_support # 1) distance2D _target <= _stageReach + 300}) then {
                _readyAT = _readyAT + (([_g] call NeroAI_fnc_rulesCombatFacts) # _atIndex);
            };
        } forEach _field;
        missionNamespace setVariable [_slotsKey,_slots];
        private _needed = (((ceil (_readyFoot * 0.5)) max (_readyFoot min 2)) max 1) min 3;
        missionNamespace setVariable ["NeroWL_rulesNeed_" + _tag,_needed];
        private _known = if (isNull _target) then {0} else {[_side,_target] call _fnc_known};
        private _operation = [_readyFoot,_staged,_needed,_known,_freshRecon,_now-_started,_captureHold,_knownArmour,_readyAT,_stagedStrength] call NeroAI_fnc_rulesOperation;
        private _stage = _operation # 0;
        missionNamespace setVariable [_opKey,[_targetId,_stage,_started,_known,_readyFoot,_staged,_needed]];
        if ((_previous # 0) != _targetId || {(_previous # 1) != _stage}) then {
            ["INFO",format ["OPERATION %1 %2 ready=%3 staged=%4/%5 AT=%6 (%7).",_tag,_stage,_readyFoot,_staged,_needed,_readyAT,_operation # 1]] call NeroAI_fnc_log;
            {if (((_plan # _forEachIndex) # 1) != "MANUAL") then {_x setVariable ["NeroAI_forcePlan",true,true];};} forEach _field;
        };

        /* 5. Roles: fighter cover once enemy aircraft are seen (aviation allowed). */
        if (!_hqThreat && {(missionNamespace getVariable ["NeroAI_airEnabled", true])} && {(_now - (missionNamespace getVariable ["NeroWL_rulesRoleReview_" + _tag, -1e6])) > 120}) then {
            missionNamespace setVariable ["NeroWL_rulesRoleReview_" + _tag, _now];
            private _air = {
                private _t = _x param [0, ""];
                _t isEqualType "" && {_t isKindOf "Air"} && {(_now - (_x param [3, -1e6])) <= 300}
            } count (NeroAI_sharedIntel getOrDefault [_tag, []]);
            if (_air > 0 && {(_groups findIf {(_x getVariable ["NeroWL_role", ""]) isEqualTo "AIR_SUPERIORITY"}) < 0}) then {
                private _wls = missionNamespace getVariable ["BIS_WL_allWarlords", []];
                private _pick = _field findIf {
                    ((_x getVariable ["NeroWL_role", "INFANTRY"]) in ["INFANTRY", "RECON"]) && {((units _x) findIf {_x in _wls}) >= 0}
                    && {!(_x getVariable ["NeroAI_playerHold",false])} && {_now >= (_x getVariable ["NeroAI_manualOrderUntil",0])}
                    && {_now >= (_x getVariable ["NeroWL_logisticsUntil",0])} && {_now >= (_x getVariable ["NeroAI_purchaseHoldUntil",0])}
                    && {!(((_x getVariable ["NeroWL_rulesMission",[]]) param [0,""]) in ["DEFEND","CONSOLIDATE"])}
                    && {private _support = _x getVariable ["NeroAI_supporting",[]];count _support < 3 || {_now - (_support # 2) >= 180}}
                };
                if (_pick >= 0) then {
                    private _g = _field # _pick;
                    _g setVariable ["NeroWL_role", "AIR_SUPERIORITY", true];
                    ["INFO", format ["RULES %1 %2 role -> AIR_SUPERIORITY (%3 enemy aircraft seen).", _tag, _g getVariable ["NeroAI_callsign", groupId _g], _air]] call NeroAI_fnc_log;
                };
            };
        };
    };
} forEach (_sides select {_x in [west, east]});
missionNamespace setVariable ["NeroWL_rulesSectorIntel", _memory];

if (_voteOnly) exitWith {};

/* Partisans and sector garrisons: hold the nearest own sector. */
{
    private _g = _y;
    if ([_g] call NeroAI_fnc_validateGroup && {(side _g) isEqualTo resistance || {_g getVariable ["NeroWL_garrison", false]}}) then {
        private _sector = _g getVariable ["NeroWL_garrisonSector", objNull];
        if (isNull _sector) then {
            private _own = _sectors select {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo (side _g) && {(_x distance2D (leader _g)) < 2500}};
            if (_own isNotEqualTo []) then {
                _sector = _own # 0;
                { if ((_x distance2D (leader _g)) < (_sector distance2D (leader _g))) then {_sector = _x;}; } forEach _own;
            };
        };
        private _kind = if (isNull _sector) then {"NONE"} else {"GARRISON"};
        private _old = _g getVariable ["NeroWL_rulesMission", []];
        if (!((_old param [0, ""]) isEqualTo _kind) || {!((_old param [1, objNull]) isEqualTo _sector)}) then {
            /* Assignment changes must not leave the old CQB loop attacking
                 * while the fair planning queue has not reached this group yet. */
                if (((_g getVariable ["NeroWL_rulesPhase",[]]) param [0,""]) isEqualTo "ASSAULT") then {
                    [_g,"HOLD",getPosATL (leader _g),"DEFEND","AUTONOMY"] call NeroAI_fnc_executeMacro;
                };
                _g setVariable ["NeroWL_rulesMission", [_kind, _sector, if (isNull _sector) then {[]} else {getPosATL _sector}, _now]];
            _g setVariable ["NeroAI_forcePlan", true, true];
        };
    };
} forEach NeroAI_activeGroups;
