/* Publishes a bounded, time-limited tactical picture to friendly NeroAI groups. */
params ["_group", ["_reason", ""]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};

private _now = diag_tickTime;
private _cooldown = missionNamespace getVariable ["NeroAI_radioCooldownSeconds", 20];
private _last = _group getVariable ["NeroAI_lastIntelShare", -_cooldown];
if ((_now - _last) < _cooldown) exitWith {[false, "Передача разведданных временно на паузе."]};

private _leader = leader _group;
private _friendlySide = side _leader;
private _intel = +(_group getVariable ["NeroAI_intel", []]);
if (_intel isEqualTo []) then {
    {
        // nearTargets: [position, type, side, cost, object, positionAccuracy]
        private _target = _x param [4, objNull];
        private _combatObject = !isNull _target && {
            _target isKindOf "Man" || {_target isKindOf "LandVehicle"} ||
            {_target isKindOf "Air"} || {_target isKindOf "Ship"} ||
            {_target isKindOf "StaticWeapon"}
        };
        if (_combatObject && {alive _target} && {(_friendlySide getFriend (side _target)) < 0.6}) then {
            private _pos = _x # 0;
            _intel pushBack [_x # 1, [round (_pos # 0), round (_pos # 1)], round ((_leader knowsAbout _target) * 10), netId _target];
        };
    } forEach (_leader nearTargets 1200);
};
_intel resize ((count _intel) min 12);
if (_intel isEqualTo []) exitWith {[false, "Подтверждённых контактов для передачи нет."]};

private _sideKey = str _friendlySide;
private _shared = +(NeroAI_sharedIntel getOrDefault [_sideKey, []]);
private _changed = 0;
{
    private _entry = [_x # 0, _x # 1, _x # 2, _now, _group getVariable ["NeroAI_callsign", groupId _group], _x param [3, ""]];
    private _key = format ["%1:%2:%3", _entry # 0, (_entry # 1) # 0, (_entry # 1) # 1];
    private _duplicate = _shared findIf {format ["%1:%2:%3", _x # 0, (_x # 1) # 0, (_x # 1) # 1] isEqualTo _key};
    if (_duplicate >= 0) then {_shared deleteAt _duplicate;} else {_changed = _changed + 1;};
    _shared pushBack _entry;

    private _targetId = _entry # 5;
    if (_targetId isEqualType "" && {_targetId != ""}) then {
        private _target = objectFromNetId _targetId;
        if (!isNull _target) then {
            {
                private _friendlyGroup = _y;
                if ([_friendlyGroup] call NeroAI_fnc_validateGroup && {side _friendlyGroup isEqualTo _friendlySide}) then {
                    _friendlyGroup reveal [_target, (((_entry # 2) / 10) max 0.5) min 4];
                };
            } forEach NeroAI_activeGroups;
        };
    };
} forEach _intel;
private _ttl = missionNamespace getVariable ["NeroAI_intelTtlSeconds", 180];
_shared = _shared select {(_now - (_x # 3)) <= _ttl};
if ((count _shared) > 24) then {_shared = _shared select [(count _shared) - 24, 24];};
NeroAI_sharedIntel set [_sideKey, _shared];
_group setVariable ["NeroAI_intel", _intel, true];
_group setVariable ["NeroAI_lastIntelShare", _now, true];

private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
private _suffix = if (_reason isEqualTo "") then {""} else {format [" (%1)", _reason]};
if (_changed > 0) then {
    [_leader, format ["%1: передаю новые разведданные, контактов: %2%3.", _callsign, count _intel, _suffix], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
};
[if (_changed > 0) then {"INFO"} else {"DEBUG"}, format ["%1 shared %2 intel item(s); new=%3.", _callsign, count _intel, _changed]] call NeroAI_fnc_log;
[true, format ["%1 передал союзникам %2 разведконтактов.", _callsign, count _intel]]
