params ["_vehicle","_group"];
if (!isServer || {isNull _vehicle} || {!local _group} || {units _group findIf {isPlayer _x}>=0}) exitWith {false};
private _units=units _group select {alive _x && {local _x}};if (count _units==0) exitWith {false};
private _static=_vehicle isKindOf "StaticWeapon";
if (!_static) then {private _driver=leader _group;unassignVehicle _driver;if (vehicle _driver!=_driver) then {moveOut _driver;};_driver assignAsDriver _vehicle;_driver moveInDriver _vehicle;_units=_units-[_driver];};
private _seats=(fullCrew [_vehicle,"",true]) select {isNull (_x#0) && {(_x#1)!="driver"}};
private _rank=[];{private _priority=switch (_x#1) do {case "gunner":{0};case "commander":{1};case "cargo":{3};default {2};};_rank pushBack [_priority*100+_forEachIndex,_x];} forEach _seats;_rank sort true;_seats=_rank apply {_x#1};
{if (_forEachIndex<count _seats && {vehicle _x==_x}) then {private _seat=_seats#_forEachIndex;
 if ((_seat#1)=="cargo") then {_x assignAsCargoIndex [_vehicle,_seat#2];_x moveInCargo [_vehicle,_seat#2];} else {_x assignAsTurret [_vehicle,_seat#3];_x moveInTurret [_vehicle,_seat#3];};
};} forEach _units;
_vehicle engineOn true;_vehicle limitSpeed 45;_group addVehicle _vehicle;
diag_log format ["[NeroOP EQUIPMENT] CREW class=%1 seats=%2 group=%3",typeOf _vehicle,count crew _vehicle,groupId _group];if (_static) then {!isNull gunner _vehicle} else {!isNull driver _vehicle}
