/* One-time AI mission loadout. Preserve player aircraft and spent ammunition. */
params ["_v",["_equip",true]];
if (!local _v || {[_v] call NeroOP_fnc_campaignPlayerControl}) exitWith {};
private _role=_v getVariable ["NeroOP_airRole","CAS"];
if (_equip) then {if (_role=="BOMBER") then {
 {private _index=_x#0;private _mags=_v getCompatiblePylonMagazines _index;private _he=_mags select {toLower getText(configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _x >> "ammo") >> "RHS_WarheadType")!="nuke" && {toLower _x find "kh55sh">=0}};
  if (count _he>0) then {_v setPylonLoadOut [_index,_he#0,true,_x#2];};
 } forEach getAllPylonsInfo _v;
} else {
 if (_role in ["CAS","ATTACK_HELI","FIGHTER"]) then {
  {private _index=_x#0;private _mags=_v getCompatiblePylonMagazines _index;private _arm=_mags select {private _c=configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _x >> "ammo");isClass(_c >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower _x find "harm">=0} || {toLower _x find "kh31p">=0}};if (_index mod 3==0 && {count _arm>0}) then {_v setPylonLoadOut [_index,_arm#0,true,_x#2];};private _ag=_mags select {private _c=configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _x >> "ammo");getText(_c >> "simulation") in ["shotMissile","shotRocket","shotShell"] && {getNumber(_c >> "airLock")==0} && {getNumber(_c >> "hit")>20} && {toLower _x find "flare"<0}};
   if (count _ag>0 && {(_index mod 3)!=0 || {_v isKindOf "Helicopter"}}) then {_v setPylonLoadOut [_index,_ag#0,true,_x#2];};
  } forEach getAllPylonsInfo _v;
 };
};
};
_v addEventHandler ["Fired",{params ["_v","_weapon","_muzzle","_mode","_ammo","_mag","_projectile"];
 if (local _v && {!([_v] call NeroOP_fnc_campaignPlayerControl)}) then {
  if (_v getVariable ["NeroOP_airRole",""]=="BOMBER" && {toLower _mag find "kh55sh">=0}) then {
   private _pos=_v getVariable ["NeroOP_strikePos",[]];if (count _pos>=2 && {getNumber(configFile >> "CfgAmmo" >> _ammo >> "manualControl")==1}) then {_projectile setMissileTargetPos _pos;};
   if (count _pos==2) then {_projectile setMissileTargetPos [_pos#0,_pos#1,0];};
   [_projectile,_v,_v getVariable ["NeroOP_side",1]] spawn NeroOP_fnc_campaignCruiseTrack;
   _v setVariable ["NeroOP_strikeAt",serverTime];diag_log format ["[NeroOP AIR] CRUISE FIRED class=%1 magazine=%2 reported=%3",typeOf _v,_mag,_pos];
  } else {if (serverTime-(_v getVariable ["NeroOP_fireLogAt",-20])>10) then {_v setVariable ["NeroOP_fireLogAt",serverTime];diag_log format ["[NeroOP AIR] FIRED class=%1 weapon=%2 role=%3",typeOf _v,_weapon,_v getVariable ["NeroOP_airRole",""]];};};
 };
}];
