/* NeroAI 4.7.0 [Any Warlords]: one-shot scenario profile — everything NeroAI used
 * to assume about "the Takistan mission" is read from the running mission and the
 * terrain instead, so the same PBO commands vanilla Altis/Stratis/Malden/Tanoa
 * Warlords and community Warlords ports (Chernarus, Sahrani, Kunduz, Cam Lao Nam,
 * any RHS/CUP faction set) without a rebuild.
 *
 * Sources, all verified against functions_f_warlords (fn_WLVarsInit / fn_WLInit):
 *   factions  BIS_WL_factionsPool = [FactionOPFOR, FactionBLUFOR, FactionIndep]
 *   bases     BIS_WL_base_WEST / BIS_WL_base_EAST (the ModuleWLBase_F hubs)
 *   sides     Warlords is always WEST vs EAST with RESISTANCE holding sectors
 *   terrain   CfgWorlds >> worldName (description, size) + a sampled survey of
 *             the map (water, relief, tree and building density)
 *
 * Result: NeroAI_scenario (hashmap, broadcast) and the flat variables the rest of
 * the addon reads: NeroAI_factionNames, NeroAI_factionClasses, NeroAI_basePos_BLUE
 * / _RED, NeroAI_terrainProfile (unless the mission preset it), NeroAI_terrainLine.
 *
 *   [] call NeroAI_fnc_scenarioProfile  ->  hashmap (cached after the first call) */
if (!isServer) exitWith {createHashMap};
private _cached = missionNamespace getVariable ["NeroAI_scenario", nil];
private _fnc_resolveBases = {
    /* -> hashmap BLUE/RED -> [x,y,0]; sets NeroAI_basePos_* for whatever it finds */
    private _bases = createHashMap;
    private _hubs = entities "ModuleWLBase_F";
    {
        _x params ["_key", "_var", "_sideIndex", "_markers"];
        private _hub = missionNamespace getVariable [_var, objNull];
        if (isNull _hub && {_sideIndex<2}) then {
            /* module attribute Side: 1 = OPFOR (fn_WLSectorsSetup); anything else on a hub = BLUFOR */
            private _i = if (_sideIndex isEqualTo 1) then { _hubs findIf {(_x getVariable ["Side", -1]) isEqualTo 1} } else { _hubs findIf {!((_x getVariable ["Side", -1]) isEqualTo 1)} };
            if (_i >= 0) then { _hub = _hubs # _i; };
        };
        private _pos = [];
        if (!isNull _hub) then { private _p = getPosATL _hub; _pos = [_p # 0, _p # 1, 0]; };
        if (_pos isEqualTo []) then {
            { private _m = getMarkerPos _x; if (!(_m isEqualTo [0, 0, 0])) exitWith { _pos = [_m # 0, _m # 1, 0]; }; } forEach _markers;
        };
        if !(_pos isEqualTo []) then {
            _bases set [_key, _pos];
            missionNamespace setVariable [format ["NeroAI_basePos_%1", _key], _pos, true];
        };
    } forEach [
        ["BLUE", "BIS_WL_base_WEST", 0, ["respawn_west", "wl_base_west", "base_west"]],
        ["RED",  "BIS_WL_base_EAST", 1, ["respawn_east", "wl_base_east", "base_east"]],
        ["GREEN","BIS_WL_base_GUER",2,["respawn_guerrila"]]
    ];
    _bases
};
if (!isNil "_cached" && {_cached isEqualType createHashMap} && {_cached getOrDefault ["ready", false]}) exitWith {
    if ((count (_cached getOrDefault ["bases", createHashMap])) < 2) then {
        private _again = [] call _fnc_resolveBases;
        if ((count _again) > (count (_cached getOrDefault ["bases", createHashMap]))) then {
            _cached set ["bases", _again];
            missionNamespace setVariable ["NeroAI_scenario", _cached, true];
            ["INFO", format ["Scenario profile: bases resolved late — %1.", keys _again]] call NeroAI_fnc_log;
        };
    };
    _cached
};

private _profile = createHashMap;
private _cfgWorld = configFile >> "CfgWorlds" >> worldName;
private _worldDisplay = getText (_cfgWorld >> "description");
if (_worldDisplay isEqualTo "") then { _worldDisplay = worldName; };
_profile set ["world", worldName];
_profile set ["worldDisplay", _worldDisplay];
_profile set ["worldSize", worldSize];

/* --- factions ------------------------------------------------------------ */
private _pool = missionNamespace getVariable ["BIS_WL_factionsPool", []];
if !(_pool isEqualType []) then { _pool = []; };
private _fnc_factionName = {
    params ["_class"];
    if !(_class isEqualType "") exitWith {""};
    private _dn = getText (configFile >> "CfgFactionClasses" >> _class >> "displayName");
    if (_dn isEqualTo "") then { _dn = _class; };
    _dn
};
/* Order in the pool is OPFOR, BLUFOR, INDEP. A faction the module left empty is
 * inferred from whoever is standing on the map for that side. */
private _fnc_inferFaction = {
    params ["_side"];
    private _u = allUnits select {alive _x && {(side (group _x)) isEqualTo _side} && {!(_x isKindOf "UAV_AI_base_F")}};
    if (_u isEqualTo []) exitWith {""};
    private _counts = createHashMap;
    { private _f = faction _x; if !(_f isEqualTo "") then { _counts set [_f, (_counts getOrDefault [_f, 0]) + 1]; }; } forEach _u;
    private _best = ""; private _bestN = 0;
    { if (_y > _bestN) then { _best = _x; _bestN = _y; }; } forEach _counts;
    _best
};
private _classes = createHashMap;
private _names = createHashMap;
{
    _x params ["_key", "_index", "_side"];
    private _class = if ((count _pool) > _index && {(_pool # _index) isEqualType ""}) then {_pool # _index} else {""};
    if (_class isEqualTo "") then { _class = [_side] call _fnc_inferFaction; };
    _classes set [_key, _class];
    _names set [_key, [_class] call _fnc_factionName];
} forEach [["RED", 0, east], ["BLUE", 1, west], ["GREEN", 2, resistance]];
_profile set ["factionClasses", _classes];
_profile set ["factionNames", _names];
missionNamespace setVariable ["NeroAI_factionClasses", _classes, true];
missionNamespace setVariable ["NeroAI_factionNames", _names, true];

/* --- bases ----------------------------------------------------------------- */
private _bases = [] call _fnc_resolveBases;
_profile set ["bases", _bases];

/* --- terrain survey -------------------------------------------------------- */
/* 81 sample points on a jittered grid across the play area: how much is water,
 * how rough the relief is, how dense trees and buildings are. Cheap
 * (nearestTerrainObjects on a 50-60 m radius) and done once per mission.
 * Calibration 19.09 (Altis, RHS Warlords): whole-map survey said ISLANDS +
 * DENSE_FOREST (70 % sea in the square, bushes counted) — now sectors' envelope
 * and TREE only. */
private _size = worldSize max 1024;
/* Survey envelope = the sectors' bounding box + 2 km (the war happens there), the
 * whole map only when no sector is known yet. */
private _x0 = 0; private _y0 = 0; private _x1 = _size; private _y1 = _size;
private _sectorPts = ((entities "ModuleWLSector_F") + (entities "ModuleWLBase_F")) apply { getPosATL _x };
if ((count _sectorPts) >= 3) then {
    _x0 = _size; _y0 = _size; _x1 = 0; _y1 = 0;
    { _x0 = _x0 min (_x # 0); _y0 = _y0 min (_x # 1); _x1 = _x1 max (_x # 0); _y1 = _y1 max (_x # 1); } forEach _sectorPts;
    _x0 = (_x0 - 2000) max 1; _y0 = (_y0 - 2000) max 1; _x1 = (_x1 + 2000) min (_size - 1); _y1 = (_y1 + 2000) min (_size - 1);
};
private _n = 9;
private _water = 0; private _samples = 0;
private _heights = []; private _trees = 0; private _buildings = 0;
for "_ix" from 0 to (_n - 1) do {
    for "_iy" from 0 to (_n - 1) do {
        private _px = _x0 + ((_x1 - _x0) * (_ix + 0.5 + (random 0.6) - 0.3) / _n);
        private _py = _y0 + ((_y1 - _y0) * (_iy + 0.5 + (random 0.6) - 0.3) / _n);
        private _p = [_px max 1 min (_size - 1), _py max 1 min (_size - 1), 0];
        _samples = _samples + 1;
        if (surfaceIsWater _p) then { _water = _water + 1; } else {
            _heights pushBack (getTerrainHeightASL _p);
            /* real trees only — Mediterranean scrub counted as forest on Altis */
            _trees = _trees + (count (nearestTerrainObjects [_p, ["TREE"], 50, false]));
            _buildings = _buildings + (count (nearestTerrainObjects [_p, ["HOUSE", "BUILDING", "CHURCH"], 60, false]));
        };
    };
};
private _land = (count _heights) max 1;
private _waterFrac = _water / (_samples max 1);
private _mean = 0; { _mean = _mean + _x; } forEach _heights; _mean = _mean / _land;
private _var = 0; { _var = _var + ((_x - _mean) ^ 2); } forEach _heights;
private _relief = sqrt (_var / _land);           /* std-dev of elevation, m */
private _hMax = if (_heights isEqualTo []) then {0} else { selectMax _heights };
private _treeDensity = _trees / _land;           /* trees per 60 m disc */
private _buildDensity = _buildings / _land;

private _tags = [];
if (_waterFrac >= 0.45) then { _tags pushBack "ISLANDS" } else { if (_waterFrac >= 0.15) then { _tags pushBack "COAST" } };
if (_relief >= 90 || {_hMax >= 900}) then { _tags pushBack "MOUNTAINS" } else {
    if (_relief >= 35) then { _tags pushBack "HILLS" } else { _tags pushBack "FLAT" };
};
if (_treeDensity >= 25) then { _tags pushBack "DENSE_FOREST" } else {
    if (_treeDensity >= 8) then { _tags pushBack "FOREST" } else {
        if (_treeDensity >= 2) then { _tags pushBack "SPARSE_TREES" } else { _tags pushBack "OPEN" };
    };
};
if (_buildDensity >= 4) then { _tags pushBack "URBAN" } else { if (_buildDensity >= 0.6) then { _tags pushBack "VILLAGES" } };
/* Arid steppe / desert: open relief with almost no trees. Wet jungle: dense trees
 * with little relief variance is not distinguished further — the tags carry it. */
if ((_tags findIf {_x in ["OPEN", "SPARSE_TREES"]}) >= 0 && {(_tags findIf {_x isEqualTo "ISLANDS"}) < 0}) then { _tags pushBack "ARID" };

/* Preset by the mission (missions/NeroAI_Warlords.Altis sets it in init.sqf) wins;
 * otherwise a coarse profile keyed off the survey for legacy consumers. */
private _preset = missionNamespace getVariable ["NeroAI_terrainProfile", ""];
private _coarse = if ("MOUNTAINS" in _tags && {"ARID" in _tags}) then {"TAKISTAN"} else {
    if ("DENSE_FOREST" in _tags || {"FOREST" in _tags}) then {"FOREST"} else {"ALTIS"}
};
if (!(_preset isEqualType "") || {_preset isEqualTo ""} || {_preset isEqualTo "AUTO"}) then {
    missionNamespace setVariable ["NeroAI_terrainProfile", _coarse, true];
} else { _coarse = _preset; };
/* No "|" here or anywhere in the snapshot: INIDBI2 cuts the value at a pipe. */
private _line = format ["%1: %2", _worldDisplay, (_tags apply {toLower _x}) joinString ", "];
missionNamespace setVariable ["NeroAI_terrainLine", _line, true];
_profile set ["terrainTags", _tags];
_profile set ["terrainLine", _line];
_profile set ["terrainProfile", _coarse];
_profile set ["survey", [round (_waterFrac * 100), round _relief, round _hMax, round (_treeDensity * 10) / 10, round (_buildDensity * 10) / 10]];

_profile set ["ready", true];
missionNamespace setVariable ["NeroAI_scenario", _profile, true];
["INFO", format ["Scenario profile: %1 (%2, %3 m); factions BLUE=%4 RED=%5 GREEN=%6; bases %7; terrain [%8] water %9 pct relief %10 m hmax %11 m trees %12 bld %13; envelope %14.",
    _worldDisplay, worldName, worldSize, _names get "BLUE", _names get "RED", _names get "GREEN", keys _bases, _tags joinString ",",
    round (_waterFrac * 100), round _relief, round _hMax, round (_treeDensity * 10) / 10, round (_buildDensity * 10) / 10, [round _x0, round _y0, round _x1, round _y1]]] call NeroAI_fnc_log;
_profile
