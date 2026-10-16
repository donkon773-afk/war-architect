/* 4.5.0 [Vanilla Command]: no stress/adrenaline model any more — vanilla AI
 * psychology (suppression, morale) is the engine's own. The only watcher left
 * is the casualty report, which is radio traffic plus a replan request. */
params ["_unit"];
if (isNull _unit || {!local _unit} || {_unit getVariable ["NeroAI_watchersInstalled", false]}) exitWith {};

_unit setVariable ["NeroAI_watchersInstalled", true];
_unit addEventHandler ["Killed", {
    params ["_unit"];
    private _casualtyGroup = group _unit;
    if (!isNull _casualtyGroup && {_casualtyGroup getVariable ["NeroAI_active", false]}) then {
        _casualtyGroup setVariable ["NeroAI_forcePlan", true, true];
        [_casualtyGroup, typeOf _unit] spawn {
            params ["_group", "_lostClass"];
            uiSleep 0.5;
            if (isNull _group) exitWith {};
            private _alive = {alive _x} count units _group;
            private _initial = _group getVariable ["NeroAI_initialStrength", _alive + 1];
            _initial = _initial max (_alive + 1);
            private _losses = (_initial - _alive) max 0;
            private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
            private _lastReport = _group getVariable ["NeroAI_lastLossReport", -10];
            if ((diag_tickTime - _lastReport) >= 8) then {
                [leader _group, format ["%1: есть потери, боеспособны %2 из %3, продолжаем действовать.", _callsign, _alive, _initial], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
                _group setVariable ["NeroAI_lastLossReport", diag_tickTime, true];
            };
            ["WARN", format ["%1 casualty: class=%2; alive=%3/%4; losses=%5; autonomous replanning requested.", _callsign, _lostClass, _alive, _initial, _losses]] call NeroAI_fnc_log;
        };
    };
}];
