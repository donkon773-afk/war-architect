/* 11.10 Tactical AI without LLM — one squad's plan, called by
 * fn_tacticalAutonomy in place of the LLM request (same candidates, same
 * event triggers: contact, losses, ambush, stall, forced replan).
 *
 * Facts come from the squad's own contacts, its side's shared intel and the
 * mission the strategist (fn_rulesCommander) assigned; fn_rulesChooseBehaviour
 * decides; the decision runs through fn_executeMacro as source AUTONOMY, i.e.
 * the same whitelist and guards as an LLM plan (player priority, logistics
 * windows, boarding-first, objective / own-sector targets, fire safety).
 *
 *   [_group, _reason, _intelRows] call NeroAI_fnc_rulesGroupPlan -> [ok, summary] */
params ["_group", ["_reason", ""], ["_intelRows", []]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};
private _now = diag_tickTime;
if (_group getVariable ["NeroAI_playerHold",false] || {_now < (_group getVariable ["NeroAI_manualOrderUntil",0])}) exitWith {[false,"Действует приказ игрока."]};
private _leader = leader _group;
private _side = side _group;
private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
private _living = (units _group) select {alive _x};
private _initial = (_group getVariable ["NeroAI_initialStrength", count _living]) max (count _living);

/* ---- mission and objective -------------------------------------------- */
private _mission = _group getVariable ["NeroWL_rulesMission", []];
private _kind = _mission param [0, "NONE"];
private _sector = _mission param [1, objNull];
if (_kind isEqualTo "ATTACK") then {
    /* The live native objective is authoritative for attackers. */
    _sector = [_group] call NeroAI_fnc_wlGroupObjective;
};
if !(_sector isEqualType objNull) then {_sector = objNull;};
private _targetPos = if (isNull _sector) then {_mission param [2, []]} else {getPosATL _sector};
private _hasTarget = _targetPos isEqualType [] && {count _targetPos >= 2};
private _radius = 150;
if (!isNull _sector) then {
    private _size = _sector getVariable ["Size", 300];
    if !(_size isEqualType 0) then {_size = 300;};
    _radius = ((_size / 2) max 75) min 400;
};
private _distTarget = if (_hasTarget) then {_leader distance2D _targetPos} else {-1};
private _sectorName = "";
if (!isNull _sector) then {
    _sectorName = _sector getVariable ["Name", ""];
    if !(_sectorName isEqualType "") then {_sectorName = "";};
    if ((toUpper _sectorName) select [0, 4] isEqualTo "STR_") then {_sectorName = localize _sectorName;};
    if (_sectorName isEqualTo "") then {_sectorName = mapGridPosition _sector;};
};

/* ---- contacts ---------------------------------------------------------- */
private _contacts = 0;
private _nearest = 1e9;
private _nearestPos = [];
private _armour = 0;
private _heavyArmour = false;
{
    private _p = _x param [1, []];
    if (_p isEqualType [] && {count _p >= 2}) then {
        private _d = _leader distance2D _p;
        if (_d <= 600) then {_contacts = _contacts + 1;};
        if (_d < _nearest) then {_nearest = _d; _nearestPos = [_p # 0, _p # 1, 0];};
        private _t = _x param [0, ""];
        if (_d <= 900 && {_t isEqualType ""} && {_t isKindOf "Tank" || {_t isKindOf "Wheeled_APC_F"} || {_t isKindOf "Tracked_APC_F"}}) then {
            _armour = _armour + 1;
            if (_t isKindOf "Tank" && {getNumber (configFile >> "CfgVehicles" >> _t >> "transportSoldier") < 4}) then {_heavyArmour = true;};
        };
    };
} forEach _intelRows;
private _shared = ((missionNamespace getVariable ["NeroAI_sharedIntel", createHashMap]) getOrDefault [str _side, []]) select {(_now - (_x param [3, -1e6])) <= 120};
_shared = [_shared] call NeroAI_fnc_rulesUniqueIntel;
/* Densest known cluster (150 m) for indirect fire. */
private _cluster = 0;
private _clusterPos = [];
{
    private _p = _x param [1, []];
    if (_p isEqualType [] && {count _p >= 2}) then {
        private _n = {((_x param [1, [0, 0]]) distance2D _p) <= 150} count _shared;
        if (_n > _cluster) then {_cluster = _n; _clusterPos = [_p # 0, _p # 1, 0];};
    };
} forEach _shared;
private _clusterDist = if (_clusterPos isEqualTo []) then {1e9} else {_leader distance2D _clusterPos};
private _enemiesInTarget = if (_hasTarget) then {{((_x param [1, [0, 0]]) distance2D _targetPos) <= (_radius + 150)} count _shared} else {0};
private _contactsInTarget = if (_hasTarget) then {
    ({((_x param [1, [0, 0]]) distance2D _targetPos) <= _radius} count _shared)
    + ({((_x param [1, [0, 0]]) distance2D _targetPos) <= _radius} count _intelRows)
} else {0};

/* ---- capabilities ------------------------------------------------------ */
private _caps = [_group] call NeroAI_fnc_analyzeGroupCapabilities;
private _cap = {params ["_k"]; private _i = _caps find _k; if (_i < 0) then {0} else {_caps param [_i + 1, 0]}};
private _combat = [_group] call NeroAI_fnc_rulesCombatFacts;
private _antiTank = _combat # (if (_heavyArmour) then {5} else {4});
_group setVariable ["NeroWL_rulesSupportNeed",if (_armour > 0) then {if (_heavyArmour) then {"HEAVY_AT"} else {"LIGHT_AT"}} else {"поддержка"}];
private _armed = ["armedVehicles"] call _cap;
private _mountedArmour = (["armour"] call _cap) > 0 && {(["mounted"] call _cap) >= ((count _living) min 2)};
if (_kind isEqualTo "ATTACK" && {_hasTarget} && {[_group,_targetPos] call NeroAI_fnc_dismountAssault}) exitWith {[true,"Остановка транспорта и подтверждение высадки перед пешим штурмом."]};

/* Side fire support (cached per side for 10 s). */
private _fireKey = format ["NeroWL_rulesFire_%1", _side];
private _fireCache = missionNamespace getVariable [_fireKey, [-1e6, ""]];
if ((_now - (_fireCache # 0)) > 10) then {
    private _kindReady = "";
    /* Same selection as fn_requestFireSupport: a crewed friendly tube with artillery ammunition. */
    {
        if (alive _x && {canFire _x} && {((crew _x) findIf {alive _x}) >= 0} && {([_x] call NeroAI_fnc_getVehicleSide) isEqualTo _side} && {(getArtilleryAmmo [_x]) isNotEqualTo []}) exitWith {
            _kindReady = if (_x isKindOf "StaticMortar" || {"mortar" in (toLower (typeOf _x))}) then {"MORTAR"} else {"ARTILLERY"};
        };
    } forEach vehicles;
    _fireCache = [_now, _kindReady];
    missionNamespace setVariable [_fireKey, _fireCache];
};
private _fireKind = _fireCache # 1;

/* Purse for reinforcements: own warlord, above reserve plus a squad's price. */
private _wls = missionNamespace getVariable ["BIS_WL_allWarlords", []];
private _wl = (_living select {_x in _wls}) param [0, objNull];
private _cp = if (isNull _wl) then {0} else {_wl getVariable ["BIS_WL_funds", 0]};
if !(_cp isEqualType 0) then {_cp = 0;};
private _canBuyInfantry = !isNull _wl && {_cp >= ((missionNamespace getVariable ["NeroAI_purchaseReserveCP", 1500]) + 800)};

/* ---- phase and partners ------------------------------------------------ */
private _sectorId = if (isNull _sector) then {""} else {netId _sector};
private _phaseState = _group getVariable ["NeroWL_rulesPhase", ["", _now, _sectorId]];
if !((_phaseState param [2, ""]) isEqualTo _sectorId) then {_phaseState = ["", _now, _sectorId];};
private _phase = _phaseState # 0;
private _stageWait = if (_phase isEqualTo "STAGE") then {_now - (_phaseState # 1)} else {0};
private _stageDist = (_radius + 300) min 480;
private _partners = 0;
if (_kind isEqualTo "ATTACK" && {_hasTarget}) then {
    {
        private _m = _y getVariable ["NeroWL_rulesMission", []];
        if ((side _y) isEqualTo _side && {(_m param [0, ""]) isEqualTo "ATTACK"} && {(_m param [1,objNull]) isEqualTo _sector} && {[_y] call NeroAI_fnc_validateGroup}
            && {!(_y getVariable ["NeroAI_playerHold",false])} && {_now >= (_y getVariable ["NeroAI_manualOrderUntil",0])}
            && {_now >= (_y getVariable ["NeroWL_logisticsUntil",0])} && {_now >= (_y getVariable ["NeroAI_purchaseHoldUntil",0])}
            && {private _supporting = _y getVariable ["NeroAI_supporting",[]];count _supporting < 3 || {_now - (_supporting # 2) >= 180}}
            && {((leader _y) distance2D _targetPos) <= (_stageDist + 150)}) then {
            private _partner = [_y] call NeroAI_fnc_rulesCombatFacts;
            if (_partner # 2 && {!(_partner # 3)} && {(_y getVariable ["NeroWL_rulesCombatRole","ASSAULT"]) isEqualTo "ASSAULT"}) then {_partners = _partners + 1;};
        };
    } forEach NeroAI_activeGroups;
};
private _needed = missionNamespace getVariable [format ["NeroWL_rulesNeed_%1", _side], 1];
private _posture = missionNamespace getVariable [format ["NeroWL_rulesPosture_%1", _side], 1];
private _ambush = _reason isEqualTo "ЗАСАДА";
private _operation = missionNamespace getVariable [format ["NeroWL_rulesOperation_%1",_side],["","PREPARE",_now]];
private _operationStage = if ((_operation # 0) isEqualTo _sectorId) then {_operation # 1} else {"PREPARE"};
private _combatRole = _group getVariable ["NeroWL_rulesCombatRole","ASSAULT"];

private _supportVehicles = [];
{private _v = objectParent _x;if (!isNull _v && {_v isKindOf "LandVehicle"} && {group driver _v isEqualTo _group}) then {_supportVehicles pushBackUnique _v;};} forEach _living;
if (_kind isEqualTo "ATTACK" && {_hasTarget} && {_combatRole in ["FIRE_SUPPORT","ANTI_TANK"]}) then {
    {[_x,_group,_targetPos,_combatRole,_targetPos getDir (getPosATL _x)] call NeroAI_fnc_vehicleCombatPosition;} forEach _supportVehicles;
};
private _supportReached = _hasTarget && {_supportVehicles isNotEqualTo []} && {(_supportVehicles findIf {
    private _goal = _x getVariable ["NeroWL_fireObjective",[]];private _position = (_x getVariable ["NeroWL_firePosition",[[],false,-1e9]]) # 0;
    count _goal < 2 || {count _position < 2} || {_goal distance2D _targetPos > 60} || {_x distance2D _position > 65}
}) < 0};
private _decision = [
    _kind, if (_combat # 3) then {_combat param [9,count _living]} else {_combat # 0}, _initial, _contacts, _nearest, _armour, _antiTank, _armed, _ambush,
    _distTarget, _radius, _phase, _stageWait, _partners, _needed, _fireKind != "",
    _cluster, _clusterDist, _posture, _enemiesInTarget, _canBuyInfantry, _contactsInTarget,
    _combat # 2,_operationStage,_combatRole,_supportReached
] call NeroAI_fnc_rulesChooseBehaviour;
_decision params ["_what", "_why", "_extras"];

/* ---- geometry ---------------------------------------------------------- */
private _sectors = (missionNamespace getVariable ["BIS_WL_sectors", []]) select {_x isEqualType objNull && {!isNull _x}};
private _own = _sectors select {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _side};
private _fnc_dry = {
    params ["_centre", "_dist", "_bearing"];
    private _p = _centre getPos [_dist, _bearing];
    private _i = 1;
    while {surfaceIsWater _p && {_i <= 7}} do {
        _p = _centre getPos [_dist, _bearing + (if (_i mod 2 == 0) then {25} else {-25}) * ceil (_i / 2)];
        _i = _i + 1;
    };
    [_p # 0, _p # 1, 0]
};
private _approach = 0;
if (_hasTarget) then {
    /* From the own sector nearest the objective (the friendly lines), plus the
     * strategist's envelopment offset for this squad. */
    private _origin = getPosATL _leader;
    private _lines = _own select {(_x distance2D _targetPos) > 150};
    if (_lines isNotEqualTo []) then {
        private _o = _lines # 0;
        { if ((_x distance2D _targetPos) < (_o distance2D _targetPos)) then {_o = _x;}; } forEach _lines;
        _origin = getPosATL _o;
    };
    _approach = (_targetPos getDir _origin) + (_group getVariable ["NeroWL_rulesApproach", 0]);
};
private _urban = false;
if (_hasTarget) then {
    private _cached = if (isNull _sector) then {-1} else {_sector getVariable ["NeroWL_rulesUrban", -1]};
    if (_cached isEqualTo -1) then {
        _cached = if (count ((nearestObjects [_targetPos, ["House", "Building"], 150]) select {count (_x buildingPos -1) > 1}) >= 6) then {1} else {0};
        if (!isNull _sector) then {_sector setVariable ["NeroWL_rulesUrban", _cached];};
    };
    _urban = _cached isEqualTo 1;
};
private _lambs = !isNil "lambs_wp_fnc_taskHunt";

/* ---- execution --------------------------------------------------------- */
private _done = [];
private _acted = false;
private _exec = {
    params ["_type", ["_pos", []], ["_arg", ""]];
    private _r = [_group, _type, _pos, _arg, "AUTONOMY"] call NeroAI_fnc_executeMacro;
    if (_r # 0) then {_acted = true;};
    _done pushBack format ["%1%2=%3", _type, if (_arg isEqualTo "") then {""} else {"/" + _arg}, if (_r # 0) then {"ok"} else {_r # 1}];
    _r
};
/* The same order to the same place is not re-issued inside its window:
 * restarting a template or a route every tick would freeze the squad. */
private _grid = if (_what in ["COUNTER", "BREAK"]) then {200} else {50};
private _keyPos = switch (_what) do {
    case "ADVANCE"; case "STAGE": {[_targetPos, _stageDist, _approach] call _fnc_dry};
    case "SUPPORT_MOVE": {[_targetPos,(_radius * 0.75) min 300,_approach] call _fnc_dry};
    case "SELF_DEFEND"; case "FIRE_SUPPORT": {getPosATL _leader};
    case "COUNTER": {_nearestPos};
    default {if (_hasTarget) then {_targetPos} else {[]}};
};
private _key = format ["%1/%2/%3/%4@%5",_what,_kind,_combatRole,_operationStage,if (_keyPos isEqualTo []) then {"-"} else {format ["%1,%2",round ((_keyPos # 0)/_grid),round ((_keyPos # 1)/_grid)]}];
private _window = switch (_what) do {
    case "ADVANCE"; case "DEFEND_MOVE": {60};
    case "COUNTER"; case "BREAK": {90};
    default {120};
};
private _last = _group getVariable ["NeroWL_rulesLastOrder", ["", -1e6]];
private _repeat = ((_last # 0) isEqualTo _key) && {(_now - (_last # 1)) < _window};
private _newPhase = _phase;

if (!_repeat) then {
    switch (_what) do {
        case "ADVANCE"; case "SUPPORT_MOVE": {
            private _r = ["ADVANCE", _keyPos] call _exec;
            if (_r # 0) then {_newPhase = "APPROACH"; [_group, "ADVANCE", _sectorName] call NeroAI_fnc_rulesRadio;};
        };
        case "STAGE": {
            private _r = ["HOLD", _keyPos, "DEFEND"] call _exec;
            if (_r # 0 && {_phase != "STAGE"}) then {_newPhase = "STAGE"; _phaseState set [1, _now]; [_group, "STAGE", _sectorName] call NeroAI_fnc_rulesRadio;};
        };
        case "ASSAULT": {
            /* Buildings: infantry clears them (CQB); a mounted armour squad
             * supports from the edge; known defenders in the open: RUSH. */
            private _tactic = "";
            private _aim = _targetPos;
            if (_urban && {!_mountedArmour}) then {
                _tactic = "CQB";
                _aim = [_targetPos,_radius,_group getVariable ["NeroWL_rulesAssaultSlot",0]] call NeroAI_fnc_rulesAssaultPoint;
                if (surfaceIsWater _aim) then {_aim = _targetPos;};
            } else {
                if (_mountedArmour && {_urban}) then {_aim = [_targetPos, (_radius * 0.6) min 200, _approach] call _fnc_dry;} else {
                    if (_enemiesInTarget > 0) then {_tactic = "RUSH";};
                };
            };
            private _r = ["ASSAULT", _aim, _tactic] call _exec;
            if (_r # 0) then {
                if (_phase != "ASSAULT") then {[_group, "ASSAULT", _sectorName] call NeroAI_fnc_rulesRadio;};
                _newPhase = "ASSAULT";
            };
        };
        case "COUNTER": {
            if (_nearestPos isEqualTo []) then {_nearestPos = if (_clusterPos isEqualTo []) then {getPosATL _leader} else {_clusterPos};};
            ["SET_ROE", [], "OPEN_FIRE"] call _exec;
            _group setCombatBehaviour "COMBAT";
            if (_lambs) then {["RECON", _nearestPos, "HUNT"] call _exec;};
            [_group, "COUNTER"] call NeroAI_fnc_rulesRadio;
        };
        case "BREAK"; case "REGROUP": {
            /* Fall back to the nearest own sector that does not lie towards the
             * enemy; the HQ when nothing else is left. */
            private _threatDir = if (_nearestPos isEqualTo []) then {-1} else {_leader getDir _nearestPos};
            private _best = objNull;
            private _bestD = 1e9;
            {
                private _d = _leader distance2D _x;
                private _towards = _threatDir >= 0 && {(abs (((_leader getDir _x) - _threatDir + 540) mod 360 - 180)) < 60} && {_d > 250};
                if (!_towards && {_d < _bestD}) then {_best = _x; _bestD = _d;};
            } forEach _own;
            if (isNull _best && {_own isNotEqualTo []}) then {_best = _own # 0; { if ((_leader distance2D _x) < (_leader distance2D _best)) then {_best = _x;}; } forEach _own;};
            if (!isNull _best) then {
                private _bn = _best getVariable ["Name", ""];
                if (!(_bn isEqualType "") || {_bn isEqualTo ""}) then {_bn = mapGridPosition _best;};
                if ((toUpper _bn) select [0, 4] isEqualTo "STR_") then {_bn = localize _bn;};
                ["RETREAT", getPosATL _best] call _exec;
                [_group, "BREAK", _bn] call NeroAI_fnc_rulesRadio;
            } else {
                ["SET_ROE", [], "RETURN_FIRE"] call _exec;
            };
            _newPhase = "";
        };
        case "DEFEND_MOVE": {
            if (_hasTarget) then {
                private _r = ["ADVANCE", _targetPos] call _exec;
                if (_r # 0) then {[_group, if (_kind isEqualTo "RESERVE") then {"RESERVE"} else {"DEFEND_MOVE"}, _sectorName] call NeroAI_fnc_rulesRadio;};
            };
        };
        case "DEFEND": {
            ["HOLD", _targetPos, if (_urban) then {"GARRISON"} else {"DEFEND"}] call _exec;
            [_group, "DEFEND", _sectorName] call NeroAI_fnc_rulesRadio;
        };
        case "RESERVE": {
            ["HOLD", _targetPos, "DEFEND"] call _exec;
        };
        case "SELF_DEFEND"; case "FIRE_SUPPORT": {
            ["HOLD",getPosATL _leader,"DEFEND"] call _exec;
            _newPhase = "";
        };
        default {};
    };
    if (_what != "IDLE" && {_acted}) then {_group setVariable ["NeroWL_rulesLastOrder", [_key, _now]];};
};

/* Extras have their own cooldowns (and the macro functions their own guards). */
if ("FIRE" in _extras && {_fireKind != ""} && {_clusterPos isNotEqualTo []} && {(_now - (_group getVariable ["NeroWL_rulesFireAt", -1e6])) > 150}) then {
    _group setVariable ["NeroWL_rulesFireAt", _now];
    ["REQUEST_FIRE", _clusterPos, _fireKind] call _exec;
};
if ("RECON" in _extras && {_hasTarget} && {(_now - (_group getVariable ["NeroWL_rulesReconAt", -1e6])) > 120}) then {
    _group setVariable ["NeroWL_rulesReconAt", _now];
    ["RECON", _targetPos] call _exec;
};
if ("REQUEST_SUPPORT" in _extras) then {["REQUEST_SUPPORT", getPosATL _leader] call _exec;};
if ("BUY_INFANTRY" in _extras && {(_now - (_group getVariable ["NeroWL_rulesBuyAt", -1e6])) > 180}) then {
    _group setVariable ["NeroWL_rulesBuyAt", _now];
    ["BUY", [], "INFANTRY"] call _exec;
};
if ("SHARE_INTEL" in _extras) then {["SHARE_INTEL"] call _exec;};

if (_newPhase != _phase) then {_phaseState set [0, _newPhase]; if (_newPhase != "STAGE") then {_phaseState set [1, _now];};};
_group setVariable ["NeroWL_rulesPhase", _phaseState];
_group setVariable ["NeroWL_rulesDecision", [_now, _what, _why, _done]];
private _summary = format ["RULES %1 %2/%3 -> %4 (%5)%6: %7", _callsign, _kind, if (_newPhase isEqualTo "") then {"-"} else {_newPhase}, _what, _why,
    if (_repeat) then {" [повтор не нужен]"} else {""}, if (_done isEqualTo []) then {"—"} else {_done joinString ", "}];
if (!_repeat || {_done isNotEqualTo []}) then {["INFO", _summary] call NeroAI_fnc_log;};
[true, _summary]
