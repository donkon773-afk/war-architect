/* Paid transport, real boarding and flight. No player units or teleportation. */
params ["_group","_target"];
if (!isServer || {!local _group} || {isPlayer leader _group}) exitWith {[false,"Перевозка доступна только локальному AI-отряду."]};
private _troops=(units _group) select {alive _x};
if (_troops isEqualTo [] || {(_troops findIf {isPlayer _x || {vehicle _x != _x}}) >= 0}) exitWith {[false,"Отряд должен быть пешим и без игроков."]};
if (leader _group distance2D _target < 2500) exitWith {[false,"Для короткого перехода используйте наземный маршрут."]};
private _side=side _group;
private _fleet=vehicles select {alive _x && {local _x} && {_x getVariable ["NeroWL_paidAir",false]} && {(_x getVariable ["NeroAI_assetRole",""]) == "TRANSPORT"} && {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) == _side} && {(_x getVariable ["NeroAI_airState",""]) == "PARKED"} && {fuel _x > 0.4} && {damage _x < 0.3} && {alive driver _x} && {_x emptyPositions "Cargo" >= count _troops} && {diag_tickTime-(_x getVariable ["NeroAI_lastSortie",-1e6])>180}};
if (_fleet isEqualTo []) exitWith {[false,"Нет готового оплаченного транспорта со свободными местами."]};
private _air=_fleet # 0;
private _homeSector=_air getVariable ["NeroWL_homeSector",objNull];
if (isNull _homeSector || {(_homeSector getVariable ["BIS_WL_sectorSide",sideUnknown]) != _side}) exitWith {[false,"База транспорта потеряна."]};
private _pickup=(getPosATL leader _group) findEmptyPosition [15,150,typeOf _air];
if !(_pickup isEqualTo []) then {private _pflat=_pickup isFlatEmpty [18,-1,0.12,20,0,false,objNull];_pickup=if (_pflat isEqualTo []) then {[]} else {ASLToATL _pflat};};
private _approach=_target getPos [800,_target getDir (getPosATL leader _group)];
private _landing=[_approach,0,400,18,0,0.12,0,[],[_approach,_approach]] call BIS_fnc_findSafePos;
private _flat=_landing isFlatEmpty [18,-1,0.12,20,0,false,objNull];
if (_pickup isEqualTo [] || {_flat isEqualTo []}) exitWith {[false,"Нет ровной безопасной площадки посадки."]};
_landing=ASLToATL _flat;
private _aa=(missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str _side,[]];
if ((_aa findIf {private _p=_x param [1,[]];private _n=toLower (_x param [0,""]);count _p>=2 && {(_p distance2D _landing<1800) || {_p distance2D _pickup<1800}} && {(["zsu","shilka","_aa","sam","tunguska","nasams"] findIf {_n find _x>=0})>=0}})>=0) exitWith {[false,"Перевозка отменена: разведка обнаружила ПВО у площадки."]};
_air setVariable ["NeroAI_airState","TRANSPORT",true];
_air setVariable ["NeroAI_lastSortie",diag_tickTime,true];
_group setVariable ["NeroAI_lastAirRequest",diag_tickTime,true];
private _operation = _group getVariable ["NeroAI_opToken",0];
private _epoch = _group getVariable ["NeroWL_routeEpoch",0];
private _lease = (_group getVariable ["NeroWL_transportSequence",0]) + 1;
private _leaseUntil = diag_tickTime + 2400;
_group setVariable ["NeroWL_transportSequence",_lease];
_group setVariable ["NeroWL_transportLease",_lease];
_group setVariable ["NeroWL_transportActive",true];
_group setVariable ["NeroWL_logisticsUntil",_leaseUntil];
private _handle = [_air,_group,_troops,_pickup,_landing,+_target,_side,_operation,_epoch,_lease,_leaseUntil] spawn {
 params ["_air","_group","_troops","_pickup","_landing","_target","_side","_operation","_epoch","_lease","_leaseUntil"];
 private _pilot=driver _air;
 private _ag=group _pilot;
 private _home=_air getVariable ["NeroAI_homeBase",getPosATL _air];
 private _callsign=_group getVariable ["NeroAI_callsign",groupId _group];
 private _aborted=false;
 private _log={params ["_text"];["INFO",format ["AIR TRANSPORT %1 %2: %3",typeOf _air,_callsign,_text]] call NeroAI_fnc_log;};
 private _aboard={({alive _x && {vehicle _x == _air}} count _troops)};
 private _aaNear={private _known=(missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str _side,[]];(_known findIf {private _p=_x param [1,[]];private _n=toLower (_x param [0,""]);count _p>=2 && {_air distance2D _p<1800} && {(["zsu","shilka","_aa","sam","tunguska","nasams"] findIf {_n find _x>=0})>=0}})>=0};
 private _current = {!isNull _group && {local _group} && {(_group getVariable ["NeroAI_opToken",-1]) isEqualTo _operation} && {(_group getVariable ["NeroWL_routeEpoch",-1]) isEqualTo _epoch} && {(_group getVariable ["NeroWL_transportLease",-1]) isEqualTo _lease}};
 private _release = {
  // A late sortie must not unlock a newer purchase, boarding or transport.
  if ((_group getVariable ["NeroWL_transportLease",-1]) isEqualTo _lease) then {
   if ((_group getVariable ["NeroWL_logisticsUntil",0]) isEqualTo _leaseUntil) then {_group setVariable ["NeroWL_logisticsUntil",0];};
   _group setVariable ["NeroWL_transportActive",false];
  };
 };
 private _guard={(call _current) && {local _air} && {alive _air} && {alive _pilot} && {!isPlayer _pilot} && {fuel _air>0.25} && {damage _air<0.4} && {!(call _aaNear)}};
 /* 7.10: invisible pads make the AI land at the chosen spot; GET OUT keeps the
  * rotor turning while the squad leaves; a 150 m acceptance radius replaced the
  * 120 m one that made whole sorties abort and fly home with the troops. */
 private _flyLand={
  params ["_position","_mode",["_guardCode",_guard]];
  private _pad=createVehicle ["Land_HelipadEmpty_F",_position,[],0,"CAN_COLLIDE"];
  while {count waypoints _ag>0} do {deleteWaypoint ((waypoints _ag) # 0);};
  _air land "NONE";_air engineOn true;_air flyInHeight 90;
  private _wp=_ag addWaypoint [_position,0];_wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 100;
  private _timeout=diag_tickTime + ((150 max ((_air distance2D _position)/30+150)) min 1500);
  waitUntil {sleep 3;!(call _guardCode) || {_air distance2D _position<300} || {diag_tickTime>_timeout}};
  private _ok=false;
  if ((call _guardCode) && {_air distance2D _position<300}) then {
   _air land _mode;
   _timeout=diag_tickTime+150;
   waitUntil {sleep 3;!(call _guardCode) || {isTouchingGround _air && {abs speed _air<3}} || {diag_tickTime>_timeout}};
   _ok=(call _guardCode) && {isTouchingGround _air} && {abs speed _air<3} && {_air distance2D _position<150};
  };
  deleteVehicle _pad;
  _ok
 };
 /* Everyone out on the ground: ordered dismount, then a forced dismount for
  * whoever the AI kept inside after 25 s. Only while the helicopter is landed. */
 private _unload={
  {if (alive _x && {local _x} && {!isPlayer _x} && {group _x isEqualTo _group} && {vehicle _x == _air}) then {[_x] orderGetIn false;unassignVehicle _x;doGetOut _x;};} forEach _troops;
  private _t=diag_tickTime+25;
  waitUntil {sleep 2;!alive _air || {(call _aboard)==0} || {diag_tickTime>_t}};
  if (alive _air && {isTouchingGround _air}) then {{if (alive _x && {local _x} && {!isPlayer _x} && {group _x isEqualTo _group} && {vehicle _x == _air}) then {moveOut _x;};} forEach _troops;};
  sleep 3;
 };
 _ag setCombatMode "BLUE";_ag setBehaviour "CARELESS";
 if ([_pickup,"GET IN"] call _flyLand) then {
  ["pickup landed"] call _log;
  {if ((call _current) && {alive _x} && {local _x} && {!isPlayer _x} && {group _x isEqualTo _group} && {isNull objectParent _x}) then {_x assignAsCargo _air;[_x] orderGetIn true;_x doMove (getPosATL _air);};} forEach _troops;
  private _timeout=diag_tickTime+150;
  waitUntil {sleep 3;!(call _guard) || {(_troops findIf {alive _x && {vehicle _x != _air}})<0} || {diag_tickTime>_timeout}};
  [format ["boarded %1/%2",call _aboard,{alive _x} count _troops]] call _log;
  if ((call _guard) && {(call _aboard)>0}) then {
   // Stragglers walk; they are not left assigned to a departing aircraft.
   {if ((call _current) && {alive _x} && {local _x} && {!isPlayer _x} && {group _x isEqualTo _group} && {vehicle _x != _air} && {assignedVehicle _x isEqualTo _air}) then {unassignVehicle _x;[_x] orderGetIn false;};} forEach _troops;
   if ([_landing,"GET OUT"] call _flyLand) then {
    ["drop landed"] call _log;
    call _unload;
    [format ["unloaded, %1 still aboard",call _aboard]] call _log;
    // Check after unloading too: the player's order may arrive while it waits.
    isNil {
     call _release;
     if ((call _current) && {(call _aboard)==0}) then {[_group,"ADVANCE",_target,"","AIR_TRANSPORT"] call NeroAI_fnc_executeMacro;};
     false
    };
   } else {_aborted=true;};
  } else {_aborted=true;};
 } else {_aborted=true;};
 /* Aborted with troops aboard (damage, known AA, timeout): land on the
  * nearest safe flat ground and put them out before returning — never fly
  * the squad back to base. */
 if (_aborted && {local _air} && {alive _air} && {alive _pilot} && {!isPlayer _pilot} && {(call _aboard)>0}) then {
  private _spot=[getPosATL _air,0,600,18,0,0.15,0] call BIS_fnc_findSafePos;
  if (_spot isEqualType [] && {count _spot>=2} && {(_air distance2D [_spot # 0,_spot # 1,0])<700}) then {
   if ([[_spot # 0,_spot # 1,0],"GET OUT",{local _air && {alive _air} && {alive _pilot} && {!isPlayer _pilot} && {fuel _air>0.05}}] call _flyLand) then {call _unload;};
  };
  [format ["aborted; emergency drop, %1 still aboard",call _aboard]] call _log;
 };
 call _release;
 if ((_group getVariable ["NeroWL_transportLease",-1]) isEqualTo _lease) then {_group setVariable ["NeroWL_transportLease",nil]; _group setVariable ["NeroWL_transportScript",nil];};
 if (local _air && {alive _air} && {alive _pilot} && {!isPlayer _pilot} && {crew _air findIf {isPlayer _x} < 0}) then {
  _air setVariable ["NeroAI_airState","RTB",true];
  if ([_home,"LAND",{local _air && {alive _air} && {alive _pilot} && {!isPlayer _pilot} && {fuel _air>0.1}}] call _flyLand) then {
   call _unload;
   _air engineOn false;
   _air setVariable ["NeroAI_airState","PARKED",true];
  } else {_air setVariable ["NeroAI_airState","UNAVAILABLE",true];};
 };
 [format ["finished aborted=%1",_aborted]] call _log;
};
_group setVariable ["NeroWL_transportScript",_handle];
[true,"Оплаченный вертолёт выполняет посадку, перевозку и возвращение; бойцы садятся физически."]
