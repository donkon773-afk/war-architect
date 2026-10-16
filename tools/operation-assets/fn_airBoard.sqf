params [["_unit",objNull,[objNull]],["_plane",objNull,[objNull]]];
if (!hasInterface || {_unit!=player} || {!local _unit} || {!alive _unit} || {isNull _plane} || {!alive _plane}) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner!=2}) exitWith {};
if ((_plane getVariable ["NeroOP_side",-1])!=([west,east] find side group _unit)) exitWith {};
_unit assignAsDriver _plane;_unit moveInDriver _plane;
if (driver _plane!=_unit) exitWith {};
[_unit,_plane] remoteExecCall ["NeroOP_fnc_airActivate",2];
[_unit,_plane] spawn {
 params ["_unit","_plane"];private _deadline=diag_tickTime+15;
 waitUntil {sleep .1;isNull _plane || {!alive _unit} || {diag_tickTime>_deadline} || {local _plane && {_plane getVariable ["NeroOP_launched",false]}}};
 if (isNull _plane || {!alive _unit} || {_unit!=player} || {driver _plane!=_unit} || {!local _plane} || {!(_plane getVariable ["NeroOP_launched",false])}) exitWith {};
 private _heading=_plane getVariable ["NeroOP_heading",getDir _plane];
 _plane allowDamage true;_unit setCaptive false;
 if !(_plane getVariable ["NeroOP_adopted",false]) then {_plane setDir _heading;_plane setVelocity [sin _heading*180,cos _heading*180,0];};
 _plane engineOn true;_plane flyInHeight getNumber(missionConfigFile >> "CfgNeroOperation" >> "altitude");
 [_plane,_unit] call NeroOP_fnc_airAvionics;
 diag_log format ["[NeroOP AIR] CLIENT IN COCKPIT id=%1",_plane getVariable ["NeroOP_flight",""]];
};
