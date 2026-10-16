if (!hasInterface || {isNull player}) exitWith {};
private _groups = allGroups select {[_x] call NeroAI_fnc_validateGroup && {side _x isEqualTo side group player}};
if (_groups isEqualTo []) exitWith {systemChat "[NeroAI 4.3.0] Активных групп нет.";};
systemChat "[NeroAI 4.3.0] Автономные группы:";
{
    private _leader = leader _x;
    private _alive = {alive _x} count units _x;
    private _initial = _x getVariable ["NeroAI_initialStrength", _alive];
    systemChat format ["%1 | командир %2 | бойцов %3/%4 | автономный ванильный режим", _x getVariable ["NeroAI_callsign", groupId _x], name _leader, _alive, _initial];
} forEach _groups;
