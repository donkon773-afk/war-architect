/* Saved mission config only. Coordinates are validated by the application. */
params ["_side","_class","_center",["_owner",objNull],["_crew",true]];
if(!isServer || {!isClass(configFile >> "CfgVehicles" >> _class)})exitWith{objNull};
private _cfg=missionConfigFile >> "CfgNeroDesign";
if((["VEHICLE"]call NeroAI_fnc_designPurchaseCapacity)<=0)exitWith{objNull};
if(getNumber(configFile >> "CfgVehicles" >> _class >> "side")!=([east,west,resistance]find _side))exitWith{objNull};
private _isAir=_class isKindOf "Air";
private _airLimit=(missionNamespace getVariable["NeroWL_airLimit",5]) max 0 min 5;
if(_isAir && {!(missionNamespace getVariable["NeroAI_airEnabled",true]) || {count(vehicles select {alive _x && {_x isKindOf "Air"} && {_x getVariable["NeroAI_ownerSide",side _x]isEqualTo _side}})>=_airLimit}})exitWith{objNull};
private _pos=if(_class isKindOf "Ship")then{[_center,20,500,20,2,0,0,[],[]]call BIS_fnc_findSafePos}else{_center findEmptyPosition[20,200,_class]};
if(_pos isEqualTo [] || {surfaceIsWater _pos && {!(_class isKindOf "Ship")}})exitWith{diag_log format["[NeroWL Designer] no land spawn %1 %2",_class,_center];objNull};
private _crewRoom=["INFANTRY"]call NeroAI_fnc_designPurchaseCapacity;
if(_crew && {_crewRoom<=0})exitWith{objNull};
if(_class isKindOf "Plane")then{_pos=[_pos#0,_pos#1,300];};
private _v=createVehicle[_class,_pos,[],0,"NONE"];
_v setVariable["NeroAI_ownerSide",_side,true];
if(_crew)then{
 createVehicleCrew _v;
 if(count crew _v>_crewRoom)exitWith{private _g=group effectiveCommander _v;{_v deleteVehicleCrew _x;}forEach crew _v;deleteVehicle _v;if(!isNull _g)then{deleteGroup _g;};};
 if(alive _v)then{private _g=group effectiveCommander _v;if(!isNull _g)then{if(!isNull _owner && {!isPlayer _owner} && {!_isAir})then{(units _g)joinSilent(group _owner);if(count units _g==0)then{deleteGroup _g;};_g=group _owner;};_g setVariable["NeroWL_initialAsset",true,true];_g setVariable["BIS_WL_groupVehs",[_v],true];};};
};
if(isNull _v)exitWith{objNull};
if(!isNull _owner)then{private _ledger=(group _owner)getVariable["BIS_WL_groupVehs",[]];_ledger pushBackUnique _v;(group _owner)setVariable["BIS_WL_groupVehs",_ledger,true];};
if(_isAir && {_crew})then{
 private _g=group effectiveCommander _v;_v setVariable["NeroWL_paidAir",true,true];_v setVariable["BIS_WL_itemOwner",_owner,true];private _home=missionNamespace getVariable[format["BIS_WL_base_%1",_side],objNull];_v setVariable["NeroWL_homeSector",_home,true];_v setVariable["NeroWL_airport",-1,true];private _role=getText(missionConfigFile >> "CfgWLRequisitionPresets" >> "NeroWL_RHSStart" >> str _side >> "Aircraft" >> _class >> "NeroWL_role");private _airRole=if(_role=="JET_FIGHTER")then{"INTERCEPT"}else{if(_role=="AIR_TRANSPORT")then{"TRANSPORT"}else{"CAS"}};_v setVariable["NeroAI_assetRole",_airRole,true];if(!isNull _owner && {!isPlayer _owner})then{group _owner setVariable["NeroWL_role",if(_airRole=="INTERCEPT")then{"AIR_SUPERIORITY"}else{if(_airRole=="TRANSPORT")then{"AIR_TRANSPORT"}else{"AIR_CAS"}},true];};_v setVariable["NeroAI_homeBase",_center,true];_v setVariable["NeroAI_airState","READY",true];_g setVariable["NeroAI_isBaseAssetCrew",true,true];_v flyInHeight 300;if(_class isKindOf "Plane")then{_v setVelocityModelSpace[0,160,0];};
 private _wp=_g addWaypoint[_center,0];_wp setWaypointType "LOITER";_wp setWaypointLoiterRadius 800;
};
diag_log format["[NeroWL Designer] asset=%1 side=%2 position=%3",_class,_side,getPosATL _v];_v
