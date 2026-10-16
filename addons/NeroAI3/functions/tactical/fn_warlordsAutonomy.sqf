/* Resume an existing mission movement waypoint; no guessed sector ownership. */
params ["_group"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};
/* Warlords presence = real sector objects exist (NeroAI_fnc_warlordsSectors). */
if (([] call NeroAI_fnc_warlordsSectors) isEqualTo []) exitWith {[false, "Warlords не обнаружен."]};
private _now = diag_tickTime;
if ((_group getVariable ["NeroAI_playerHold", false]) ||
    {_now < (_group getVariable ["NeroAI_manualOrderUntil", 0])}) exitWith {[false, "Действует приказ игрока."]};
if ((_group getVariable ["NeroAI_vehicleState", ""]) in ["BOARDING", "PARTIAL_BOARDING"]) exitWith {[false, "Ожидается посадка."]};
private _order = _group getVariable ["NeroAI_lastPlayerOrder", []];
private _lastAt = _group getVariable ["NeroAI_enrolledAt", _now];
if (_order isEqualType [] && {count _order >= 4}) then {_lastAt = _order # 3;};
private _autonomyMove=_group getVariable ["NeroAI_lastAutonomyMove",[]];
if (_autonomyMove isEqualType [] && {count _autonomyMove>=3}) then {_lastAt=_lastAt max (_autonomyMove # 2);};
private _idle = missionNamespace getVariable ["NeroAI_warlordsIdleSeconds", 180];
if !(_idle isEqualType 0) then {_idle = 180;};
if ((_now - _lastAt) < (_idle max 180)) exitWith {[false, "Ожидается окончание ручного управления."]};
if ((_now - (_group getVariable ["NeroAI_lastWarlordsAutonomy", -120])) < 120) exitWith {[false, "Ожидание такта."]};
private _index = currentWaypoint _group;
if (_index <= 0 || {_index >= count waypoints _group}) exitWith {[false, "Сценарий не назначил активную маршрутную точку."]};
private _waypoint = [_group, _index];
// Scripted, synchronized, HOLD, GETIN and other mission waypoints remain native.
if !((waypointType _waypoint) in ["MOVE", "SAD"]) exitWith {[false, "Маршрутная точка управляется сценарием."]};
private _target = waypointPosition _waypoint;
if ((leader _group) distance2D _target < 35) exitWith {[true, "Группа у цели сценария."]};
private _result = [_group, "MOVE", _target] call NeroAI_fnc_vehicleTactics;
if (_result # 0) then {
    _group setVariable ["NeroAI_lastWarlordsAutonomy", _now, true];
    _group setVariable ["NeroAI_warlordsTarget", [_index, _target, _now], true];
    ["INFO", format ["%1 resumes native mission waypoint %2 (WARLORDS_AUTONOMY).", groupId _group, _index]] call NeroAI_fnc_log;
};
_result
