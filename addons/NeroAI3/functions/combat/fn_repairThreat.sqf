/* Own observations and damage events, not a global enemy search. */
params ["_group","_vehicle"];
private _near = 1e9;
{
    private _position = _x param [1,[]];
    if (count _position >= 2) then {_near = _near min (_position distance2D _vehicle);};
} forEach (_group getVariable ["NeroAI_intel",[]]);
{
    private _position = _x param [1,[]];
    if (count _position >= 2 && {diag_tickTime-(_x param [3,-1e6]) <= 120}) then {_near = _near min (_position distance2D _vehicle);};
} forEach ((missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str side _group,[]]);
[_near,diag_tickTime-(_vehicle getVariable ["NeroWL_lastVehicleHit",-1e6])]
