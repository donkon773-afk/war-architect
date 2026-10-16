params ["_group", "_type", ["_position", []], ["_argument", ""], ["_source", "PLAYER"]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};

if !(_type isEqualType "") exitWith {[false, "Неверный тип действия."]};
if !(_position isEqualType []) exitWith {[false, "Неверный тип позиции."]};
if !(_argument isEqualType "") exitWith {[false, "Неверный тип аргумента."]};
if !(_source isEqualType "") exitWith {[false, "Неверный источник."]};

_type = toUpper _type;
_source = toUpper _source;

private _allowedActions = [
    "ADVANCE", "ASSAULT", "HOLD", "RETREAT", "RECON", "REQUEST_FIRE",
    "BOARD", "DISEMBARK", "REPAIR", "SET_ROE", "SET_SECTOR", "REPORT", "CANCEL",
    "REQUEST_SUPPORT", "SHARE_INTEL", "NEGOTIATE", "DESIGNATE", "AUTONOMY", "BUY", "ASSIGN_ROLE", "AIR_TASK"
];
if !(_type in _allowedActions) exitWith {
    ["WARN", format ["executeMacro: Unknown action type %1 for group %2.", _type, _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [false, "Неизвестное действие."]
};

if (count _position > 0) then {
    if (!((count _position in [2, 3]) && {({_x isEqualType 0} count _position) isEqualTo count _position})) then {
        _position = [];
    };
};

if (_type isEqualTo "SET_ROE") then {
    _argument = toUpper _argument;
    if !(_argument in ["HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"]) exitWith {
        _argument = "";
    };
};
if (_type isEqualTo "SET_ROE" && {_argument isEqualTo ""}) exitWith {
    ["WARN", format ["executeMacro: Invalid SET_ROE argument for group %1.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [false, "Неизвестные правила открытия огня."]
};

if (_type isEqualTo "REQUEST_FIRE") then {
    _argument = toUpper _argument;
    if !(_argument in ["ARTILLERY", "MORTAR", "CAS"]) exitWith {
        _argument = "";
    };
};
if (_type isEqualTo "REQUEST_FIRE" && {_argument isEqualTo ""}) exitWith {
    ["WARN", format ["executeMacro: Invalid REQUEST_FIRE argument for group %1.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [false, "Неизвестный тип артподдержки."]
};

if (_type isEqualTo "BUY") then {
    _argument = toUpper _argument;
    if !(_argument in ["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"]) exitWith {
        _argument = "";
    };
};
if (_type isEqualTo "BUY" && {_argument isEqualTo ""}) exitWith {
    ["WARN", format ["executeMacro: Invalid BUY argument for group %1.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [false, "Неизвестный класс техники."]
};

if (_type == "ASSIGN_ROLE" && {!(_argument in ["INFANTRY","MECHANIZED","ARMOR","RECON","AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"])}) exitWith {[false,"Недопустимая роль."]};
if (_type == "AIR_TASK" && {!(_argument in ["CAS","RECON","TRANSPORT","INTERCEPT","ESCORT"])}) exitWith {[false,"Недопустимая задача авиации."]};
private _now = diag_tickTime;
private _manualUntil = _group getVariable ["NeroAI_manualOrderUntil", 0];
private _manualHold = _group getVariable ["NeroAI_playerHold", false];
private _blockedByManual = !(_source in ["PLAYER", "PLAYER_DEFERRED", "MOBILITY_RETRY"]) && {_manualHold || {_now < _manualUntil}};
if (_blockedByManual) exitWith {[false, "Автономное действие отложено: действует прямой приказ игрока."]};
/* Rules-mode safety gate covers support/continuation paths as well as plans.
 * Literal player orders keep their existing priority and semantics. */
if (missionNamespace getVariable ["NeroAI_rulesMode",false] && {_type isEqualTo "ASSAULT"} &&
    {!(_source in ["PLAYER","PLAYER_DEFERRED","MOBILITY_RETRY"])}) then {
    private _facts = [_group] call NeroAI_fnc_rulesCombatFacts;
    if !(_facts # 2) then {_blockedByManual = true;};
};
if (_blockedByManual) exitWith {[false,"Штурм отменён: группа не готова к атаке."]};
if (!(_source in ["PLAYER","PLAYER_DEFERRED","MOBILITY_RETRY"]) && {_type in ["ADVANCE","ASSAULT","RETREAT","HOLD","CANCEL","DISEMBARK"]} && {_now < (_group getVariable ["NeroWL_logisticsUntil",0]) || {_now < (_group getVariable ["NeroAI_purchaseHoldUntil",0])}}) exitWith {[false,"Группа завершает доставку/посадку/воздушную перевозку; новый марш отложен."]};
// Recovery may only replay a still-active, fully resolved movement order.
// It must not refresh its timestamp, authority window or operation token.
if (_source isEqualTo "MOBILITY_RETRY") then {
    private _saved = _group getVariable ["NeroAI_lastPlayerOrder", []];
    if (_manualHold || {_now >= _manualUntil} || {count _saved < 4} ||
        {!(_type in ["ADVANCE", "ASSAULT", "RETREAT"])} ||
        {!((_saved # 0) isEqualTo _type)} || {!((_saved # 1) isEqualTo _position)}) then {
        _blockedByManual = true;
    };
};
if (_blockedByManual) exitWith {[false, "Повтор устаревшего приказа отклонён."]};
if (_source in ["PLAYER", "PLAYER_DEFERRED"]) then {
    if (_source isEqualTo "PLAYER") then {
        /* Release repair constraints before applying a newer player order.
         * The old worker sees its missing lease and cannot restore old orders. */
        private _repairVehicle = _group getVariable ["NeroWL_repairVehicle",objNull];
        if (!isNull _repairVehicle) then {
            private _lease = _repairVehicle getVariable ["NeroWL_repairLease",[]];
            if (count _lease >= 5 && {_group in [_lease # 0,_lease # 3]}) then {[_repairVehicle,_lease] call NeroAI_fnc_repairRelease;};
        };
        _group setVariable ["NeroAI_opToken", (_group getVariable ["NeroAI_opToken", 0]) + 1, true];
    };
    _group setVariable ["NeroAI_lastPlayerOrder", [_type, _position, _argument, _now], true];
    if (_type in ["ADVANCE", "ASSAULT", "RETREAT", "BOARD", "DISEMBARK", "REPAIR", "SET_SECTOR", "DESIGNATE"]) then {
        _group setVariable ["NeroAI_playerHold", false, true];
        _group setVariable ["NeroAI_manualOrderUntil", _now + 180, true];
    };
    if (_type isEqualTo "HOLD") then {
        _group setVariable ["NeroAI_playerHold", true, true];
        _group setVariable ["NeroAI_manualOrderUntil", 1e12, true];
    };
    if (_type isEqualTo "CANCEL") then {
        _group setVariable ["NeroAI_playerHold", true, true];
        _group setVariable ["NeroAI_manualOrderUntil", _now + 60, true];
    };
    if (_type isEqualTo "AUTONOMY") then {
        _group setVariable ["NeroAI_playerHold", false, true];
        _group setVariable ["NeroAI_manualOrderUntil", 0, true];
        _group setVariable ["NeroAI_lastPlayerOrder", [], true];
        _group setVariable ["NeroAI_playerVehicleDirective", "", true];
        _group setVariable ["NeroAI_autonomyMode", "FULL", true];
        _group setVariable ["NeroWL_vehicleService",false,true];
    };
    if (_type isEqualTo "BOARD") then {_group setVariable ["NeroAI_playerVehicleDirective", "BOARD", true];};
    if (_type isEqualTo "DISEMBARK") then {_group setVariable ["NeroAI_playerVehicleDirective", "DISEMBARK", true];};
    if (_type isEqualTo "SET_ROE") then {_group setVariable ["NeroAI_playerROE", _argument, true];};
    if (_type isEqualTo "ASSAULT") then {_group setVariable ["NeroAI_playerROE", "OPEN_FIRE", true];};
};
private _relativeParts = _argument splitString ":";
if (
    (count _relativeParts) isEqualTo 3 &&
    {(_relativeParts # 0) in ["DIR", "REL"]} &&
    {_type in ["ADVANCE", "ASSAULT", "RETREAT", "SET_SECTOR", "DESIGNATE"]}
) then {
    private _bearing = parseNumber (_relativeParts # 1);
    private _distance = ((parseNumber (_relativeParts # 2)) max 10) min 2000;
    if ((_relativeParts # 0) isEqualTo "REL") then {_bearing = _bearing + getDir (leader _group);};
    private _origin = getPosATL (leader _group);
    _position = [(_origin # 0) + sin _bearing * _distance, (_origin # 1) + cos _bearing * _distance, 0];
    _argument = "";
};
private _hasPosition = _position isEqualType [] && {count _position >= 2} && {(_position # 0) isEqualType 0} && {(_position # 1) isEqualType 0};
if (_hasPosition) then {
    _position = [(((_position # 0) max 0) min 100000), (((_position # 1) max 0) min 100000), 0];
};
private _members = (units _group) select {alive _x};
private _actionContext = if (_hasPosition) then {format [" @%1,%2", round (_position # 0), round (_position # 1)]} else {""};
if !(_argument isEqualTo "") then {
    _actionContext = _actionContext + format [" (%1)", _argument];
};
["ACTION", format ["Group %1 -> %2%3; members=%4.", _group getVariable ["NeroAI_callsign", groupId _group], _type, _actionContext, count _members]] call NeroAI_fnc_log;

// Anti-paralysis guard for autonomous marches. A model plan that points the
// group at its own current position clears the bridge grounded-filter but only
// makes the group jitter in place and tire out. Re-check the live distance,
// suppress a near-identical autonomous move reissued within a short window, and
// drop to LIMITED speed for an exhausted group instead of forcing a sprint.
private _marchSpeed = "FULL";
private _moveGuardResult = [];
private _autonomousSource = !(_source in ["PLAYER", "PLAYER_DEFERRED", "MOBILITY_RETRY"]);
if (_autonomousSource && {_type in ["ADVANCE","ASSAULT","HOLD","RETREAT"]} && {_group getVariable ["NeroWL_vehicleService",false]}) exitWith {[false,"Группа ожидает ремонт или прикрытие."]};
private _nativeTarget = if (_group getVariable ["NeroWL_garrison",false]) then {_group getVariable ["NeroWL_garrisonSector",objNull]} else {[_group] call NeroAI_fnc_wlGroupObjective};
if (_autonomousSource && {_group getVariable ["NeroWL_garrison",false]} && {_type in ["BUY","ASSIGN_ROLE","AIR_TASK","REQUEST_SUPPORT"]}) exitWith {[false,"Гарнизон управляет только своей обороной."]};
private _ownedWaiting = (_group getVariable ["BIS_WL_groupVehs", []]) select {
    !isNull _x && {alive _x} && {canMove _x} && {crew _x isEqualTo []}
};
if (_autonomousSource && {_type in ["ADVANCE", "ASSAULT"]} && {!(_ownedWaiting isEqualTo [])}) exitWith {
    [false, "Сначала посадка в купленную технику Warlords."]
};
/* 11.10 tactical AI without LLM: the strategist also defends, regroups and
 * falls back — an own sector (HQ included) is a legitimate target as well. */
private _ownSectorTarget = NeroAI_rulesMode && {_hasPosition} && {
    ((missionNamespace getVariable ["BIS_WL_sectors", []]) findIf {
        _x isEqualType objNull && {!isNull _x} && {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo (side _group)} && {(_position distance2D _x) <= 500}
    }) >= 0
};
private _supportDestination = _group getVariable ["NeroWL_supportDestination",[]];
private _supportSectorTarget = _source isEqualTo "SUPPORT" && {_hasPosition} && {count _supportDestination >= 3}
    && {_now < (_supportDestination # 1)} && {(_supportDestination # 0) distance2D _position < 35}
    && {!isNull (_supportDestination # 2)} && {alive (_supportDestination # 2)}
    && {(_supportDestination # 2) distance2D _position <= 250};
if (_autonomousSource && {_type in ["ADVANCE", "ASSAULT", "RETREAT"]} && {!_ownSectorTarget} && {!_supportSectorTarget} &&
    {(!(_nativeTarget isEqualType objNull) || {isNull _nativeTarget} || {!_hasPosition} ||
        {(_position distance2D _nativeTarget) > 500})}) exitWith {
    [false, "Автономный марш отклонён: точка не соответствует текущей цели Warlords."]
};
if (_autonomousSource && {_type in ["ADVANCE", "ASSAULT", "RETREAT"]} && {_hasPosition}) then {
    private _minMove = missionNamespace getVariable ["NeroAI_autonomyMinAdvanceMeters", 35];
    private _lastMove = _group getVariable ["NeroAI_lastAutonomyMove", ["", [], -60]];
    private _tooClose = ((leader _group) distance2D _position) < _minMove;
    private _repeat = ((_lastMove # 0) isEqualTo _type)
        && {(_lastMove # 1) isEqualType [] && {count (_lastMove # 1) >= 2}}
        && {(_position distance2D (_lastMove # 1)) < 25}
        && {(_now - (_lastMove # 2)) < 45};
    if (_tooClose || _repeat) exitWith {
        private _why = "Автономное перемещение отклонено: цель у текущей позиции группы.";
        _group setVariable ["NeroAI_lastActionResult", [diag_tickTime, _type, false, _why], true];
        _moveGuardResult = [false, _why];
    };
    _group setVariable ["NeroAI_lastAutonomyMove", [_type, _position, _now], true];
    private _fatigueSum = 0;
    { _fatigueSum = _fatigueSum + getFatigue _x; } forEach _members;
    if (_members isNotEqualTo [] && {(_fatigueSum / (count _members)) >= 0.8}) then {_marchSpeed = "LIMITED";};
};

// exitWith inside the guard only leaves its then block. Refuse at function scope.
if (_moveGuardResult isNotEqualTo []) exitWith {_moveGuardResult};

private _result = [true, "Действие передано группе."];
/* 8.10: a behaviour template (LAMBS task) ends with any new movement order;
 * RECON only supersedes the march when it carries a template itself. */
private _tactic = if (_type in ["ASSAULT", "HOLD", "RECON"]) then {toUpper _argument} else {""};
private _vehicleHold = NeroAI_rulesMode && {_autonomousSource} && {_type isEqualTo "HOLD"} && {(_members findIf {isNull objectParent _x || {!((objectParent _x) isKindOf "LandVehicle")} || {(assignedVehicleRole _x param [0,""]) isEqualTo "cargo"}}) < 0};
/* Live probe 8.10: qwen3.5-9b chose no template in 6/6 plans. An AI-to-AI order
 * without one gets the obvious template (the player's own orders stay literal):
 * a town assault clears buildings, a hold occupies them (DEFEND without houses). */
if (_tactic isEqualTo "" && {_autonomousSource} && {missionNamespace getVariable ["NeroAI_tacticDefaults", true]}) then {
    if (_type isEqualTo "ASSAULT" && {_hasPosition} && {count ((nearestObjects [_position, ["House", "Building"], 150]) select {count (_x buildingPos -1) > 1}) >= 6}) then {_tactic = "CQB";};
    if (_type isEqualTo "HOLD") then {_tactic = "GARRISON";};
};
// Repeated autonomous objectives must not restart every vehicle's road search.
// Player orders and template changes always go through the normal handoff.
private _reuseRoute = false;
if (_autonomousSource && {_type in ["ADVANCE","RETREAT"]} && {_hasPosition} && {_tactic isEqualTo ""} &&
    {(_group getVariable ["NeroWL_tactic",[]]) isEqualTo []} &&
    {(_group getVariable ["NeroWL_routeOrderType",""]) isEqualTo _type}) then {
    private _movers = _group getVariable ["NeroWL_routeMovers",[]];
    private _epoch = _group getVariable ["NeroWL_routeEpoch",0];
    _reuseRoute = _movers isNotEqualTo [] && {
        _movers findIf {
            private _target = _x getVariable ["NeroWL_routeTarget",[]];
            private _handle = _x getVariable ["NeroWL_routeScript",scriptNull];
            isNull _x || {!alive _x} || {scriptDone _handle} ||
            {(_x getVariable ["NeroWL_routeEpoch",-1]) isNotEqualTo _epoch} ||
            {count _target < 2} || {_target distance2D _position >= 60}
        } < 0
    };
};
if (_reuseRoute) exitWith {
    private _message = "Группа продолжает действующий маршрут к той же цели.";
    _group setVariable ["NeroAI_lastActionResult",[_now,_type,true,_message],true];
    [true,_message]
};
if (_type in ["ADVANCE","ASSAULT","RETREAT","HOLD","CANCEL","BOARD","DISEMBARK","AUTONOMY"] || {_tactic in ["HUNT","CREEP"]}) then {
    [_group] call NeroAI_fnc_tacticStop;
    [_group] call NeroAI_fnc_routeStop;
    _group setVariable ["NeroWL_routeOrderType",_type];
};
switch (_type) do {
    case "ASSIGN_ROLE": {_group setVariable ["NeroWL_role",_argument,true];_group setVariable ["NeroWL_roleUntil",_now+300];_result=[true,format ["Роль %1 назначена на следующий этап операции.",_argument]];};
    case "AIR_TASK": {_result=if (_hasPosition) then {[_group,_position,_argument] call NeroAI_fnc_dispatchAir} else {[false,"Нужна подтверждённая точка авиационной задачи."]};};
    case "ADVANCE": {
        if (!_hasPosition) exitWith {_result = [false, "Для выдвижения не задана точка или направление."];};
        _group setCombatBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setSpeedMode _marchSpeed;
        _result = [_group, "MOVE", _position,objNull,_source,_type] call NeroAI_fnc_vehicleTactics;
    };
    case "ASSAULT": {
        if (!_hasPosition) exitWith {_result = [false, "Для штурма не задана точка или направление."];};
        private _template = [_group, "ASSAULT", _tactic, _position] call NeroAI_fnc_tacticOrder;
        if (_template # 0) exitWith {_result = [true, _template # 1];};
        _group setCombatBehaviour "COMBAT";
        _group setCombatMode "RED";
        _group setSpeedMode _marchSpeed;
        _group setFormation "WEDGE";
        _result = [_group, "MOVE", _position,objNull,_source,_type] call NeroAI_fnc_vehicleTactics;
    };
    case "HOLD": {
        private _template = if (_vehicleHold) then {[false,""]} else {[_group, "HOLD", _tactic,if (_hasPosition) then {_position} else {[]}] call NeroAI_fnc_tacticOrder};
        if (_template # 0) exitWith {_result = [true, _template # 1];};
        _group setCombatBehaviour "AWARE";
        _group setCombatMode "YELLOW";
        _group setSpeedMode "LIMITED";
        { doStop _x; } forEach _members;
    };
    case "RETREAT": {
        if (!_hasPosition) exitWith {_result = [false, "Для отхода не задана точка или направление."];};
        _group setCombatBehaviour "STEALTH";
        _group setCombatMode "GREEN";
        _group setSpeedMode _marchSpeed;
        _result = [_group, "MOVE", _position,objNull,_source,_type] call NeroAI_fnc_vehicleTactics;
    };
    case "RECON": {
        private _template = [_group, "RECON", _tactic, if (_hasPosition) then {_position} else {[]}] call NeroAI_fnc_tacticOrder;
        if (_template # 0) exitWith {_result = [true, _template # 1];};
        _result = [_group, if (_hasPosition) then {_position} else {[]}] call NeroAI_fnc_uavRecon;
    };
    case "REQUEST_FIRE": {
        _result = if (_hasPosition) then {[_group, _position, _argument] call NeroAI_fnc_requestFireSupport} else {[false, "Для огневой поддержки нужны координаты."]};
    };
    case "BOARD": { _result = [_group, "BOARD", _position] call NeroAI_fnc_vehicleTactics; };
    case "DISEMBARK": { _result = [_group, "DISEMBARK"] call NeroAI_fnc_vehicleTactics; };
    case "REPAIR": { _result = [_group,objNull,_source] call NeroAI_fnc_repairVehicle; };
    /* 4.5.0: spend the group's own Warlords CP on vanilla requisition. */
    case "BUY": { _result = [_group, if (_argument isEqualTo "") then {"TANK"} else {_argument}, _source] call NeroAI_fnc_purchaseAsset; };
    case "SET_ROE": {
        switch (_argument) do {
            case "HOLD_FIRE": { _group setCombatMode "BLUE"; };
            case "RETURN_FIRE": { _group setCombatMode "GREEN"; };
            case "OPEN_FIRE": { _group setCombatMode "RED"; };
            default {_result = [false, "Неизвестные правила открытия огня."];};
        };
    };
    case "SET_SECTOR": {
        if (!_hasPosition) exitWith {_result = [false, "Для наблюдения не задан сектор или направление."];};
        { _x doWatch _position; } forEach _members;
        leader _group setDir ((leader _group) getDir _position);
    };
    case "REPORT": {
        private _contacts = count (_group getVariable ["NeroAI_intel", []]);
        private _initial = _group getVariable ["NeroAI_initialStrength", count _members];
        private _report = format ["%1: боеспособны %2 из %3, потери %4, подтверждённых контактов %5.", _group getVariable ["NeroAI_callsign", groupId _group], count _members, _initial, (_initial - count _members) max 0, _contacts];
        _group setVariable ["NeroAI_reportRequested", diag_tickTime, true];
        _group setVariable ["NeroAI_lastReport", _report, true];
        [leader _group, _report, "GROUP"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
    };
    case "REQUEST_SUPPORT": { _result = [_group, _position, if (_source in ["PLAYER","PLAYER_DEFERRED"]) then {"приказ игрока"} else {_group getVariable ["NeroWL_rulesSupportNeed","поддержка"]}] call NeroAI_fnc_requestSupport; };
    case "SHARE_INTEL": { _result = [_group, "приказ игрока"] call NeroAI_fnc_shareIntel; };
    case "NEGOTIATE": { _result = [_group, _position] call NeroAI_fnc_negotiate; };
    case "DESIGNATE": {
        _result = if (_hasPosition) then {[_group, _position] call NeroAI_fnc_laserDesignate} else {[false, "Для лазерной подсветки нужны координаты или направление."]};
    };
    case "CANCEL": {
        {
            private _unit = _x;
            if (vehicle _unit isEqualTo _unit) then {unassignVehicle _unit;};
            if (!isNull (laserTarget _unit)) then {
                private _laserWeapons = (weapons _unit) select {
                    private _weaponClass = _x;
                    "laserdesignator" in toLower _weaponClass
                };
                if !(_laserWeapons isEqualTo []) then {_unit forceWeaponFire [_laserWeapons # 0, _laserWeapons # 0];};
            };
            doStop _unit;
            _unit doWatch objNull;
        } forEach _members;
        _group setSpeedMode "NORMAL";
        _group setVariable ["NeroAI_supportState", "CANCELLED", true];
        _group setVariable ["NeroAI_designationState", "CANCELLED", true];
        _group setVariable ["NeroAI_playerVehicleDirective", "", true];
    };
    case "AUTONOMY": {
        /* Do not stop, redirect or delete Warlords waypoints. Releasing the
         * manual authority window lets the next autonomy pass reassess the
         * current objective, contacts, vehicle state and shared intelligence. */
        _group setVariable ["NeroAI_playerHold", false, true];
        _group setVariable ["NeroAI_manualOrderUntil", 0, true];
        _group setVariable ["NeroAI_lastPlayerOrder", [], true];
        _group setVariable ["NeroAI_playerVehicleDirective", "", true];
    };
    default {_result = [false, "Действие отсутствует в разрешённом наборе NeroAI."];};
};

// A previously selected player ROE remains authoritative across movement,
// retreat, hold and autonomous macro actions. SET_ROE itself updates it above.
private _persistentROE = _group getVariable ["NeroAI_playerROE", ""];
if !(_persistentROE isEqualTo "") then {
    switch (_persistentROE) do {
        case "HOLD_FIRE": {_group setCombatMode "BLUE";};
        case "RETURN_FIRE": {_group setCombatMode "GREEN";};
        case "OPEN_FIRE": {_group setCombatMode "RED";};
    };
};
if ((_result # 0) && {_source in ["PLAYER", "PLAYER_DEFERRED"]} && {_type != "AUTONOMY"}) then {
    // Store absolute destination after resolving DIR/REL, not the old placeholder.
    _group setVariable ["NeroAI_lastPlayerOrder", [_type, _position, _argument, _now], true];
};
_group setVariable ["NeroAI_lastActionResult", [diag_tickTime, _type, _result # 0, _result # 1], true];

// 4.2.0: a request/coordination action opens an LLM radio dialogue with the
// selected responder group (bounded to one hop). Never from an INTERGROUP reply.
if (
    (_result # 0) && {_source != "INTERGROUP"} &&
    {_type in ["REQUEST_SUPPORT", "SHARE_INTEL", "NEGOTIATE"]} &&
    {missionNamespace getVariable ["NeroAI_intergroupEnabled", true]}
) then {
    [_group, _type] call NeroAI_fnc_intergroupRelay;
};
_result
