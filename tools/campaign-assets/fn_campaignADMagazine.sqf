/* Owner-local ammo conversion preserves each remaining round, including reserve magazines. */
params ["_v","_linked"];
if (getText(configFile >> "CfgVehicles" >> typeOf _v >> "NeroAD_original")=="") exitWith {};

private _cfg=configFile >> "CfgNeroAirDefense" >> (_v getVariable ["NeroOP_adOriginal",typeOf _v]);
// Replace only the local turret's missile weapon. Native vehicle classes and turret inheritance remain intact.
{
 private _path=_x;
 if (_v turretLocal _path) then {
  private _stock=(magazinesAllTurrets [_v,true]) select {(_x#1) isEqualTo _path};
  { _x params ["_old","_new"];if (_old in (_v weaponsTurret _path)) then {_v removeWeaponTurret [_old,_path];_v addWeaponTurret [_new,_path];}; } forEach getArray(_cfg >> "weaponPairs");
  { _x params ["_old","_basic"];private _items=_stock select {(_x#0)==_old};
    {_v removeMagazineTurret [_old,_path];} forEach _items;
    {_v addMagazineTurret [_basic,_path,_x#2];} forEach _items;
  } forEach getArray(_cfg >> "originalMagazinePairs");
 };
} forEach getArray(_cfg >> "turretPaths");
private _pairs=getArray(_cfg >> "magazinePairs");
{_x params ["_basic","_remote"];private _from=if (_linked) then {_basic} else {_remote};private _to=if (_linked) then {_remote} else {_basic};
 private _stock=(magazinesAllTurrets [_v,true]) select {(_x#0)==_from && {_v turretLocal (_x#1)}};
 { _v removeMagazineTurret [_from,_x#1]; } forEach _stock;
 { _v addMagazineTurret [_to,_x#1,_x#2]; } forEach _stock;
} forEach _pairs;
_v setVariable ["NeroOP_adMagazineLinked",_linked];
