/* Critical evacuation is scoped to this vehicle, not every healthy asset. */
params ["_group","_vehicle"];
if (!isServer || {!local _vehicle} || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {false};
private _members = (crew _vehicle) select {group _x isEqualTo _group && {alive _x} && {local _x} && {!isPlayer _x}};
if (_members isEqualTo []) exitWith {false};
[_group] call NeroAI_fnc_routeStop;
if (!isNull driver _vehicle) then {doStop driver _vehicle;};
_vehicle engineOn false;
{unassignVehicle _x;[_x] orderGetIn false;doGetOut _x;} forEach _members;
_vehicle setVariable ["NeroWL_evacuated",true,true];
_group setVariable ["NeroAI_repairStatus","CRITICAL_EVACUATION",true];
_group setVariable ["NeroAI_forcePlan",true,true];
true
