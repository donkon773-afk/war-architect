params ["_group"];
if (isNull _group) exitWith {[]};

private _living = (units _group) select {alive _x};
private _vehicles = [];
{ private _vehicle = vehicle _x; if (_vehicle != _x && {alive _vehicle}) then {_vehicles pushBackUnique _vehicle;}; } forEach _living;

private _mounted = {vehicle _x != _x} count _living;
private _wounded = {damage _x > 0.25} count _living;
private _medics = {_x getUnitTrait "Medic"} count _living;
private _engineers = {_x getUnitTrait "Engineer" || {_x getUnitTrait "ExplosiveSpecialist"}} count _living;
private _antiTank = {secondaryWeapon _x != ""} count _living;
private _armedVehicles = {canFire _x} count _vehicles;
private _mobileVehicles = {canMove _x} count _vehicles;
private _aircraft = {_x isKindOf "Air"} count _vehicles;
private _armour = {_x isKindOf "Tank" || {_x isKindOf "Wheeled_APC_F"} || {_x isKindOf "Tracked_APC_F"}} count _vehicles;
private _freeSeats = 0;
{
    _freeSeats = _freeSeats + ((_x emptyPositions "driver") max 0) + ((_x emptyPositions "gunner") max 0) + ((_x emptyPositions "commander") max 0) + ((_x emptyPositions "cargo") max 0);
} forEach _vehicles;

private _initial = _group getVariable ["NeroAI_initialStrength", count _living];
private _losses = (_initial - count _living) max 0;
private _currentWaypoint = currentWaypoint _group;
private _waypointType = "";
private _waypointPosition = [];
if (_currentWaypoint >= 0 && {_currentWaypoint < count waypoints _group}) then {
    _waypointType = waypointType [_group, _currentWaypoint];
    private _wp = waypointPosition [_group, _currentWaypoint];
    _waypointPosition = [round (_wp # 0), round (_wp # 1)];
};

[
    "alive", count _living,
    "initial", _initial,
    "losses", _losses,
    "wounded", _wounded,
    "mounted", _mounted,
    "medics", _medics,
    "engineers", _engineers,
    "antiTank", _antiTank,
    "vehicles", count _vehicles,
    "mobileVehicles", _mobileVehicles,
    "armedVehicles", _armedVehicles,
    "armour", _armour,
    "aircraft", _aircraft,
    "freeSeats", _freeSeats,
    "waypoint", [_waypointType, _waypointPosition]
]
