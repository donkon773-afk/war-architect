/* Quiescent native FSM still acknowledges resets and votes in LLM mode.
 * Movement remains with NeroAI until the group is released. */
params ["_unit"];
if (missionNamespace getVariable ["BIS_WL_resetVoting",false]) then {BIS_WL_AIVotingReset = true;};
if (isPlayer _unit || {!alive _unit}) exitWith {};
private _side = side group _unit;
if (!isNull (missionNamespace getVariable [format ["BIS_WL_currentSector_%1",_side],objNull])) exitWith {
    if (!isNull (_unit getVariable ["BIS_WL_selectedSector",objNull])) then {_unit setVariable ["BIS_WL_selectedSector",objNull,true];};
};
if (missionNamespace getVariable ["NeroAI_rulesMode",false]) exitWith {};
private _wls = (missionNamespace getVariable ["BIS_WL_allWarlords",[]]) select {alive _x && {side group _x isEqualTo _side}};
private _humans = _wls select {isPlayer _x};
if ((missionNamespace getVariable ["BIS_WL_AICanVote",1]) != 1 && {_humans isNotEqualTo []}) exitWith {};
private _available = ([_side] call NeroAI_fnc_wlSnapshot) param [1,[]];
if (_available isEqualTo []) exitWith {};
private _choice = _unit getVariable ["BIS_WL_selectedSector",objNull];
{private _v = _x getVariable ["BIS_WL_selectedSector",objNull];if (_v in _available) exitWith {_choice = _v;};} forEach _humans;
if (!(_choice in _available)) then {
    _choice = [_side] call NeroAI_fnc_wlCounterTarget;
    if (!(_choice in _available)) then {_choice = _available # 0;};
};
_unit setVariable ["BIS_WL_selectedSector",_choice,true];
