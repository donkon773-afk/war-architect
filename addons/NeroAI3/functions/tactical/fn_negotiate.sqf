/* Radio coordination between existing friendly NeroAI groups. Negotiation
 * exchanges status/intel only and never silently turns into a movement order. */
params ["_group", ["_position", []]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};

private _now = diag_tickTime;
private _cooldown = missionNamespace getVariable ["NeroAI_radioCooldownSeconds", 20];
private _last = _group getVariable ["NeroAI_lastNegotiation", -_cooldown];
if ((_now - _last) < _cooldown) exitWith {[false, "Радиоканал координации временно занят."]};

private _leader = leader _group;
private _friendlySide = side _leader;
private _selected = grpNull;
private _bestDistance = 1e12;
{
    private _candidate = _y;
    if (_candidate != _group && {[_candidate] call NeroAI_fnc_validateGroup} && {side _candidate isEqualTo _friendlySide}) then {
        private _distance = _leader distance2D (leader _candidate);
        if (_distance < _bestDistance) then {
            _bestDistance = _distance;
            _selected = _candidate;
        };
    };
} forEach NeroAI_activeGroups;

if (isNull _selected) exitWith {
    _group setVariable ["NeroAI_negotiationState", ["NO_RECIPIENT", _now], true];
    [false, "Нет другой активной союзной группы для переговоров."]
};

private _requester = _group getVariable ["NeroAI_callsign", groupId _group];
private _responder = _selected getVariable ["NeroAI_callsign", groupId _selected];
private _locationText = "";
if (_position isEqualType [] && {count _position >= 2}) then {
    _locationText = format [" Координационная точка %1-%2.", round (_position # 0), round (_position # 1)];
};

[_leader, format ["%1 вызывает %2. Передаю тактическую обстановку.%3", _requester, _responder, _locationText], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
[leader _selected, format ["%1, это %2. На связи, данные принимаю.", _requester, _responder], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
[_group, "переговоры с союзной группой"] call NeroAI_fnc_shareIntel;

_group setVariable ["NeroAI_lastNegotiation", _now, true];
_group setVariable ["NeroAI_negotiationState", ["CONNECTED", netId _selected, _position, _now], true];
_selected setVariable ["NeroAI_negotiationState", ["CONNECTED", netId _group, _position, _now], true];
["INFO", format ["%1 established radio coordination with %2.", _requester, _responder]] call NeroAI_fnc_log;
[true, format ["Связь установлена с группой %1.", _responder]]
