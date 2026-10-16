/* NeroAI 4.5.0 [Vanilla Command]: the one place that answers "where are the
 * Warlords sectors and who holds them".
 *
 * LIVE INCIDENT (13.09): `bis_wl_allWarlords` — used as the sector list in
 * 4.3.0 — is the array of WARLORDS (the AI commanders / players of each
 * side), not of sectors. GREEN garrisons were dropped on top of BLUE's base
 * and on RED groups. Never again.
 *
 * 4.5.0: variable names verified against the vanilla Warlords sources
 * (functions_f_warlords: fn_WLInit / fn_WLSectorsSetup / fn_WLSectorsCommonInit):
 *   list   — BIS_WL_sectors (server-built, publicVariable'd; contains bases);
 *            fallback: entities "ModuleWLSector_F" + entities "ModuleWLBase_F";
 *   owner  — hub getVariable "BIS_WL_sectorSide" (a SIDE; RESISTANCE = the
 *            vanilla neutral garrison);
 *   name   — hub getVariable "Name" (resolved by Warlords from the nearest
 *            CfgLocation when the module has no name);
 *   base   — typeOf hub == "ModuleWLBase_F" (also BIS_WL_base_WEST/EAST).
 *
 * Returns [[obj, [x,y,0], name, ownerKey, isBase], ...] with ownerKey one of
 * "BLUE" / "RED" / "GREEN" / "NONE". Cached for a few seconds: this is called
 * from the snapshot builder several times per autonomy tick. */
private _cacheTtl = missionNamespace getVariable ["NeroAI_sectorCacheSeconds", 5];
private _cache = missionNamespace getVariable ["NeroAI_sectorCache", [-1e6, []]];
if ((diag_tickTime - (_cache # 0)) < _cacheTtl) exitWith { +(_cache # 1) };

private _raw = [];
private _source = "BIS_WL_sectors";
if (!isNil "BIS_WL_sectors") then {
    private _v = missionNamespace getVariable ["BIS_WL_sectors", []];
    if (_v isEqualType []) then { _raw = _v select {_x isEqualType objNull && {!isNull _x}}; };
};
if (_raw isEqualTo []) then {
    _source = "entities";
    _raw = (entities "ModuleWLSector_F") + (entities "ModuleWLBase_F");
};

private _baseWest = missionNamespace getVariable ["BIS_WL_base_WEST", objNull];
private _baseEast = missionNamespace getVariable ["BIS_WL_base_EAST", objNull];

private _fnc_ownerKey = {
    params ["_obj"];
    private _o = _obj getVariable ["BIS_WL_sectorSide", nil];
    if (isNil "_o") exitWith {"NONE"};
    if !(_o isEqualType west) exitWith {"NONE"};
    switch (_o) do {
        case west: {"BLUE"};
        case east: {"RED"};
        case resistance: {"GREEN"};
        default {"NONE"};
    }
};

private _out = [];
{
    private _p = getPosATL _x;
    if ((count _p) >= 2 && {!((_p select [0, 2]) isEqualTo [0, 0])}) then {
        private _name = _x getVariable ["Name", ""];
        if !(_name isEqualType "") then { _name = ""; };
        if (_name isEqualTo "") then { _name = _x getVariable ["BIS_WL_sectorName", ""]; };
        /* 4.7.0a: community missions store a stringtable key as the name. */
        if ((toUpper _name) select [0, 4] isEqualTo "STR_") then { _name = localize _name; };
        /* 4.7.0: community missions do not always name their sectors — use the
         * nearest named place, else a grid reference, never the object's p3d string. */
        if (_name isEqualTo "") then {
            private _near = nearestLocations [_p, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "Hill", "Airport"], 900];
            if !(_near isEqualTo []) then { _name = text (_near # 0); };
        };
        if (_name isEqualTo "") then { _name = format ["Сектор %1", mapGridPosition _p]; };
        private _isBase = (_x getVariable["NeroWL_isBase",false]) || {(typeOf _x) isEqualTo "ModuleWLBase_F"} || {_x isEqualTo _baseWest} || {_x isEqualTo _baseEast};
        _out pushBack [_x, [_p # 0, _p # 1, 0], _name, [_x] call _fnc_ownerKey, _isBase];
    };
} forEach _raw;

/* One-shot diagnostic so the RPT shows exactly what was found. */
if (!(missionNamespace getVariable ["NeroAI_sectorsProbed", false]) && {!(_out isEqualTo [])}) then {
    missionNamespace setVariable ["NeroAI_sectorsProbed", true];
    ["INFO", format ["Warlords sectors: %1 via %2: %3", count _out, _source,
        _out apply {format ["%1@%2,%3/%4%5", _x # 2, round ((_x # 1) # 0), round ((_x # 1) # 1), _x # 3, if (_x # 4) then {"/BASE"} else {""}]}
    ]] call NeroAI_fnc_log;
};

missionNamespace setVariable ["NeroAI_sectorCache", [diag_tickTime, +_out]];
_out
