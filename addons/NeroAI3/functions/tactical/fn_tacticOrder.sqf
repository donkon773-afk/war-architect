/* 8.10: behaviour templates as tools for the LLM. The model picks a template
 * (ASSAULT/HOLD/RECON + support CQB|RUSH|GARRISON|DEFEND|HUNT|CREEP); NeroAI
 * marches the group to the place on roads with LAMBS switched off, and on
 * arrival (or first contact) hands the fight to the LAMBS Danger.fsm task.
 * LAMBS is an optional, separately loaded mod (GPL-2.0, not bundled): without
 * it, or when a template does not fit the place, the plain order runs.
 * Returns [handled, message]; handled=false means "run the plain order". */
params ["_group", "_type", "_tactic", ["_position", []]];
if (!isServer || {isNull _group}) exitWith {[false, ""]};
_tactic = toUpper _tactic;
private _templates = createHashMapFromArray [
    ["ASSAULT", ["CQB", "RUSH"]],
    ["HOLD", ["GARRISON", "DEFEND"]],
    ["RECON", ["HUNT", "CREEP"]]
];
if !(_tactic in (_templates getOrDefault [_type, []])) exitWith {[false, ""]};
if (isNil "lambs_wp_fnc_taskCQB") exitWith {
    ["INFO", format ["%1 template %2 skipped: LAMBS Danger.fsm is not loaded.", _group getVariable ["NeroAI_callsign", groupId _group], _tactic]] call NeroAI_fnc_log;
    [false, ""]
};
private _leader = leader _group;
if (_position isEqualTo []) then {_position = getPosATL _leader;};
_position = [_position # 0, _position # 1, 0];

/* Fit check: building templates need buildings at the place. */
private _houses = [];
if (_tactic in ["CQB", "GARRISON"]) then {_houses = (nearestObjects [_position, ["House", "Building"], 120]) select {count (_x buildingPos -1) > 1};};
if (_tactic in ["CQB", "GARRISON"] && {count _houses < 2}) then {
    private _fallback = if (_tactic isEqualTo "CQB") then {"RUSH"} else {"DEFEND"};
    ["INFO", format ["%1 template %2 -> %3: no buildings within 120 m of the target.", _group getVariable ["NeroAI_callsign", groupId _group], _tactic, _fallback]] call NeroAI_fnc_log;
    _tactic = _fallback;
};

[_group] call NeroAI_fnc_tacticStop;
private _epoch = _group getVariable ["NeroWL_routeEpoch", 0];
_group setVariable ["NeroWL_tactic", [_tactic, _position, diag_tickTime, "MARCH", _epoch]];
private _far = (_leader distance2D _position) > 350;
if (_far) then {
    _group setCombatMode "YELLOW";
    [_group, "MOVE", _position] call NeroAI_fnc_vehicleTactics;
};
private _handle = [_group, _tactic, _position, _epoch] spawn {
    params ["_group", "_tactic", "_position", "_epoch"];
    scriptName "NeroWL tactic watcher";
    private _deadline = diag_tickTime + 1200;
    private _live = {!isNull _group && {(units _group) findIf {alive _x} >= 0} && {(_group getVariable ["NeroWL_routeEpoch", 0]) isEqualTo _epoch}};
    waitUntil {
        sleep 3;
        !(call _live)
        || {((leader _group) distance2D _position) < 350}
        || {((((leader _group) targets [true, 400, [], 20]) select {alive _x}) isNotEqualTo [])}
        || {diag_tickTime > _deadline}
    };
    if (!(call _live) || {diag_tickTime > _deadline}) exitWith {
        if (!isNull _group) then {_group setVariable ["NeroWL_tactic", nil];};
    };
    /* Foot templates: the squad gets out first (crews keep their vehicle). */
    if (_tactic in ["CQB", "GARRISON", "DEFEND", "CREEP"] && {(units _group) findIf {alive _x && {!isNull objectParent _x}} >= 0}) then {
        {if (alive _x && {!isPlayer _x} && {(assignedVehicleRole _x param [0, ""]) isEqualTo "cargo"}) then {unassignVehicle _x; [_x] orderGetIn false; doGetOut _x;};} forEach units _group;
        private _out = diag_tickTime + 40;
        waitUntil {sleep 2; !(call _live) || {diag_tickTime > _out} || {((units _group) select {alive _x && {!isNull objectParent _x} && {(assignedVehicleRole _x param [0, ""]) isEqualTo "cargo"}}) isEqualTo []}};
    };
    if !(call _live) exitWith {};
    // End every owned route before a template can issue movement commands.
    _epoch = [_group] call NeroAI_fnc_routeStop;
    private _flags = ["MOVE","PATH","COVER","SUPPRESSION","FSM","TARGET","AUTOTARGET","ANIM","AUTOCOMBAT"];
    private _restore = (units _group select {local _x && {!isPlayer _x}}) apply {
        private _unit = _x;
        [_unit, _flags apply {[_x, _unit checkAIFeature _x]}, _unit getVariable ["lambs_danger_disableAI",false]]
    };
    _group setVariable ["NeroWL_tacticRestore",[attackEnabled _group,_restore]];
    _group setVariable ["lambs_danger_disableGroupAI", nil];
    _group setVariable ["NeroWL_tactic", [_tactic, _position, diag_tickTime, "EXEC", _epoch]];
    private _task = switch (_tactic) do {
        case "CQB": {[_group, _position, 120, 21] spawn lambs_wp_fnc_taskCQB};
        case "RUSH": {[_group, 400, 15, [], _position, false] spawn lambs_wp_fnc_taskRush};
        case "GARRISON": {[_group, _position, 80, true, _epoch] spawn NeroAI_fnc_tacticDefend};
        case "DEFEND": {[_group, _position, 80, false, _epoch] spawn NeroAI_fnc_tacticDefend};
        case "HUNT": {[_group, 500, 15, [], _position, false, false, 0] spawn lambs_wp_fnc_taskHunt};
        case "CREEP": {[_group, 400, 15, [], _position, false] spawn lambs_wp_fnc_taskCreep};
        default {scriptNull};
    };
    _group setVariable ["NeroWL_tacticTask", _task];
    _group setVariable ["NeroWL_tactic", [_tactic, _position, diag_tickTime, "EXEC", _epoch]];
    ["INFO", format ["%1 template %2 started at %3 (%4 alive).", _group getVariable ["NeroAI_callsign", groupId _group], _tactic, [round (_position # 0), round (_position # 1)], count ((units _group) select {alive _x})]] call NeroAI_fnc_log;
};
_group setVariable ["NeroWL_tacticWatcher", _handle];
["INFO", format ["%1 template %2 ordered at %3 (%4 m): %5.", _group getVariable ["NeroAI_callsign", groupId _group], _tactic, [round (_position # 0), round (_position # 1)], round (_leader distance2D _position), if (_far) then {"march on roads first"} else {"starting on arrival"}]] call NeroAI_fnc_log;
[true, format ["Шаблон %1: %2.", _tactic, if (_far) then {"марш к месту, затем исполнение"} else {"исполнение на месте"}]]
