params ["_vehicle","_group","_target"];
if (_vehicle getVariable ["NeroOP_routeBusy",false]) exitWith {};
if (!isServer || {!local _group} || {!alive _vehicle} || {[_group] call NeroOP_fnc_campaignPlayerControl}) exitWith {};
_vehicle limitSpeed getNumber(missionConfigFile >> "CfgNeroOperation" >> "Gameplay" >> "vehicleSpeed");_vehicle setVariable ["NeroOP_routeBusy",true];private _side=_group getVariable ["NeroOP_side",-1];
private _pos=NeroOP_campPositions#_target;private _hostile=(NeroOP_campOwners#_target)!=_side;
private _end=if (_group getVariable ["NeroOP_attackHold",false]) then {_pos getPos [(NeroOP_campRadii#_target)+500,_pos getDir (NeroOP_campPositions#(NeroOP_campRoots#_side))]} else {if (_hostile) then {_pos getPos [(NeroOP_campRadii#_target)+160,_pos getDir getPosATL _vehicle]} else {_pos}};
private _route=[getPosATL _vehicle,_end,_side] call NeroOP_fnc_campaignRoad;
/* Routing may yield. Recheck player authority and the exact target afterwards. */
if (alive _vehicle && {local _group} && {!([_group] call NeroOP_fnc_campaignPlayerControl)} && {(_group getVariable ["NeroOP_campTarget",-1])==_target}) then {
 if (count _route>0) then {
  {deleteWaypoint _x;} forEach +(waypoints _group);
  {private _wp=_group addWaypoint [_x,25];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";_wp setWaypointBehaviour "AWARE";} forEach _route;
  private _hold=_group addWaypoint [_end,30];_hold setWaypointType "HOLD";_group setCurrentWaypoint [_group,1];_vehicle engineOn true;_vehicle setVariable ["NeroOP_groundTarget",_target];
  diag_log format ["[NeroOP EQUIPMENT] GROUND TASK class=%1 target=%2 roads=%3",typeOf _vehicle,_target,count _route];
 } else {_vehicle setVariable ["NeroOP_groundTarget",-1];_vehicle setVariable ["NeroOP_routeRetryAt",serverTime+60];diag_log format ["[NeroOP EQUIPMENT] NO ROAD class=%1 target=%2; retry scheduled",typeOf _vehicle,_target];};
};
_vehicle setVariable ["NeroOP_routeBusy",false];
