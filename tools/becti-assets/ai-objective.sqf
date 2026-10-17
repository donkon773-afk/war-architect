params ["_group","_side"];
private _logic=_side call CTI_CO_FNC_GetSideLogic;private _id=_side call CTI_CO_FNC_GetSideID;
private _towns=if (missionNamespace getVariable ["CTI_SM_STRATEGIC",0]==1) then {(_logic getVariable ["CTI_ACTIVE",[]])+(_logic getVariable ["CTI_AVAILLABLE",[]])} else {+CTI_Towns};
_towns=_towns arrayIntersect _towns;
private _avoid=_group getVariable ["WA_BECTI_avoidTown",[objNull,0]];
_towns=_towns select {!isNull _x && {_x getVariable ["cti_town_sideID",-1]!=_id} && {!surfaceIsWater getPosATL _x} && {_x!=(_avoid#0) || {serverTime>(_avoid#1)}}};
private _reports=[_group] call NeroOP_fnc_bectiAIContacts;
private _rank=[];private _teams=_side call CTI_CO_FNC_GetSideGroups;
{
 private _town=_x;private _assigned={_x!=_group && {_x getVariable ["cti_order_pos",objNull] isEqualTo _town}} count _teams;
 private _known={(_x#1) distance2D _town<1000} count _reports;
 _rank pushBack [(leader _group distance2D _town)+3000*floor(_assigned/3)+_known*250,_forEachIndex];
} forEach _towns;
_rank sort true;
if (count _rank==0) then {objNull} else {_towns#((_rank#0)#1)}
