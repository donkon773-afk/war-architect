/* Safe partial field repair, requiring an actual engineer/toolkit or repair truck.
   Native BECTI funds pay for it. Never fills fuel/ammunition or repairs during contact. */
params ["_v","_group","_seed"];
if (!isServer || {isRemoteExecuted} || {!local _v} || {_v getVariable ["WA_BECTI_repairBusy",false]}) exitWith {};
_v setVariable ["WA_BECTI_repairBusy",true];
private _side=side _group;
private _engineer=(units _group select {alive _x && {local _x} && {_x getUnitTrait "engineer"} && {"ToolKit" in items _x}}) param [0,objNull];
private _originalRole=if (isNull _engineer) then {[]} else {assignedVehicleRole _engineer};
private _trucks=vehicles select {alive _x && {getRepairCargo _x>0} && {alive driver _x} && {side group driver _x==_side} && {_x distance2D _v<1200} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}};
private _truck=_trucks param [0,objNull];
private _safe={alive _v && {local _v} && {local _group} && {_group getVariable ["cti_order_seed",-1]==_seed} && {!([_group] call NeroOP_fnc_campaignPlayerControl)} && {([_group] call NeroOP_fnc_bectiAIContacts) findIf {(_x#1) distance2D _v<650}<0}};
if (call _safe && {!isNull _engineer || {!isNull _truck}}) then {
 if (!isNull _truck && {_truck distance2D _v>20}) then {driver _truck doMove (getPosATL _v getPos [12,getDir _v+90]);};
 private _deadline=serverTime+60;
 if (!isNull _engineer) then {unassignVehicle _engineer;moveOut _engineer;_engineer doMove (getPosATL _v getPos [4,getDir _v+90]);};
 waitUntil {sleep 1;!call _safe || {serverTime>_deadline} || {!isNull _engineer && {_engineer distance _v<7}} || {!isNull _truck && {_truck distance2D _v<20}}};
 private _available={!isNull _engineer && {alive _engineer} && {_engineer distance _v<7} || {!isNull _truck && {_truck distance2D _v<20}}};
 if (call _safe && {call _available}) then {
  if (!isNull _engineer) then {_engineer playMoveNow "Acts_carFixingWheel";};
  private _end=serverTime+12;
  waitUntil {sleep 1;serverTime>=_end || {!call _safe} || {!call _available}};
  if (call _safe && {call _available}) then {
   isNil {
    if (([_group,_side] call CTI_CO_FNC_GetFunds)>=20) then {
     [_group,_side,-20] call CTI_CO_FNC_ChangeFunds;
     private _hits=getAllHitPointsDamage _v;private _damage=(damage _v) min .2;
     if (!isNil "ace_repair_fnc_setDamage") then {[_v,_damage,false] call ace_repair_fnc_setDamage;} else {_v setDamage [_damage,false];};
     {_v setHitIndex [_forEachIndex,_x min .2,false];} forEach (_hits param [2,[]]);
     diag_log format ["[WA BECTI REPAIR] DONE group=%1 class=%2 damage=%3",_group,typeOf _v,damage _v];
    };
   };
  };
 };
};
if (!isNull _engineer && {alive _engineer} && {call _safe} && {vehicle _engineer==_engineer}) then {
 if (count _originalRole>0 && {toLower(_originalRole#0)=="driver"}) then {_engineer assignAsDriver _v;} else {if (count _originalRole>1 && {toLower(_originalRole#0)=="turret"}) then {_engineer assignAsTurret [_v,_originalRole#1];} else {_engineer assignAsCargo _v;};};[_engineer] orderGetIn true;
};
_v setVariable ["WA_BECTI_repairBusy",false];
