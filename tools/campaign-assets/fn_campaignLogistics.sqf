/* Supply/vehicle loop is independent of capture, group orders and Zeus. */
private _cfg=missionConfigFile >> "CfgNeroOperation";private _last=serverTime;private _lastDispatch=[serverTime-100,serverTime-100];private _lastSave=serverTime-55;
while {!NeroOP_campFinished} do {
 sleep 2;private _now=serverTime;private _elapsed=((_now-_last) max 0) min 10;_last=_now;
 NeroOP_campSupplyBlocked=NeroOP_campSupplyBlocked apply {_x select {(_x#1)>serverTime}};
 private _graphs=[0,1] apply {[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_x,_x] call NeroOP_fnc_campaignGraph};
 {private _n=_forEachIndex;private _owner=NeroOP_campOwners#_n;
  if (_x>0 && {_owner>=0} && {_n in ((_graphs#_owner)#0)}) then {isNil {private _result=[NeroOP_campStocks,NeroOP_campLedger,"produce","",-1,_n,_x*_elapsed/60] call NeroOP_fnc_campaignStock;NeroOP_campStocks=_result#0;};};
 } forEach NeroOP_campIncome;
 {private _entry=_x;private _truck=_x#5;private _side=_x#1;private _path=_x#8;
  private _lost=isNull _truck || {!alive _truck} || {!alive driver _truck} || {serverTime>(_x#7)} || {_path findIf {(NeroOP_campOwners#_x)!=_side}>=0};
  if (_lost) then {[_entry,false] call NeroOP_fnc_campaignConvoyFinish;} else {
   (_truck getVariable ["NeroOP_campCargoMarker",""]) setMarkerPos getPosATL _truck;
   if (_truck distance2D (NeroOP_campPositions#(_x#3))<(NeroOP_campRadii#(_x#3))) then {[_entry,true] call NeroOP_fnc_campaignConvoyFinish;};
  };
 } forEach +NeroOP_campConvoys;
 /* Autonomous fleet: deficits, retries, reusable vehicles, no manual request required. */
 {private _truck=_x;private _side=_truck getVariable ["NeroOP_side",-1];
  if (alive _truck && {alive driver _truck} && {local _truck} && {_side in [0,1]} && {!([_truck] call NeroOP_fnc_campaignPlayerControl)}) then {
   private _g=group driver _truck;_g setBehaviourStrong "SAFE";_g setCombatMode "BLUE";_g setSpeedMode "FULL";driver _truck disableAI "AUTOCOMBAT";_truck limitSpeed getNumber(_cfg >> "Gameplay" >> "truckSpeed");
   private _home=_truck getVariable ["NeroOP_supplyHome",NeroOP_campRoots#_side];
   if (_truck getVariable ["NeroOP_supplyReturning",false] && {_truck distance2D (NeroOP_campPositions#_home)<(NeroOP_campRadii#_home)+100}) then {_truck setVariable ["NeroOP_supplyReturning",false];};
   private _active=NeroOP_campConvoys findIf {(_x#5)==_truck}>=0;
   private _p=getPosATL _truck;private _anchor=_truck getVariable ["NeroOP_supplyAnchor",[_p,_now]];
   if (_p distance2D (_anchor#0)>20) then {_truck setVariable ["NeroOP_supplyAnchor",[_p,_now]];} else {
    if (_now-(_anchor#1)>45 && {_active || {_truck getVariable ["NeroOP_supplyReturning",false]}} && {!(_truck getVariable ["NeroOP_supplyPlanning",false])}) then {
     _truck engineOn true;private _wp=currentWaypoint _g;if (_wp<count waypoints _g) then {driver _truck doMove waypointPosition [_g,_wp];};_truck setVariable ["NeroOP_supplyAnchor",[_p,_now]];diag_log format ["[NeroOP SUPPLY] STUCK RETRY side=%1 truck=%2",_side,typeOf _truck];
    };
   };if (isNil {_truck getVariable "NeroOP_supplyAnchor"}) then {_truck setVariable ["NeroOP_supplyAnchor",[_p,_now]];};
   if (!_active && {!(_truck getVariable ["NeroOP_supplyPlanning",false])} && {_now>=(_truck getVariable ["NeroOP_supplyRetryAt",0])} && {!(_truck getVariable ["NeroOP_supplyReturning",false])}) then {
    private _nodes=(_graphs#_side)#0;private _source=_nodes findIf {_truck distance2D (NeroOP_campPositions#_x)<(NeroOP_campRadii#_x)+150 && {(NeroOP_campStocks#_x)>getNumber(_cfg >> "convoyCargo")+100}};
    if (_source<0) then {_truck setVariable ["NeroOP_supplyRetryAt",_now+60];[_truck,_side] spawn NeroOP_fnc_campaignTruckReturn;} else {
     if (_now-(_lastDispatch#_side)>5) then {
      private _from=_nodes#_source;private _rank=[];
      {private _node=_x;private _front=NeroOP_campLinks findIf {(_x#0)==_node && {(NeroOP_campOwners#(_x#1))!=_side} || {(_x#1)==_node && {(NeroOP_campOwners#(_x#0))!=_side}}}>=0;
       private _wanted=if (_front) then {1200} else {600};private _blocked=(NeroOP_campSupplyBlocked#_side) findIf {(_x#0)==_node && {(_x#1)>_now}}>=0;
       if (_node!=_from && {!_blocked} && {(NeroOP_campStocks#_node)<_wanted} && {NeroOP_campConvoys findIf {(_x#1)==_side && {(_x#3)==_node}}<0}) then {_rank pushBack [if (_front) then {0} else {1},NeroOP_campStocks#_node,_truck distance2D (NeroOP_campPositions#_node),_node];};
      } forEach _nodes;_rank sort true;
      if (count _rank>0) then {_lastDispatch set [_side,_now];[_side,(_rank#0)#3,[],_truck] spawn NeroOP_fnc_campaignConvoy;};
     };
    };
   };
   if (_truck getVariable ["NeroOP_supplyReturning",false] && {!_active} && {_now>=(_truck getVariable ["NeroOP_supplyRetryAt",0])} && {currentWaypoint _g>=count waypoints _g}) then {_truck setVariable ["NeroOP_supplyRetryAt",_now+90];[_truck,_side,_home] spawn NeroOP_fnc_campaignTruckReturn;};
  };
 } forEach +NeroOP_campSupplyTrucks;
 if (_now-_lastSave>=60) then {_lastSave=_now;[] call NeroOP_fnc_campaignSave;};
 if (count NeroOP_campLedger>600) then {private _open=NeroOP_campLedger select {(_x#1)==0};private _done=NeroOP_campLedger select {(_x#1)!=0};NeroOP_campLedger=_open+(_done select [(count _done-500) max 0]);};
};
