/* Owner-local, real-magazine launch assistance. Contacts are supplied by sensors/intel. */
params ["_v","_target",["_limit",20000]];
if (!local _v || {!alive _v} || {!alive _target} || {[_v] call NeroOP_fnc_campaignPlayerControl} || {!canFire _v}) exitWith {false};
private _side=side group effectiveCommander _v;
private _patriot=getNumber(configFile >> "CfgNeroAirDefense" >> "patriotBMD")==1 && {toLower (_v getVariable ["NeroOP_adOriginal",typeOf _v]) in ["b_sam_system_03_f","i_e_sam_system_03_f"]} && {_target getVariable ["NeroMS_ballistic",false]};
private _salvo=_v getVariable ["NeroOP_bmdSalvo",[objNull,0]];if (_patriot && {(_salvo#0)==_target} && {(_salvo#1)>=2}) exitWith {false};
private _targetUnit=if (_target isKindOf "Man") then {_target} else {effectiveCommander _target};
if (!([[west,east] find _side,_target] call NeroOP_fnc_campaignIFF)) exitWith {false};
if (getNumber(configFile >> "CfgVehicles" >> typeOf _v >> "isUav")==1 && {!isAutonomous _v}) exitWith {false};
if !(_v getVariable ["NeroOP_missileEH",false]) then {
 _v setVariable ["NeroOP_missileEH",true];
 _v addEventHandler ["Fired",{
  params ["_v","_weapon","_muzzle","_mode","_ammo","_mag","_p"];
  if (!local _p || {getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")!="shotMissile"}) exitWith {};
  private _request=_v getVariable ["NeroOP_missileRequest",[objNull,"",-10]];
  private _target=_request#0;private _bound=false;
  if (alive _target && {_weapon==(_request#1)} && {serverTime-(_request#2)<=6} && {[[west,east] find side group effectiveCommander _v,_target] call NeroOP_fnc_campaignIFF}) then {
   _bound=_p setMissileTarget _target;
  };
  _v setVariable ["NeroOP_missileLastShot",serverTime];
  private _actual=missileTarget _p;if (!isNull _actual) then {_target=_actual;};
  if (!isNull _target && {_target getVariable ["NeroMS_ballistic",false]} && {getNumber(configFile >> "CfgAmmo" >> _ammo >> "NeroAD_bmd")==1}) then {private _s=_v getVariable ["NeroOP_bmdSalvo",[objNull,0]];_v setVariable ["NeroOP_bmdSalvo",[_target,if ((_s#0)==_target) then {(_s#1)+1} else {1}]];};
  diag_log format ["[NeroOP MISSILE] FIRED vehicle=%1 weapon=%2 ammo=%3 requested=%4 actual=%5 bound=%6",typeOf _v,_weapon,_ammo,typeOf _target,typeOf missileTarget _p,_bound];
 }];
};
if ((_v getVariable ["NeroOP_missileAim",objNull])!=_target) then {_v setVariable ["NeroOP_missileAim",_target];_v setVariable ["NeroOP_missileAimAt",if (_v getVariable ["NeroOP_radarSupported",false]) then {serverTime-2} else {serverTime}];};
private _air=_target isKindOf "Air";private _range=_v distance _target;private _choices=[];
{
 _x params ["_mag","_path","_rounds"];
 if (_rounds>0 && {_v turretLocal _path}) then {
  private _a=configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _mag >> "ammo");
  private _airLock=getNumber(_a >> "airLock");private _manual=getNumber(_a >> "manualControl")>0;private _laser=getNumber(_a >> "laserLock")>0;
  private _arm=isClass(_a >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower _mag find "harm">=0} || {toLower _mag find "kh31p">=0};
  private _locks=getNumber(_a >> "weaponLockSystem");if (isText(_a >> "weaponLockSystem")) then {_locks=0;{_locks=_locks+parseNumber _x;} forEach (getText(_a >> "weaponLockSystem") splitString "+ ");};
  if (getText(_a >> "simulation")=="shotMissile" && {toLower _mag find "kh55"<0} && {[_air,_airLock,_manual,_laser,_locks,_arm,isVehicleRadarOn _target] call NeroOP_fnc_campaignMissileCompatible}) then {
   private _maximum=(getNumber(_a >> "missileLockMaxDistance")) min _limit;
   private _minimum=(getNumber(_a >> "missileLockMinDistance")) max (if (_v isKindOf "Air") then {600} else {100});
   private _op=if (_path isEqualTo [-1]) then {driver _v} else {_v turretUnit _path};
   if (alive _op && {local _op} && {!isPlayer _op} && {_range>=_minimum} && {_range<=_maximum}) then {
    {private _weapon=_x;private _cfg=configFile >> "CfgWeapons" >> _weapon;
     if (_mag in getArray(_cfg >> "magazines")) then {private _loaded=weaponState [_v,_path,_weapon];if (count _loaded>=7 && {(_loaded#3)==_mag} && {(_loaded#4)>0}) then {_choices pushBack [-_maximum,_weapon,_path,_op,_a,_minimum,_maximum];};};
    } forEach (_v weaponsTurret _path);
   };
  };
 };
} forEach magazinesAllTurrets [_v,true];
if (count _choices==0) exitWith {
 if (serverTime-(_v getVariable ["NeroOP_missileNoWeaponAt",-100])>15) then {_v setVariable ["NeroOP_missileNoWeaponAt",serverTime];diag_log format ["[NeroOP MISSILE] NO_COMPATIBLE vehicle=%1 target=%2 range=%3 loaded=%4",typeOf _v,typeOf _target,round _range,magazinesAllTurrets [_v,true]];};false
};
// Sort only scalar indices: configs and objects are never compared.
private _rank=[];{_rank pushBack [_x#0,_forEachIndex];} forEach _choices;_rank sort true;
(_choices#((_rank#0)#1)) params ["_score","_weapon","_path","_op","_a","_minimum","_maximum"];
_op reveal [_target,4];_op doTarget _target;
private _selected=weaponState [_v,_path];
if (count _selected==0 || {(_selected#0)!=_weapon}) then {_v selectWeaponTurret [_weapon,_path];};
private _state=weaponState [_v,_path,_weapon];
if (count _state<7) exitWith {false};
private _direction=if (_v isKindOf "Air" && {_path isEqualTo [-1]}) then {vectorDir _v} else {_v weaponDirection _weapon};
private _toward=vectorNormalized ((getPosASL _target) vectorDiff (getPosASL _v));
private _angle=acos (((vectorNormalized _direction) vectorDotProduct _toward) max -1 min 1);
private _cone=getNumber(_a >> "missileLockCone");if (_cone<=0) then {_cone=30;};_cone=_cone min (if (_v isKindOf "Air") then {45} else {170});
private _visible=[_v,"VIEW",_target] checkVisibility [getPosASL _v vectorAdd [0,0,2],getPosASL _target]>.1;
private _cooldown=serverTime-((_v getVariable ["NeroOP_missileLastShot",-100]) max (_v getVariable ["NeroOP_missileAttemptAt",-100]));
if !([_range,_minimum,_maximum,_angle,_cone,vectorMagnitude velocity _target,getNumber(_a >> "missileLockMaxSpeed"),serverTime-(_v getVariable ["NeroOP_missileAimAt",serverTime])+(if (_patriot) then {1.5} else {0}),_cooldown+(if (_patriot) then {3} else {0}),_state#4,(_state#5) max (_state#6),_visible] call NeroOP_fnc_campaignMissileGate) exitWith {false};
_v setVariable ["NeroOP_missileRequest",[_target,_weapon,serverTime]];
_v setVariable ["NeroOP_missileAttemptAt",serverTime];
private _accepted=_v fireAtTarget [_target,_state#1];
diag_log format ["[NeroOP MISSILE] REQUEST vehicle=%1 target=%2 range=%3 weapon=%4 accepted=%5",typeOf _v,typeOf _target,round _range,_weapon,_accepted];
_accepted
