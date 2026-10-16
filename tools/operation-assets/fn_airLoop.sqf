if (!isServer) exitWith {};
private _cfg=missionConfigFile >> "CfgNeroOperation";
private _reinforce=[serverTime,serverTime];private _telemetry=serverTime;
while {!NeroOP_finished} do {
 {
  private _plane=_x;
  if (!isNull _plane) then {
   if (!alive _plane) then {[_plane] call NeroOP_fnc_airLoss;} else {
    private _pending=_plane getVariable ["NeroOP_pendingAt",-100];
    if (_pending>=0 && {serverTime-_pending>30}) then {_plane enableSimulationGlobal true;_plane allowDamage true;_plane setDamage 1;diag_log format ["[NeroOP AIR] BOARD TIMEOUT id=%1",_plane getVariable ["NeroOP_flight",""]];};
    if (_pending<0 && {isNull driver _plane || {!alive driver _plane}}) then {_plane setDamage 1;};
    // Targeting applies only to server-local AI pilots and observed enemy aircraft.
    private _pilot=driver _plane;
    if (!isNull _pilot && {alive _pilot} && {!isPlayer _pilot} && {local _pilot} && {isNull (_plane getVariable ["NeroOP_player",objNull])}) then {
     private _enemy=_pilot findNearestEnemy _plane;
     if (!isNull _enemy && {_enemy isKindOf "Plane"} && {(_enemy getVariable ["NeroOP_side",-1]) in [0,1]} && {(_enemy getVariable ["NeroOP_side",-1])!=(_plane getVariable ["NeroOP_side",-1])}) then {_pilot doTarget _enemy;_pilot doFire _enemy;};
    };
   };
  };
 } forEach +NeroOP_planes;
 private _active=[0,0];
 {if (!isNull _x && {alive _x} && {!(_x getVariable ["NeroOP_lost",false])}) then {private _idx=_x getVariable ["NeroOP_side",-1];if (_idx in [0,1]) then {_active set [_idx,(_active#_idx)+1];};};} forEach NeroOP_planes;
 private _remaining=getNumber(_cfg >> "duration")-(serverTime-NeroOP_startedAt);
 private _outcome=[NeroOP_account#0,NeroOP_budgets,getNumber(_cfg >> "scoreTarget"),serverTime-NeroOP_startedAt,getNumber(_cfg >> "duration")] call NeroOP_fnc_airOutcome;
 if ((_outcome#0)!="") then {[_outcome#0,_outcome#1] call NeroOP_fnc_airFinish;} else {
  for "_i" from 0 to 1 do {
   if (serverTime-(_reinforce#_i)>=getNumber(_cfg >> "reinforcementDelay")) then {
    _reinforce set [_i,serverTime];private _cap=getNumber(_cfg >> (["WEST","EAST"]#_i) >> "active");
    for "_n" from 1 to (2 min (_cap-(_active#_i))) do {private _plane=objNull;isNil {_plane=[_i] call NeroOP_fnc_airSpawn;};};
   };
  };
  private _reserve=[0,1] apply {(NeroOP_budgets#_x)-(((NeroOP_account#0)#_x)#0)};
  NeroOP_state=["battle",NeroOP_account#0,_active,_reserve,0 max _remaining,"",""];publicVariable "NeroOP_state";
 };
 if (serverTime-_telemetry>=30) then {_telemetry=serverTime;diag_log format ["[NeroOP AIR] TELEMETRY fps=%1 active=%2 stats=%3 remaining=%4",diag_fps,_active,NeroOP_account#0,floor _remaining];};
 // Retire only this operation's old wrecks; no player-occupied aircraft are removed.
 {if (!isNull _x && {_x getVariable ["NeroOP_lost",false]} && {serverTime-(_x getVariable ["NeroOP_lostAt",serverTime])>90} && {(crew _x findIf {isPlayer _x})<0}) then {private _group=_x getVariable ["NeroOP_group",grpNull];{if (!isPlayer _x) then {deleteVehicle _x;};} forEach crew _x;deleteVehicle _x;if (!isNull _group && {count units _group==0}) then {deleteGroup _group;};};} forEach +NeroOP_planes;
 NeroOP_planes=NeroOP_planes select {!isNull _x};
 sleep 2;
};
