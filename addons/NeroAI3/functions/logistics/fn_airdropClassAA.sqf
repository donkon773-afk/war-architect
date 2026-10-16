/* Infer potential AA from an observed class, not its hidden live inventory. */
params ["_class"];
private _cache = missionNamespace getVariable ["NeroWL_aaClassCache",createHashMap];
if (_class in _cache) exitWith {_cache get _class};
private _cfg = configFile >> "CfgVehicles" >> _class;
private _magazines = +(getArray (_cfg >> "magazines"));
private _turrets = ["true" configClasses (_cfg >> "Turrets")];
{_magazines append (getArray (configFile >> "CfgWeapons" >> _x >> "magazines"));} forEach getArray (_cfg >> "weapons");
{_magazines append (getArray (_x >> "magazines"));{_magazines append (getArray (_x >> "magazines"));} forEach ("true" configClasses (_x >> "Turrets"));} forEach (_turrets # 0);
private _aa = (_magazines findIf {private _ammo = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _x >> "ammo");getNumber (_ammo >> "airLock") > 0 && {toLower getText (_ammo >> "simulation") isEqualTo "shotmissile"}}) >= 0;
_cache set [_class,_aa];missionNamespace setVariable ["NeroWL_aaClassCache",_cache];
_aa
