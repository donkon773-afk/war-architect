/* Paid garage slot, reused by the convoy dispatcher. No free vehicle replacement. */
params ["_side",["_unit",objNull],["_restore",[]]];
if (!isServer || {!(_side in [0,1])}) exitWith {objNull};
private _cfg=missionConfigFile >> "CfgNeroOperation";private _max=getNumber(_cfg >> "convoyLimit");private _trucks=NeroOP_campSupplyTrucks select {alive _x && {alive driver _x} && {(_x getVariable ["NeroOP_side",-1])==_side}};
if (count _trucks>=_max) exitWith {objNull};
private _price=getNumber(_cfg >> "Gameplay" >> "truckCost");private _source=if (isNull _unit) then {NeroOP_campRoots#_side} else {[_unit,_side,_price] call NeroOP_fnc_campaignWarehouse};
if (count _restore==0 && {_source!=NeroOP_campRoots#_side}) exitWith {objNull};
if (_source<0 || {count _restore==0 && {(NeroOP_campStocks#_source)<_price}}) exitWith {objNull};
private _army=_cfg >> (["WEST","EAST"]#_side);private _class=getText(_army >> "truckClass");private _point=if (count _restore>0) then {_restore#1} else {NeroOP_campPositions#_source};private _pos=[_point,15,80,6,0,.3,0,[],[_point,_point]] call BIS_fnc_findSafePos;
if (surfaceIsWater _pos || {!(_class isKindOf "LandVehicle")}) exitWith {objNull};
_pos=_pos findEmptyPosition [0,50,_class];if (count _pos<2) exitWith {objNull};
private _truck=createVehicle [_class,_pos,[],0,"NONE"];private _group=createGroup [[west,east]#_side,true];private _driver=_group createUnit [(getArray(_army >> "classes"))#0,_pos,[],0,"NONE"];_driver assignAsDriver _truck;_driver moveInDriver _truck;_driver disableAI "AUTOCOMBAT";_driver setVariable ["lambs_danger_disableAI",true];
private _ok=!isNull _truck && {alive _driver} && {driver _truck==_driver};
if (_ok && {count _restore==0}) then {NeroOP_campSeq=NeroOP_campSeq+1;private _spent=[NeroOP_campStocks,NeroOP_campLedger,"spend","truck:"+str NeroOP_campSeq,_source,-1,_price] call NeroOP_fnc_campaignStock;_ok=_spent#2;if (_ok) then {NeroOP_campStocks=_spent#0;NeroOP_campLedger=_spent#1;};};
if (!_ok) exitWith {{deleteVehicle _x;} forEach units _group;deleteGroup _group;deleteVehicle _truck;objNull};
_truck setVariable ["NeroOP_side",_side,true];_truck setVariable ["NeroOP_supplyTruck",true,true];_truck setVariable ["NeroOP_campCargo",0,true];_truck limitSpeed getNumber(_cfg >> "Gameplay" >> "truckSpeed");_group setBehaviourStrong "SAFE";_group setCombatMode "BLUE";_truck engineOn true;_truck setVariable ["NeroOP_supplyPlanning",false];_truck setVariable ["NeroOP_supplyReturning",false];
if (count _restore>0) then {_truck setDamage (_restore#2);_truck setFuel (_restore#3);};NeroOP_campSupplyTrucks pushBack _truck;_truck
