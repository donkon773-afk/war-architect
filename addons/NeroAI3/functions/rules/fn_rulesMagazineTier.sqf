/* Installed config adapter. Mission overrides cover mod-specific ammo that
 * encodes penetration differently. Empty magazines are filtered by callers. */
params [["_magazine","",[""]]];
if (_magazine isEqualTo "") exitWith {0};
private _overrides = missionNamespace getVariable ["NeroAI_rulesAmmoTierOverrides",createHashMap];
private _override = _overrides getOrDefault [_magazine,-1];
if (_override >= 0) exitWith {(round _override) max 0 min 2};
private _cache = missionNamespace getVariable ["NeroWL_rulesAmmoCache",createHashMap];
private _cached = _cache getOrDefault [_magazine,-1];
if (_cached >= 0) exitWith {_cached};
private _ammo = getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
private _rows = [];
private _seen = [];
while {_ammo != "" && {!(_ammo in _seen)} && {count _rows < 4}} do {
    _seen pushBack _ammo;
    private _cfg = configFile >> "CfgAmmo" >> _ammo;
    _rows pushBack [getText (_cfg >> "simulation"),getNumber (_cfg >> "hit"),getNumber (_cfg >> "caliber"),getNumber (_cfg >> "airLock"),getText (_cfg >> "warheadName")];
    _ammo = if (isText (_cfg >> "submunitionAmmo")) then {getText (_cfg >> "submunitionAmmo")} else {""};
};
private _tier = 0;
reverse _rows;
{_tier = (_x + [_tier]) call NeroAI_fnc_rulesAmmoTier;} forEach _rows;
_cache set [_magazine,_tier];
missionNamespace setVariable ["NeroWL_rulesAmmoCache",_cache];
_tier
