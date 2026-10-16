params ["_unit","_plane","_flight"];
if (!hasInterface || {_unit!=player} || {!local _unit} || {!alive _unit} || {isNull _plane} || {!isRemoteExecuted} || {remoteExecutedOwner!=2} || {(_plane getVariable ["NeroOP_pendingPilot",objNull])!=_unit}) exitWith {};
[_unit,_plane,_flight] spawn {
 params ["_unit","_plane","_flight"];private _deadline=diag_tickTime+15;
 if (isNull _flight || {!local _flight}) then {_flight=createGroup [side group _unit,true];_flight setVariable ["NeroOP_campFlight",true,true];_flight setVariable ["NeroOP_side",[west,east] find side group _unit,true];};
 if (!local _flight || {_unit!=player} || {!alive _unit} || {!alive _plane} || {(_plane getVariable ["NeroOP_pendingPilot",objNull])!=_unit}) exitWith {};
 unassignVehicle _unit;if (vehicle _unit!=_unit) then {moveOut _unit;};[_unit] joinSilent _flight;
 _unit assignAsDriver _plane;_unit moveInDriver _plane;
 if (driver _plane!=_unit) exitWith {};
 [_unit,"READY",_plane getVariable ["NeroOP_assetId",-1]] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];
 waitUntil {sleep .1;local _plane && {_plane getVariable ["NeroOP_equipmentLaunched",false]} || {diag_tickTime>_deadline} || {!alive _unit}};
 if (!local _plane || {driver _plane!=_unit} || {!(_plane getVariable ["NeroOP_equipmentLaunched",false])}) exitWith {};
 private _heading=_plane getVariable ["NeroOP_airHeading",getDir _plane];private _speed=if (_plane isKindOf "Helicopter") then {35} else {180};
 _plane engineOn true;_plane setVelocity [sin _heading*_speed,cos _heading*_speed,0];_plane setVehicleRadar 1;if !(_plane getVariable ["NeroOP_airArmed",false]) then {[_plane] call NeroOP_fnc_airArm;_plane setVariable ["NeroOP_airArmed",true,true];};[_plane] call NeroOP_fnc_campaignAmmoRestore;[_plane,_unit] call NeroOP_fnc_airAvionics;
 diag_log format ["[NeroOP EQUIPMENT] PLAYER PILOT READY id=%1",_plane getVariable ["NeroOP_assetId",-1]];
};
