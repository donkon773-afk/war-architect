/* Uses native factory queues/funds. One outstanding batch per combat group. */
params ["_group","_side","_pool","_factory"];
if (!isServer || {isRemoteExecuted} || {!local _group} || {isNull _factory} || {!alive _factory} || {[_group] call NeroOP_fnc_campaignPlayerControl}) exitWith {false};
private _structures=_side call CTI_CO_FNC_GetSideStructures;
_structures=+_structures;
_structures pushBackUnique _factory;
if (_structures findIf {(_x getVariable ["cti_queue_processing",[]]) findIf {count _x>4 && {(_x#4) isEqualTo _group}}>=0}>=0) exitWith {false};
private _role=_group getVariable ["cti_role","Infantry"];
private _owned=(units _group apply {vehicle _x}) select {!(_x isKindOf "Man") && {alive _x} && {driver _x in units _group}};
_owned=_owned arrayIntersect _owned;
private _held=_group getVariable ["WA_BECTI_vehicle",objNull];if (!isNull _held && {alive _held}) then {_owned pushBackUnique _held;};
private _needVehicle=!(_role in ["Infantry","InfantryAT","InfantryAA"]) && {count _owned==0};
private _desired=getNumber(missionConfigFile >> "CfgWarArchitectDoctrine" >> str _side >> "groupSize");
if (_desired<1) then {_desired=CTI_AI_TEAMS_GROUPSIZE;};
private _candidates=[];private _needed=(_desired-({alive _x} count units _group)) max 0;
if (_needVehicle) then {
 if (leader _group distance2D _factory>250) exitWith {_group setVariable ["WA_BECTI_assemblyPosition",getPosATL _factory];false};
 _candidates=_pool select {private _c=configFile >> "CfgVehicles" >> (_x#0);isClass _c && {!((_x#0) isKindOf "Man")} && {getNumber(_c >> "maxSpeed")>10} && {getNumber(_c >> "hasDriver")==1} && {count (missionNamespace getVariable [_x#0,[]])>7}};
 _needed=1;
} else {
 if (_role in ["AntiAir","Armored","AirIntercept","AirCAS","AirHeli","AirBomber","AirAttack"] && {count _owned>0}) exitWith {true};
 if (count _owned>0 && {count fullCrew [_owned#0,"cargo",true]<3}) exitWith {true};
 if (count _owned>0) then {
  private _availableCargo={isNull (_x#0)} count fullCrew [_owned#0,"cargo",true];
  private _waiting={alive _x && {vehicle _x==_x}} count units _group;
  _needed=_needed min ((_availableCargo-_waiting) max 0);
  _factory=[CTI_BARRACKS,leader _group,_structures] call CTI_CO_FNC_GetClosestStructure;
  if (!alive _factory) exitWith {};
 };
 private _template=missionNamespace getVariable [format ["CTI_SQUAD_%1_Infantry",_side],[]];
 _candidates=if (count _template>2) then {(_template#2) select {isClass(configFile >> "CfgVehicles" >> (_x#0)) && {count (missionNamespace getVariable [_x#0,[]])>7}}} else {[]};
};
if (_needed<=0 || {count _candidates==0} || {!alive _factory}) exitWith {false};
private _funds=[_group,_side] call CTI_CO_FNC_GetFunds;
private _affordable=_candidates select {(missionNamespace getVariable (_x#0))#2<=_funds};
if (count _affordable==0) exitWith {false};
for "_i" from 1 to _needed do {
 private _class=(selectRandom _affordable)#0;private _cost=(missionNamespace getVariable _class)#2;
 if (_funds<_cost) exitWith {};
 _funds=_funds-_cost;
 [_group,_group,_side,_class,_factory,[true,true,true,true,true],time+random 100000+diag_frameno+_i] call CTI_SE_FNC_OnClientPurchase;
};
diag_log format ["[WA BECTI REQUISITION] group=%1 role=%2 vehicle=%3 requested=%4 factory=%5",_group,_role,_needVehicle,_needed,_factory];
true
