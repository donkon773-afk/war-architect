/* Scheduled road search; the final vehicle/stock reservation is atomic. */
params ["_side","_destination",["_restore",[]],["_hint",objNull]];
if (!isServer || {NeroOP_campFinished} || {!(_side in [0,1])} || {_destination<0} || {_destination>=count NeroOP_campOwners}) exitWith {};
if (count _restore==0 && {serverTime-(NeroOP_campDispatchAt#_side)<4}) exitWith {};if (count _restore==0) then {NeroOP_campDispatchAt set [_side,serverTime];};
private _cfg=missionConfigFile >> "CfgNeroOperation";private _source=if (count _restore>0) then {_restore#1} else {NeroOP_campRoots#_side};private _limit=getNumber(_cfg >> "convoyLimit");
if ({(_x#1)==_side} count NeroOP_campConvoys>=_limit) exitWith {};
private _truck=objNull;private _loading=count _restore>0;
if (_loading) then {isNil {_truck=[_side,objNull,[_side,_restore#4,0,1]] call NeroOP_fnc_campaignSupplyTruck;};} else {private _idle=NeroOP_campSupplyTrucks select {alive _x && {local _x} && {alive driver _x} && {(_x getVariable ["NeroOP_side",-1])==_side} && {_x getVariable ["NeroOP_campCargo",0]==0} && {!(_x getVariable ["NeroOP_supplyReserved",false])} && {!(_x getVariable ["NeroOP_supplyPlanning",false])} && {!(_x getVariable ["NeroOP_supplyReturning",false])} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}};if (count _idle>0) then {_truck=if (_hint in _idle) then {_hint} else {_idle#0};};};
if (isNull _truck) exitWith {};
if (!_loading) then {private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;private _near=(_graph#0) findIf {_truck distance2D (NeroOP_campPositions#_x)<(NeroOP_campRadii#_x)+150 && {(NeroOP_campStocks#_x)>=getNumber(_cfg >> "convoyCargo")+100}};if (_near>=0) then {_source=(_graph#0)#_near;} else {_source=-1;};};
if (_source<0 || {_source==_destination}) exitWith {};
private _path=[NeroOP_campOwners,NeroOP_campLinks,_source,_destination,_side] call NeroOP_fnc_campaignPath;
if (count _path<2) exitWith {};
private _amount=if (count _restore>0) then {_restore#3} else {(getNumber(_cfg >> "convoyCargo")) min (NeroOP_campStocks#_source) min (5000-(NeroOP_campStocks#_destination))};
if (_amount<20 && {count _restore==0}) exitWith {};
private _route=[];private _from=getPosATL _truck;private _ok=true;
private _legs=[_destination];_truck setVariable ["NeroOP_supplyPlanning",true];
{private _to=NeroOP_campPositions#_x;private _segment=[_from,_to,_side] call NeroOP_fnc_campaignRoad;
 if (count _segment==0) exitWith {_ok=false;};_route append _segment;_from=_to;
} forEach _legs;
if (!_ok || {count _route<2}) exitWith {_truck setVariable ["NeroOP_supplyPlanning",false];(NeroOP_campSupplyBlocked#_side) pushBack [_destination,serverTime+120];diag_log format ["[NeroOP CAMPAIGN] NO ROAD side=%1 destination=%2 restored=%3",_side,_destination,count _restore>0];};
isNil {
 private _pathNow=[NeroOP_campOwners,NeroOP_campLinks,_source,_destination,_side] call NeroOP_fnc_campaignPath;
 if (!NeroOP_campFinished && {count _pathNow>1} && {{(_x#1)==_side} count NeroOP_campConvoys<_limit}) then {
  private _pos=getPosATL _truck;private _group=group driver _truck;private _driver=driver _truck;
  if (alive _truck && {alive _driver} && {!(_truck getVariable ["NeroOP_supplyReserved",false])} && {!([_truck] call NeroOP_fnc_campaignPlayerControl)}) then {
   private _committed=false;
   if (!isNull _truck && {!isNull _driver} && {driver _truck==_driver}) then {
    NeroOP_campSeq=NeroOP_campSeq+1;private _id="cargo:"+str NeroOP_campSeq;private _ledger=[NeroOP_campStocks,NeroOP_campLedger,if (count _restore>0) then {"restore"} else {"dispatch"},_id,_source,_destination,_amount] call NeroOP_fnc_campaignStock;
    if (_ledger#2) then {NeroOP_campStocks=_ledger#0;NeroOP_campLedger=_ledger#1;_committed=true;_truck setDir (_pos getDir (_route#1));_truck limitSpeed getNumber(_cfg >> "Gameplay" >> "truckSpeed");_truck setVariable ["NeroOP_supplyReserved",true];
     {deleteWaypoint _x;} forEach +(waypoints _group);_truck engineOn true;_truck setVariable ["NeroOP_supplyReturning",false];_truck setVariable ["NeroOP_campCargo",_amount,true];_group setBehaviourStrong "SAFE";_group setCombatMode "BLUE";
     {private _wp=_group addWaypoint [_x,5];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";_wp setWaypointBehaviour "SAFE";} forEach _route;
     _group setCurrentWaypoint [_group,1];
     private _ttl=if (count _restore>0) then {_restore#5} else {getNumber(_cfg >> "convoyTimeout")};
     NeroOP_campConvoys pushBack [_id,_side,_source,_destination,_amount,_truck,_group,serverTime+_ttl,_pathNow];
     private _marker=createMarker ["NeroOP_convoy_"+str NeroOP_campSeq,_pos];_marker setMarkerType "mil_box";_marker setMarkerColor (["ColorBLUFOR","ColorOPFOR"]#_side);_marker setMarkerText format ["Снабжение: %1",round _amount];_truck setVariable ["NeroOP_campCargoMarker",_marker];
     diag_log format ["[NeroOP CAMPAIGN] CONVOY DISPATCH side=%1 target=%2 cargo=%3 restored=%4 roads=%5",_side,_destination,_amount,count _restore>0,count _route];
    };
   };
   if (!_committed) then {_truck setVariable ["NeroOP_supplyReserved",false];};
  };
 };
};

_truck setVariable ["NeroOP_supplyPlanning",false];
