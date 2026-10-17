params ["_category","_group","_side","_teams"];
if (!isServer || {isRemoteExecuted}) exitWith {};
if ([_group] call NeroOP_fnc_campaignPlayerControl) exitWith {};
if (_group getVariable ["WA_BECTI_fixedRole",false]) exitWith {};
private _rank=[];
{
 private _name=_x#0;private _template=missionNamespace getVariable [format ["CTI_SQUAD_%1_%2",_side,_name],[]];
 if (count _template>3) then {
  private _pool=_template#2;
  private _usable=_pool findIf {private _c=configFile >> "CfgVehicles" >> (_x#0);isClass _c && {(_x#0) isKindOf "Man" || {getNumber(_c >> "maxSpeed")>10 && {getNumber(_c >> "hasDriver")==1}}}}>=0;
  if (_usable) then {_rank pushBack [{_x getVariable ["cti_role",""]==_name} count _teams,_forEachIndex];};
 };
} forEach _category;
_rank sort true;
private _role=if (count _rank>0) then {(_category#((_rank#0)#1))#0} else {"Infantry"};
_group setVariable ["cti_role",_role,true];
if (_role!=(_group getVariable ["WA_BECTI_lastRole",""])) then {_group setVariable ["WA_BECTI_lastRole",_role];diag_log format ["[WA BECTI ROLE] side=%1 group=%2 role=%3",_side,_group,_role];};
