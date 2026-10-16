/* Return a surviving paid truck to a connected warehouse for its next load. */
params ["_truck","_side",["_source",-1]];
if (!alive _truck || {!alive driver _truck} || {!local _truck} || {[_truck] call NeroOP_fnc_campaignPlayerControl} || {_truck getVariable ["NeroOP_supplyPlanning",false]}) exitWith {};
_truck setVariable ["NeroOP_supplyReturning",true];_truck setVariable ["NeroOP_supplyPlanning",true];
private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
if (_source<0 || {!(_source in (_graph#0))}) then {private _rank=(_graph#0) select {(NeroOP_campStocks#_x)>getNumber(missionConfigFile >> "CfgNeroOperation" >> "convoyCargo")+100};_rank=_rank apply {[_truck distance2D (NeroOP_campPositions#_x),_x]};_rank sort true;_source=if (count _rank>0) then {(_rank#0)#1} else {NeroOP_campRoots#_side};};
private _route=[getPosATL _truck,NeroOP_campPositions#_source,_side] call NeroOP_fnc_campaignRoad;
if (alive _truck && {alive driver _truck} && {local _truck} && {!([_truck] call NeroOP_fnc_campaignPlayerControl)} && {_truck getVariable ["NeroOP_campCargo",0]==0}) then {
 private _g=group driver _truck;
 if (count _route>0) then {{deleteWaypoint _x;} forEach +(waypoints _g);{private _wp=_g addWaypoint [_x,20];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";_wp setWaypointBehaviour "SAFE";} forEach _route;_g setCurrentWaypoint [_g,1];_truck engineOn true;_truck setVariable ["NeroOP_supplyHome",_source];} else {_truck setVariable ["NeroOP_supplyRetryAt",serverTime+90];};
};
_truck setVariable ["NeroOP_supplyPlanning",false];
