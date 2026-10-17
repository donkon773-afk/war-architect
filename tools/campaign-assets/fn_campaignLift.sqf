/* Paid helicopter, real boarding/landing, finite deadlines; never teleport infantry. */
params ["_v","_parent","_flight","_side",["_forceReturn",false]];
if (!alive _v || {!alive driver _v} || {isNull _parent} || {!local _parent} || {!local _flight} || {[_v] call NeroOP_fnc_campaignPlayerControl} || {[_parent] call NeroOP_fnc_campaignPlayerControl}) exitWith {_parent setVariable ["NeroOP_liftBusy",false];false};
private _state=_v getVariable ["NeroOP_liftState","IDLE"];private _target=_parent getVariable ["NeroOP_campTarget",-1];
private _release={_parent setVariable ["NeroOP_liftBusy",false];_parent setVariable ["NeroOP_liftVehicle",objNull];{if (!isNull _x) then {deleteVehicle _x;};} forEach (_v getVariable ["NeroOP_liftPads",[]]);_v setVariable ["NeroOP_liftPads",[]];};
private _order={params ["_p"];private _pad=createVehicle ["Land_HelipadEmpty_F",[_p#0,_p#1,0],[],0,"NONE"];private _pads=_v getVariable ["NeroOP_liftPads",[]];_pads pushBack _pad;_v setVariable ["NeroOP_liftPads",_pads];_v forceSpeed -1;_v engineOn true;{deleteWaypoint _x;} forEach +(waypoints _flight);private _wp=_flight addWaypoint [_p,35];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";_wp setWaypointBehaviour "CARELESS";_flight setBehaviourStrong "CARELESS";_flight setCombatMode "BLUE";_flight enableAttack false;{_x disableAI "AUTOCOMBAT";_x setVariable ["lambs_danger_disableAI",true];} forEach units _flight;_v flyInHeight 70;_v land "NONE";_v setVariable ["NeroOP_liftLandAt",-100];_flight setCurrentWaypoint _wp;};
private _land={if (serverTime-(_v getVariable ["NeroOP_liftLandAt",-100])>=20) then {_v land "LAND";_v setVariable ["NeroOP_liftLandAt",serverTime];diag_log format ["[NeroOP LIFT] LAND REQUEST class=%1 state=%2 AGL=%3 result=%4",typeOf _v,_v getVariable ["NeroOP_liftState",""],(getPosATL _v)#2,landResult _v];};};
private _expired=_state!="IDLE" && {_target!=(_v getVariable ["NeroOP_liftTarget",-1]) || {serverTime>(_v getVariable ["NeroOP_liftDeadline",0])}};
if (_state!="RETURN" && {_forceReturn || {fuel _v<.25} || {damage _v>.65} || {_expired}}) then {
 if (_state in ["PICKUP","BOARD"]) then {_parent setVariable ["NeroOP_liftRetryAt",serverTime+300];};
 _state="RETURN";if ((_v getVariable ["NeroOP_liftParty",[]]) findIf {alive _x && {vehicle _x==_v}}<0) then {call _release;[_parent,true] call NeroOP_fnc_campaignOrder;};[NeroOP_campPositions#(NeroOP_campRoots#_side)] call _order;_v setVariable ["NeroOP_liftState",_state];_v setVariable ["NeroOP_liftDeadline",serverTime+300];
 diag_log format ["[NeroOP LIFT] ABORT class=%1 target=%2",typeOf _v,_target];
};
switch (_state) do {
 case "IDLE": {
  private _party=units _parent select {alive _x && {!isPlayer _x} && {vehicle _x==_x} && {!(_x getVariable ["ACE_isUnconscious",false])}};
  private _seats=count (fullCrew [_v,"cargo",true] select {isNull (_x#0)});
  if (_target>=0 && {serverTime>=(_parent getVariable ["NeroOP_liftRetryAt",0])} && {count _party>0} && {count _party<=_seats} && {leader _parent distance2D (NeroOP_campPositions#_target)>3500} && {!(_parent getVariable ["NeroOP_campGuard",false])} && {!(_parent getVariable ["NeroOP_rideBusy",false])} && {!(_parent getVariable ["NeroOP_liftBusy",false])}) then {
   private _origin=getPosATL leader _parent;private _pickup=[_origin,10,70,12,0,.2,0,[],[_origin,_origin]] call BIS_fnc_findSafePos;
   if (count _pickup>=2 && {_pickup distance2D _origin<150} && {!surfaceIsWater _pickup} && {(NeroOP_campIntel#_side) findIf {!(_x#2) && {(_x#1) distance2D _pickup<700}}<0}) then {
    _v setVariable ["NeroOP_liftParty",_party];_v setVariable ["NeroOP_liftPickup",_pickup];_v setVariable ["NeroOP_liftTarget",_target];_v setVariable ["NeroOP_liftDeadline",serverTime+300];_v setVariable ["NeroOP_liftState","PICKUP"];_parent setVariable ["NeroOP_liftBusy",true];_parent setVariable ["NeroOP_liftVehicle",_v];{deleteWaypoint _x;} forEach +(waypoints _parent);private _hold=_parent addWaypoint [_pickup,15];_hold setWaypointType "HOLD";{unassignVehicle _x;_x assignAsCargo _v;_x doMove _pickup;} forEach _party;[_pickup] call _order;
    diag_log format ["[NeroOP LIFT] PICKUP class=%1 group=%2 soldiers=%3 target=%4",typeOf _v,_parent getVariable ["NeroOP_groupKey",-1],count _party,_target];
   };
  };
 };
 case "PICKUP": {
  if (_v distance2D (_v getVariable ["NeroOP_liftPickup",[0,0]])<180) then {call _land;};
  if ((isTouchingGround _v || {(getPosATL _v)#2<3}) && {abs speed _v<5}) then {{deleteWaypoint _x;} forEach +(waypoints _parent);{if (alive _x && {local _x}) then {unassignVehicle _x;_x assignAsCargo _v;[_x] orderGetIn true;};} forEach (_v getVariable ["NeroOP_liftParty",[]]);diag_log format ["[NeroOP LIFT] LANDED class=%1 result=%2",typeOf _v,landResult _v];_v setVariable ["NeroOP_liftState","BOARD"];_v setVariable ["NeroOP_liftDeadline",serverTime+120];};
 };
 case "BOARD": {
  call _land;
  private _party=(_v getVariable ["NeroOP_liftParty",[]]) select {alive _x};
  if (serverTime-(_v getVariable ["NeroOP_boardRetryAt",-100])>=15) then {
   _v setVariable ["NeroOP_boardRetryAt",serverTime];
   {if (local _x && {!isPlayer _x} && {vehicle _x==_x} && {!(_x getVariable ["ACE_isUnconscious",false])}) then {_x enableAI "MOVE";_x assignAsCargo _v;[_x] orderGetIn true;};} forEach _party;
   diag_log format ["[NeroOP LIFT] BOARD PROGRESS class=%1 group=%2 aboard=%3 expected=%4 AGL=%5",typeOf _v,_parent getVariable ["NeroOP_groupKey",-1],{vehicle _x==_v} count _party,count _party,(getPosATL _v)#2];
  };
  private _gate=[count _party,{vehicle _x==_v} count _party,count fullCrew [_v,"cargo",true],serverTime>(_v getVariable ["NeroOP_liftDeadline",0]),_target!=(_v getVariable ["NeroOP_liftTarget",-1]),alive driver _v] call NeroOP_fnc_campaignBoardingGate;
  if (_gate=="ABORT") then {_v setVariable ["NeroOP_liftDeadline",0];};
  if (_gate=="READY") then {
   private _center=NeroOP_campPositions#_target;private _lz=[];private _heading=_center getDir (_v getVariable ["NeroOP_liftPickup",getPosATL _v]);
   for "_i" from 0 to 7 do {if (count _lz==0) then {private _p=_center getPos [(NeroOP_campRadii#_target)+850,_heading+45*_i];private _safe=[_p,0,120,15,0,.2,0,[],[_p,_p]] call BIS_fnc_findSafePos;
    if (count _safe>=2 && {_safe distance2D _p<150} && {_safe#0>500} && {_safe#0<worldSize-500} && {_safe#1>500} && {_safe#1<worldSize-500} && {!surfaceIsWater _safe} && {(NeroOP_campIntel#_side) findIf {!(_x#2) && {(_x#1) distance2D _safe<800}}<0}) then {_lz=_safe;};
   };};
   if (count _lz>0) then {_v setVariable ["NeroOP_liftLZ",_lz];_v setVariable ["NeroOP_liftState","FLY"];_v setVariable ["NeroOP_liftDeadline",serverTime+600];[_lz] call _order;diag_log format ["[NeroOP LIFT] BOARD COMPLETE class=%1 soldiers=%2 LZ=%3",typeOf _v,count _party,_lz];} else {_v setVariable ["NeroOP_liftDeadline",0];};
  };
 };
 case "FLY": {
  private _lz=_v getVariable ["NeroOP_liftLZ",[0,0]];
  if ((NeroOP_campIntel#_side) findIf {!(_x#2) && {(_x#1) distance2D _lz<650}}>=0) then {_v setVariable ["NeroOP_liftDeadline",0];} else {
   if (_v distance2D _lz<220) then {call _land;_v setVariable ["NeroOP_liftState","LAND"];_v setVariable ["NeroOP_liftDeadline",serverTime+150];};
  };
 };
 case "LAND": {
  call _land;
  if ((isTouchingGround _v || {(getPosATL _v)#2<3}) && {abs speed _v<5}) then {{if (local _x && {alive _x} && {vehicle _x==_v}) then {unassignVehicle _x;[_x] orderGetIn false;_x action ["GetOut",_v];};} forEach (_v getVariable ["NeroOP_liftParty",[]]);_v setVariable ["NeroOP_liftState","UNLOAD"];_v setVariable ["NeroOP_liftDeadline",serverTime+60];};
 };
 case "UNLOAD": {
  if ((_v getVariable ["NeroOP_liftParty",[]]) findIf {alive _x && {vehicle _x==_v}}<0) then {call _release;[_parent,true] call NeroOP_fnc_campaignOrder;_v setVariable ["NeroOP_liftState","RETURN"];_v setVariable ["NeroOP_liftDeadline",serverTime+600];[NeroOP_campPositions#(NeroOP_campRoots#_side)] call _order;diag_log format ["[NeroOP LIFT] UNLOADED class=%1 target=%2",typeOf _v,_target];};
 };
 case "RETURN": {
  private _home=NeroOP_campPositions#(NeroOP_campRoots#_side);if (_v distance2D _home<180) then {call _land;};
  if (_v distance2D _home<250 && {(getPosATL _v)#2<3} && {abs speed _v<5}) then {{if (local _x && {alive _x} && {vehicle _x==_v}) then {unassignVehicle _x;[_x] orderGetIn false;_x action ["GetOut",_v];};} forEach (_v getVariable ["NeroOP_liftParty",[]]);if ((_v getVariable ["NeroOP_liftParty",[]]) findIf {alive _x && {vehicle _x==_v}}<0) then {_v setVariable ["NeroOP_liftState","IDLE"];call _release;[_parent,true] call NeroOP_fnc_campaignOrder;[_v,_side] call NeroOP_fnc_campaignService;};};
 };
};
true
