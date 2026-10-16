/* Eden flight assistance: observed targets only; preserve mission waypoints and pilot orders. */
if (missionNamespace getVariable ["NeroSandbox_airCombatStarted",false]) exitWith {};
NeroSandbox_airCombatStarted=true;
while {!(missionNamespace getVariable ["NeroOP_campFinished",false])} do {
 {
  private _v=_x;private _pilot=driver _v;
  if (_v isKindOf "Air" && {local _v} && {alive _pilot} && {!isTouchingGround _v} && {!([_v] call NeroOP_fnc_campaignPlayerControl)}) then {
   private _side=side group _pilot;private _contacts=[];private _airWeapon=false;private _groundWeapon=false;
   {if ((_x#2)>0) then {private _mag=_x#0;private _a=configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _mag >> "ammo");private _locks=getNumber(_a >> "weaponLockSystem");if (isText(_a >> "weaponLockSystem")) then {_locks=0;{_locks=_locks+parseNumber _x;} forEach (getText(_a >> "weaponLockSystem") splitString "+ ");};private _arm=isClass(_a >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower _mag find "harm">=0} || {toLower _mag find "kh31p">=0};if (getText(_a >> "simulation")=="shotMissile" && {toLower _mag find "kh55"<0}) then {if ([true,getNumber(_a >> "airLock"),getNumber(_a >> "manualControl")>0,getNumber(_a >> "laserLock")>0,_locks,_arm,true] call NeroOP_fnc_campaignMissileCompatible) then {_airWeapon=true;};if ([false,getNumber(_a >> "airLock"),getNumber(_a >> "manualControl")>0,getNumber(_a >> "laserLock")>0,_locks,_arm,true] call NeroOP_fnc_campaignMissileCompatible) then {_groundWeapon=true;};};};} forEach magazinesAllTurrets [_v,true];
   {private _t=_x#0;if (alive _t && {(_x#2)!="friendly"} && {_side getFriend (side group effectiveCommander _t)<.6}) then {_contacts pushBackUnique _t;};} forEach getSensorTargets _v;
   {_contacts pushBackUnique _x;} forEach (_pilot targets [true,20000,[],10]);
   private _rank=[];private _old=_v getVariable ["NeroOP_missileAim",objNull];
   {private _unit=if (_x isKindOf "Man") then {_x} else {effectiveCommander _x};private _air=_x isKindOf "Air";if (alive _x && {_side getFriend (side group _unit)<.6} && {if (_air) then {_airWeapon} else {_groundWeapon}}) then {_rank pushBack [if (_x==_old) then {-1} else {if (_air) then {0} else {1}},_v distance _x,_forEachIndex];};} forEach _contacts;_rank sort true;
   if (count _rank>0) then {private _target=_contacts#((_rank#0)#2);[_v,_target,20000] call NeroOP_fnc_campaignMissileEngage;};
  };
 } forEach vehicles;
 sleep 1;
};
