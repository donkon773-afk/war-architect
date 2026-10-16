/* Saved mission config only. Coordinates are validated by the application. */
params ["_side","_class","_center",["_owner",objNull],["_crew",true]];
if(!isServer || {!isClass(configFile >> "CfgVehicles" >> _class)})exitWith{objNull};
private _cfg=missionConfigFile >> "CfgNeroDesign";
if(count vehicles>=getNumber(_cfg >> "maxVehicles"))exitWith{objNull};
if(getNumber(configFile >> "CfgVehicles" >> _class >> "side")!=([east,west,resistance]find _side))exitWith{objNull};
private _isAir=_class isKindOf "Air";
if(_isAir && {count(vehicles select {alive _x && {_x isKindOf "Air"} && {_x getVariable["NeroAI_ownerSide",side _x]isEqualTo _side}})>=5})exitWith{objNull};
private _pos=if(_class isKindOf "Ship")then{[]}else{_center findEmptyPosition[20,200,_class]};
if(_pos isEqualTo [] || {surfaceIsWater _pos})exitWith{diag_log format["[NeroWL Designer] no land spawn %1 %2",_class,_center];objNull};
if(_class isKindOf "Plane")then{_pos=[_pos#0,_pos#1,300];};
private _v=createVehicle[_class,_pos,[],0,"NONE"];
_v setVariable["NeroAI_ownerSide",_side,true];
if(_crew)then{
 createVehicleCrew _v;
 if(count allUnits>getNumber(_cfg >> "maxNPCs"))exitWith{private _g=group effectiveCommander _v;{_v deleteVehicleCrew _x;}forEach crew _v;deleteVehicle _v;if(!isNull _g)then{deleteGroup _g;};};
 if(alive _v)then{private _g=group effectiveCommander _v;if(!isNull _g)then{_g setVariable["NeroWL_initialAsset",true,true];_g setVariable["BIS_WL_groupVehs",[_v],true];};};
};
if(isNull _v)exitWith{objNull};
if(!isNull _owner)then{private _ledger=(group _owner)getVariable["BIS_WL_groupVehs",[]];_ledger pushBackUnique _v;(group _owner)setVariable["BIS_WL_groupVehs",_ledger,true];};
if(_isAir && {_crew})then{
 private _g=group effectiveCommander _v;_v setVariable["NeroAI_paidAir",true,true];_v setVariable["NeroAI_homeBase",_center,true];_v setVariable["NeroAI_airState","READY",true];_g setVariable["NeroAI_isBaseAssetCrew",true,true];_v flyInHeight 300;
 private _wp=_g addWaypoint[_center,0];_wp setWaypointType "LOITER";_wp setWaypointLoiterRadius 800;
};
diag_log format["[NeroWL Designer] asset=%1 side=%2 position=%3",_class,_side,getPosATL _v];_v
