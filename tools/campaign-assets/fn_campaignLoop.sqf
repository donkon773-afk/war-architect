private _cfg=missionConfigFile >> "CfgNeroOperation";private _last=serverTime;private _lastWave=serverTime;private _lastOrder=serverTime;private _lastLog=serverTime;
while {!NeroOP_campFinished} do {
 sleep 2;private _now=serverTime;private _elapsed=(_now-_last) max 0;_last=_now;
 /* Zeus reinforcements participate too; airborne crews do not capture ground. */
 private _units=allUnits select {alive _x && {!captive _x} && {lifeState _x!="INCAPACITATED"} && {!(_x getVariable ["ACE_isUnconscious",false])} && {vehicle _x==_x || {(vehicle _x) isKindOf "LandVehicle"}}};
 private _graphs=[0,1] apply {[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_x,_x] call NeroOP_fnc_campaignGraph};
 for "_node" from 0 to count NeroOP_campOwners-1 do {
  private _inside=[0,0];{if (alive _x && {!captive _x} && {lifeState _x!="INCAPACITATED"} && {!(_x getVariable ["ACE_isUnconscious",false])} && {_x distance2D (NeroOP_campPositions#_node)<=NeroOP_campRadii#_node}) then {private _side=[west,east] find side group _x;if (_side>=0) then {_inside set [_side,(_inside#_side)+1];};};} forEach _units;
  private _sources=[-1,-1];private _eligible=[false,false];
  for "_side" from 0 to 1 do {private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
   if (_node in (_graph#1)) then {private _adjacent=NeroOP_campLinks apply {if ((_x#0)==_node) then {_x#1} else {if ((_x#1)==_node) then {_x#0} else {-1}}};private _source=_adjacent findIf {_x>=0 && {_x in (_graph#0)} && {(NeroOP_campStocks#_x)>=getNumber(_cfg >> "captureCost")}};
    if (_source>=0) then {_sources set [_side,_adjacent#_source];_eligible set [_side,true];};
   };
   private _team=[west,east]#_side;if (_units findIf {(_team getFriend (side group _x))<.6 && {_x distance2D (NeroOP_campPositions#_node)<=NeroOP_campRadii#_node}}>=0) then {_eligible set [_side,false];};
  };
  private _progress=[NeroOP_campOwners#_node,NeroOP_campProgress#_node,_inside,_eligible,_elapsed,getNumber(_cfg >> "captureSeconds"),if(getNumber(_cfg >> "DevMode" >> "coordinatedAI")==1) then {[0,1] apply {_node in ((_graphs#_x)#1)}} else {[true,true]}] call NeroOP_fnc_campaignProgress;
  private _charge=_progress#3;
  if (_charge>=0) then {isNil {NeroOP_campSeq=NeroOP_campSeq+1;private _result=[NeroOP_campStocks,NeroOP_campLedger,"spend","capture:"+str NeroOP_campSeq,_sources#_charge,-1,getNumber(_cfg >> "captureCost")] call NeroOP_fnc_campaignStock;
   if (_result#2 || {getNumber(_cfg >> "captureCost")==0}) then {NeroOP_campStocks=_result#0;NeroOP_campLedger=_result#1;NeroOP_campOwners set [_node,_charge];NeroOP_campStocks set [_node,0];diag_log format ["[NeroOP CAMPAIGN] CAPTURE sector=%1 side=%2",_node,_charge];} else {_progress set [1,NeroOP_campProgress#_node];};
  };};NeroOP_campProgress set [_node,_progress#1];
 };
 _graphs=[0,1] apply {[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_x,_x] call NeroOP_fnc_campaignGraph};
 NeroOP_campAirfieldService=[[],[]];{private _field=_x;private _nearest=[NeroOP_campPositions,_field#1] call NeroOP_fnc_campaignNearest;if (count _nearest>0 && {((_nearest#0)#0)<6000}) then {private _node=(_nearest#0)#1;private _owner=NeroOP_campOwners#_node;if (_owner>=0 && {_node in ((_graphs#_owner)#0)}) then {(NeroOP_campAirfieldService#_owner) pushBack [_field#0,_field#1,_node];};};} forEach NeroOP_campAirfields;
 {private _side=_x;private _main=NeroOP_campMainAirfields#_side;private _root=NeroOP_campRoots#_side;if (count _main==2 && {NeroOP_campOwners#_root==_side}) then {private _near=[NeroOP_campPositions,_main#1] call NeroOP_fnc_campaignNearest;private _enemy=count _near>0 && {((_near#0)#0)<1200} && {(NeroOP_campOwners#((_near#0)#1))==1-_side};if (!_enemy) then {(NeroOP_campAirfieldService#_side) pushBack [_main#0,_main#1,_root];};};} forEach [0,1];
 private _connected=_graphs apply {_x#0};private _reserves=[0,1] apply {(NeroOP_campBudget#_x)-(NeroOP_campIssued#_x)};private _active=[0,1] apply {private _side=_x;{(_x getVariable ["NeroOP_side",-1])==_side && {units _x findIf {alive _x}>=0}} count NeroOP_campGroups};
 private _remaining=(getNumber(_cfg >> "duration")-(serverTime-NeroOP_campStartedAt)) max 0;
 NeroOP_campState=[+NeroOP_campOwners,+NeroOP_campStocks,NeroOP_campProgress apply {+_x},_connected,_reserves,_active,NeroOP_campConvoys apply {[_x#1,_x#3,_x#4]},_remaining];publicVariable "NeroOP_campState";
 {private _side=_x;private _n=_forEachIndex;private _color=if (_side<0) then {"ColorYellow"} else {["ColorBLUFOR","ColorOPFOR"]#_side};private _connectedNode=_side>=0 && {_n in (_connected#_side)};
  ("NeroOP_sector_"+str _n) setMarkerColor _color;private _marker="NeroOP_sectorLabel_"+str _n;_marker setMarkerColor _color;_marker setMarkerText format ["%1 · %2%3",NeroOP_campNames#_n,floor (NeroOP_campStocks#_n),if (_side>=0 && {!_connectedNode}) then {" · ОТРЕЗАН"} else {""}];
 } forEach NeroOP_campOwners;
 {private _a=NeroOP_campOwners#(_x#0);private _b=NeroOP_campOwners#(_x#1);("NeroOP_link_"+str _forEachIndex) setMarkerColor (if (_a!=_b) then {"ColorOrange"} else {if (_a<0) then {"ColorYellow"} else {["ColorBLUFOR","ColorOPFOR"]#_a}});} forEach NeroOP_campLinks;
 private _winner=[NeroOP_campOwners,NeroOP_campRoots] call NeroOP_fnc_campaignOutcome;
 if (_winner>=0) then {[_winner,"enemy HQ captured"] call NeroOP_fnc_campaignFinish;} else {if (_remaining<=0) then {[-2,"session time"] call NeroOP_fnc_campaignFinish;} else {
  if (_now-_lastWave>=getNumber(_cfg >> "reinforcementDelay")) then {_lastWave=_now;{isNil {[_x] call NeroOP_fnc_campaignSpawn;};} forEach [0,1];};
  {if (isPlayer _x && {alive _x} && {side group _x in [west,east]} && {!(group _x getVariable ["NeroOP_campGroup",false])}) then {[_x] call NeroOP_fnc_campaignRequest;};} forEach allPlayers;
  {private _commander=_x getVariable ["NeroOP_slotCommander",objNull];if (_x getVariable ["NeroOP_claimed",false] && {units _x findIf {alive _x && {isPlayer _x}}<0} && {!alive _commander || {group _commander!=_x}} && {_now-(_x getVariable ["NeroOP_claimedAt",_now])>20}) then {_x setVariable ["NeroOP_claimed",false];_x setVariable ["NeroOP_slotCommander",objNull,true];};} forEach NeroOP_campGroups;
  if (_now-_lastOrder>=20) then {_lastOrder=_now;[] call NeroOP_fnc_campaignTacticalTick;{[_x] call NeroOP_fnc_campaignOrder;} forEach NeroOP_campGroups;};
 };};
 if (_now-_lastLog>=30) then {_lastLog=_now;diag_log format ["[NeroOP CAMPAIGN] STATE owners=%1 stock=%2 groups=%3 reserve=%4 convoys=%5 fps=%6",NeroOP_campOwners,NeroOP_campStocks,_active,_reserves,count NeroOP_campConvoys,diag_fps];};
};
