/* Paid payload is physical cargo. No replacement or refund after combat loss. */
params ["_plan","_payload","_parent",["_reinforce",false],["_buyer",objNull]];
_plan params ["_plane","_escort","_node"];private _side=_plane getVariable ["NeroOP_side",-1];private _pos=NeroOP_campPositions#_node;private _flight=group driver _plane;private _cover=group driver _escort;
private _wp=_flight addWaypoint [[_pos#0,_pos#1,600],0];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";
private _deadline=serverTime+900;private _dropped=false;
while {alive _plane && {alive driver _plane} && {serverTime<_deadline} && {!NeroOP_campFinished} && {!_dropped}} do {
 if (alive _escort && {alive driver _escort}) then {
  private _threats=(NeroOP_campIntel#_side) select {(_x#2) && {alive (_x#0)} && {(_x#0) distance2D _plane<8000} && {[_side,_x#0] call NeroOP_fnc_campaignIFF}};
  if (count _threats>0) then {private _t=(_threats#0)#0;{_x reveal [_t,4];_x doTarget _t;_x doFire _t;} forEach crew _escort;[_escort,_t,16000] call NeroOP_fnc_campaignMissileEngage;} else {driver _escort doMove (getPosATL _plane getPos [400,getDir _plane+90]);};
 };
 if (NeroOP_campOwners#_node!=_side) exitWith {};
 if (_plane distance2D _pos<400 && {(getPosATL _plane)#2>150} && {(getPosATL _plane)#2<1200}) then {
  {if (alive _x && {vehicle _x==_plane} && {local _x}) then {unassignVehicle _x;moveOut _x;private _chute=createVehicle ["Steerable_Parachute_F",getPosATL _x,[],0,"FLY"];_chute setPosATL (getPosATL _x);_x moveInDriver _chute;};} forEach _payload;_dropped=true;
 };
 sleep 1;
};
if (!_dropped) then {{if (alive _x && {vehicle _x==_plane}) then {_x setDamage 1;};} forEach _payload;};
private _landing=serverTime+600;waitUntil {sleep 1;serverTime>_landing || {_payload findIf {alive _x && {(getPosATL _x)#2>3}}<0} || {NeroOP_campFinished}};
{if (alive _x && {(getPosATL _x)#2>3}) then {_x setDamage 1;};} forEach _payload;
private _survivors=_payload select {alive _x && {(getPosATL _x)#2<3}};
if (isNull _parent) then {{deleteVehicle _x;} forEach _survivors;_survivors=[];};
if (!_reinforce) then {if (!isNull _parent && {([west,east]#_side) isEqualTo side _parent}) then {_survivors joinSilent _parent;};private _pending=_parent getVariable ["NeroOP_pendingRecruits",0];_parent setVariable ["NeroOP_pendingRecruits",(_pending-count _payload) max 0,true];} else {_parent setVariable ["NeroOP_dropBusy",false,true];[_parent,true] call NeroOP_fnc_campaignOrder;if (alive _buyer && {getPlayerUID _buyer==(_parent getVariable ["NeroOP_hcUID",""])}) then {[_buyer,_parent] call NeroOP_fnc_campaignAttachHC;};};
diag_log format ["[NeroOP DELIVERY] END dropped=%1 survived=%2 ordered=%3 sector=%4",_dropped,count _survivors,count _payload,_node];
{if (alive _x) then {private _g=group driver _x;{deleteWaypoint _x;} forEach +(waypoints _g);private _wp=_g addWaypoint [NeroOP_campPositions#(NeroOP_campRoots#_side),0];_wp setWaypointType "MOVE";};} forEach [_plane,_escort];
sleep 45;
{private _v=_x;private _g=group driver _v;{if (_x in crew _v && {!(_x in _payload)}) then {deleteVehicle _x;};} forEach crew _v;deleteVehicle _v;deleteGroup _g;} forEach [_plane,_escort];
NeroOP_deliveryFlights=(missionNamespace getVariable ["NeroOP_deliveryFlights",[]]) select {(_x#0)!=_plane};
