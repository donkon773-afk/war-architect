/* Coordinates an existing friendly NeroAI group. It does not spawn assets. */
params ["_group", ["_position", []], ["_reason", "поддержка"],["_repairTarget",objNull]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};

private _now = diag_tickTime;
private _suffix = if (_reason isEqualTo "REPAIR") then {"_REPAIR"} else {""};
private _lastKey = "NeroAI_lastSupportRequest"+_suffix;private _activeKey = "NeroAI_supportActiveUntil"+_suffix;
private _cooldown = missionNamespace getVariable ["NeroAI_supportCooldownSeconds", 45];
private _last = _group getVariable [_lastKey, -_cooldown];
if ((_now - _last) < _cooldown) exitWith {[false, "Запрос подмоги для этой группы ещё на перезарядке."]};
private _activeUntil = _group getVariable [_activeKey, 0];
if (_now < _activeUntil) exitWith {[false, "Назначенная группе подмога ещё выполняет задачу."]};

if (NeroAI_rulesMode) then {_group setVariable [_lastKey,_now,true];};
if !(_position isEqualType [] && {count _position >= 2}) then {_position = getPosATL (leader _group);};
private _friendlySide = side (leader _group);
private _selected = grpNull;
private _bestScore = 1e12;
{
    private _candidate = _y;
    private _supporting = _candidate getVariable ["NeroAI_supporting", []];
    private _alreadySupporting = _supporting isEqualType [] && {count _supporting >= 3} && {(_now - (_supporting # 2)) < 180};
    private _available =
        !(_candidate getVariable ["NeroAI_playerHold", false]) &&
        {_now >= (_candidate getVariable ["NeroAI_manualOrderUntil", 0])} &&
        {!_alreadySupporting} && {!(_candidate getVariable ["NeroWL_vehicleService",false])};
    if (_candidate != _group && {_available} && {[_candidate] call NeroAI_fnc_validateGroup} && {side _candidate isEqualTo _friendlySide}) then {
        private _capabilities = [_candidate] call NeroAI_fnc_analyzeGroupCapabilities;
        private _mobileIndex = _capabilities find "mobileVehicles";
        private _armedIndex = _capabilities find "armedVehicles";
        private _aliveIndex = _capabilities find "alive";
        private _mobile = if (_mobileIndex >= 0) then {_capabilities param [_mobileIndex + 1, 0]} else {0};
        private _armed = if (_armedIndex >= 0) then {_capabilities param [_armedIndex + 1, 0]} else {0};
        private _strength = if (_aliveIndex >= 0) then {_capabilities param [_aliveIndex + 1, 0]} else {0};
        private _bonus = (_mobile * 80) + (_armed * 120) + ((_strength min 20) * 5);
        private _distance = (leader _candidate) distance2D _position;
        private _score = _distance - _bonus;
        private _engineers = {[_x] call NeroAI_fnc_fieldEngineer && {"ToolKit" in items _x}} count units _candidate;
        if (NeroAI_rulesMode) then {
            private _combat = [_candidate] call NeroAI_fnc_rulesCombatFacts;
            private _task = (_candidate getVariable ["NeroWL_rulesMission",[]]) param [0,""];
            private _protected = _candidate getVariable ["NeroWL_garrison",false] || {_task in ["DEFEND","GARRISON","CONSOLIDATE"]}
                || {_now < (_candidate getVariable ["NeroWL_logisticsUntil",0])}
                || {_now < (_candidate getVariable ["NeroAI_purchaseHoldUntil",0])}
                || {[_candidate] call NeroAI_fnc_isAirCrewGroup};
            _score = [_distance,(_combat # 0) max (if (_reason == "REPAIR") then {_engineers} else {0}),_combat # 3,_combat # 4,_combat # 5,_protected,_reason,_engineers] call NeroAI_fnc_rulesSupportScore;
            if (_score < 0) then {_score = 1e12;};
        };
        if (_reason isEqualTo "REPAIR" && {_engineers <= 0}) then {_score = 1e12;};
        if (_distance <= 4000 && {_score < _bestScore}) then {
            _bestScore = _score;
            _selected = _candidate;
        };
    };
} forEach NeroAI_activeGroups;

if (isNull _selected) exitWith {
    _group setVariable ["NeroAI_supportState", "NO_FRIENDLY_GROUP_AVAILABLE", true];
    [false, "Нет другой активной союзной группы для подмоги."]
};

private _anchor = if (isNull _repairTarget) then {leader _group} else {_repairTarget};
_selected setVariable ["NeroWL_supportDestination",[_position,_now+180,_anchor]];
private _moveResult = if ((leader _selected) distance2D _position < 60) then {[true,"Группа уже у точки поддержки."]} else {[_selected, "ADVANCE", _position, "", "SUPPORT"] call NeroAI_fnc_executeMacro};
if !(_moveResult # 0) exitWith {
    _selected setVariable ["NeroWL_supportDestination",nil];
    _group setVariable ["NeroAI_supportState", "RESPONDER_UNAVAILABLE", true];
    [false, format ["Группа подмоги не смогла принять задачу: %1", _moveResult # 1]]
};
_selected setVariable ["NeroAI_supporting", [netId _group, _position, _now,_reason,netId _repairTarget], true];
_group setVariable [_lastKey, _now, true];
_group setVariable [_activeKey, _now + 180, true];
_group setVariable ["NeroAI_supportState", "REQUESTED", true];
if (_reason isEqualTo "REPAIR" && {!isNull _repairTarget}) then {[_selected,_group,_repairTarget] spawn NeroAI_fnc_engineerResponse;};
private _requester = _group getVariable ["NeroAI_callsign", groupId _group];
private _responder = _selected getVariable ["NeroAI_callsign", groupId _selected];
[leader _group, format ["%1: запрашиваю подмогу. %2 выдвигается к точке.", _requester, _responder], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
["INFO", format ["%1 requested support; %2 assigned.", _requester, _responder]] call NeroAI_fnc_log;
[true, format ["Подмога назначена: %1.", _responder]]
