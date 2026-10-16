if(getNumber(missionConfigFile >> "NeroWL_useDesigner")==1)exitWith{};
/* NeroAI 4.4.0 [Command]: one-shot base asset package for BLUE and RED.
 *
 * Each side gets, at its own base: 2 armed recon UAVs, 3 mortars, one CAS jet,
 * one fighter, one attack helicopter, and ammo / fuel / repair trucks.
 *
 * Everything is spawned PARKED and COLD: aircraft keep their engines off and
 * their pilots' MOVE AI disabled until fn_dispatchAir releases them for a
 * bounded sortie. That is deliberate — a crewed AI jet left to its own devices
 * flies straight into enemy air defence over the enemy base, which is exactly
 * what the doctrine forbids. Mortars are crewed so doArtilleryFire works.
 *
 * Runs once per mission (NeroAI_baseAssetsSpawned latch), server only. */
if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_baseAssetsEnabled", true])) exitWith {};
if (missionNamespace getVariable ["NeroAI_baseAssetsSpawned", false]) exitWith {};

private _fnc_basePos = {
    params ["_side", "_sideKey", "_markers"];
    private _pos = [];
    private _foundMarker = "";
    /* 4.7.0: the Warlords base hub itself (BIS_WL_base_WEST/EAST, any mission
     * built on the module) comes first; marker names are a convention only. */
    private _hub = missionNamespace getVariable [if (_side isEqualTo west) then {"BIS_WL_base_WEST"} else {"BIS_WL_base_EAST"}, objNull];
    if (isNull _hub) then {
        private _hubs = entities "ModuleWLBase_F";
        private _i = if (_side isEqualTo west) then { _hubs findIf {!((_x getVariable ["Side", -1]) isEqualTo 1)} } else { _hubs findIf {(_x getVariable ["Side", -1]) isEqualTo 1} };
        if (_i >= 0) then { _hub = _hubs # _i; };
    };
    if (!isNull _hub) then { private _hp = getPosATL _hub; _pos = [_hp # 0, _hp # 1, 0]; _foundMarker = "BIS_WL_base hub"; };
    if (_pos isEqualTo []) then {
        {
            private _m = getMarkerPos _x;
            if (!(_m isEqualTo [0, 0, 0])) exitWith { _pos = _m; _foundMarker = _x; };
        } forEach _markers;
    };
    if (_pos isEqualTo []) then {
        /* None of the guessed marker names exist on this map/mission — same
         * failure class as the Warlords sector variable this session already
         * hit twice. Log every marker we tried so the real one can be read
         * off next session's RPT instead of guessed a third time. */
        ["WARN", format ["%1: none of the base markers %2 exist on this map; falling back to a unit-cluster estimate.", _sideKey, _markers]] call NeroAI_fnc_log;

        /* A raw average of every living unit of that side can land nowhere
         * real if the front line is split across the map (the mean of two
         * clusters is the empty space between them, possibly next to the
         * OTHER side). Anchor on the largest local cluster instead: for each
         * candidate, count same-side neighbours within 400 m, keep the one
         * with the most, and average just that cluster. */
        private _units = (allUnits select {alive _x && {(side _x) isEqualTo _side}});
        if !(_units isEqualTo []) then {
            private _bestUnit = _units # 0;
            private _bestCount = -1;
            {
                private _p = getPosATL _x;
                private _n = {(_x distance2D _p) <= 400} count _units;
                if (_n > _bestCount) then { _bestCount = _n; _bestUnit = _x; };
            } forEach _units;
            private _cluster = _units select {(_x distance2D _bestUnit) <= 400};
            private _sx = 0; private _sy = 0;
            { private _p = getPosATL _x; _sx = _sx + (_p # 0); _sy = _sy + (_p # 1); } forEach _cluster;
            _pos = [_sx / (count _cluster), _sy / (count _cluster), 0];
        };
    } else {
        ["INFO", format ["%1: base position resolved from marker '%2'.", _sideKey, _foundMarker]] call NeroAI_fnc_log;
    };
    _pos
};

private _fnc_freeSpot = {
    params ["_centre", "_ring", "_index", "_total"];
    private _angle = 360 * _index / (_total max 1);
    private _p = _centre getPos [_ring, _angle];
    private _flat = [_p, 0, 45, 6, 0, 0.35, 0] call BIS_fnc_findSafePos;
    if (_flat isEqualType [] && {(count _flat) >= 2} && {!((_flat # 0) isEqualTo 0)}) then {_flat} else {_p}
};

/* Fixed-wing needs tarmac: a jet parked in a field taxis into a ditch instead of
 * taking off. Anything flagged runway=true is placed on the nearest airport to
 * the base when the terrain has one, and only falls back to the base ring
 * (logged) when it does not.
 *
 * BUG (live session): the map's one CfgWorlds ilsPosition was accepted with NO
 * distance cap, so when neither side's base was actually near it, BOTH sides'
 * runway-needing assets (UAV_ARMED x2, JET_CAS, JET_FIGHTER — 4 aircraft per
 * side, 8 total) piled into the same ~60 m ring around one shared point far
 * from either base: RED's jets/UAVs turned up "at BLUE's base" and vice versa,
 * and eight aircraft fighting BIS_fnc_findSafePos for the same cramped ring
 * looked like planes taking off and circling on their own. A candidate beyond
 * a sane radius of THIS side's own base is not this side's airfield. */
private _fnc_runwayPos = {
    params ["_base"];
    private _maxUsableDist = missionNamespace getVariable ["NeroAI_airfieldMaxDistanceMeters", 6000];
    private _best = [];
    private _bestD = _maxUsableDist;

    /* This Warlords build publishes its own real airstrip list
     * (bis_wl_airstrips, found via the fn_scenarioTuning diagnostic) — a far
     * more reliable source than guessed config/location data. Element shape
     * is unconfirmed by a live run, so accept object / location / raw
     * position and skip anything else rather than erroring. */
    if (!isNil "bis_wl_airstrips") then {
        {
            /* Verified in fn_WLVarsInit.sqf: an airstrip entry is
             * [runwayPos, planeSpawnPos, direction] — take the runway position,
             * not the whole entry (live 14.09 22:20: "Тип Массив, ожидался Число"). */
            private _p = switch true do {
                case (_x isEqualType objNull): { getPos _x };
                case (_x isEqualType locationNull): { locationPosition _x };
                case (_x isEqualType [] && {(count _x) > 0} && {(_x # 0) isEqualType []}): { _x # 0 };
                case (_x isEqualType []): { _x };
                default { [] };
            };
            if ((_p isEqualType []) && {(count _p) >= 2} && {!(_p isEqualTo [0, 0, 0])}) then {
                private _d = _base distance2D _p;
                if (_d < _bestD) then { _bestD = _d; _best = [_p # 0, _p # 1, 0]; };
            };
        } forEach bis_wl_airstrips;
    };

    /* Fallback: every terrain that has a main runway publishes its ILS
     * position (config data, works without a mission function name) — but
     * only when it is actually close to this side's own base. */
    if (_best isEqualTo []) then {
        private _ils = getArray (configFile >> "CfgWorlds" >> worldName >> "ilsPosition");
        if ((count _ils) >= 2 && {!(_ils isEqualTo [0, 0, 0])}) then {
            private _d = _base distance2D [_ils # 0, _ils # 1, 0];
            if (_d <= _bestD) then { _bestD = _d; _best = [_ils # 0, _ils # 1, 0]; };
        };

        /* Secondary airfields are mapped as Airport locations. */
        {
            private _p = locationPosition _x;
            if ((count _p) >= 2 && {!(_p isEqualTo [0, 0, 0])}) then {
                private _d = _base distance2D _p;
                if (_d < _bestD) then { _bestD = _d; _best = [_p # 0, _p # 1, 0]; };
            };
        } forEach (nearestLocations [_base, ["Airport", "NameLocal"], _maxUsableDist] select {
            (toLower (text _x)) find "airport" >= 0 || {(toLower (type _x)) isEqualTo "airport"}
        });
    };

    _best
};

/* 4.5.0 [Vanilla Command]: the base package is ONE armed drone per side —
 * everything else (armour, aircraft, mortars, trucks) is vanilla Warlords
 * requisition the groups buy with their own CP (fn_purchaseAsset).
 * Row: role, count, ring radius, needs a runway, needs a crew. */
private _package = [
    ["UAV_ARMED",    1, 120, true,  true]
];

private _registry = createHashMap;

{
    _x params ["_sideKey", "_side", "_markers"];
    private _base = [_side, _sideKey, _markers] call _fnc_basePos;
    if (_base isEqualTo []) then {
        ["WARN", format ["Base assets for %1 skipped: no base position could be resolved.", _sideKey]] call NeroAI_fnc_log;
    } else {
        private _spawned = [];
        private _slot = 0;
        private _runway = [_base] call _fnc_runwayPos;
        if (_runway isEqualTo []) then {
            ["WARN", format ["%1: аэродром на карте не найден — самолёты и БПЛА ставятся на базе и могут не взлететь.", _sideKey]] call NeroAI_fnc_log;
        };
        {
            _x params ["_role", "_count", "_ring", "_needsRunway", "_needsCrew"];
            /* 4.7.0: the side's own faction drone first (an armed fixed-wing UAV of the
             * mission's BLUFOR/OPFOR faction), the Takistan-war catalogue as fallback. */
            private _class = "";
            if (_role isEqualTo "UAV_ARMED") then {
                private _own = ([_sideKey, "UAV_ARMED"] call NeroAI_fnc_factionAssets) select {_x isKindOf "Air"};
                private _fixedWing = _own select {!(_x isKindOf "Helicopter")};
                if !(_fixedWing isEqualTo []) then { _own = _fixedWing; };
                if !(_own isEqualTo []) then { _class = _own # 0; };
            };
            if (_class isEqualTo "") then { _class = [_role, _sideKey] call NeroAI_fnc_assetCatalog; };
            if !(_class isEqualTo "") then {
                for "_i" from 1 to _count do {
                    _slot = _slot + 1;
                    private _origin = if (_needsRunway && {!(_runway isEqualTo [])}) then {_runway} else {_base};
                    private _ringUse = if (_needsRunway && {!(_runway isEqualTo [])}) then {110} else {_ring};
                    private _spot = [_origin, _ringUse, _slot, 16] call _fnc_freeSpot;
                    private _veh = createVehicle [_class, _spot, [], 25, "NONE"];
                    if (!isNull _veh) then {
                        _veh setVariable ["NeroAI_ownerSide", _side, true];
                        _veh setVariable ["NeroAI_assetRole", _role, true];
                        /* RTB goes back to wherever it launched from — the
                         * airfield for fixed-wing, the base ring otherwise. */
                        _veh setVariable ["NeroAI_homeBase", _origin, true];
                        if (_needsCrew) then {
                            createVehicleCrew _veh;
                            private _isAir = _veh isKindOf "Air";
                            /* This crew exists only so a scripted order
                             * (doArtilleryFire, the dispatchAir sortie) can
                             * execute — never to act on its own. Without this,
                             * both the generic enemy-AI manager and normal
                             * tactical autonomy will happily hand a "group" of
                             * one mortar gunner or UAV pilot an ASSAULT/RECON
                             * order like any rifle squad, and it walks off the
                             * gun (or flies off cold) to its death within a
                             * minute of spawning — confirmed live: RED's own
                             * base UAV crew got exactly this and was dead in
                             * under 30s. TARGET/AUTOTARGET off means the AI can
                             * never self-initiate a fire mission either. */
                            {
                                _x setVariable ["NeroAI_isBaseAssetCrew", true, true];
                                _x disableAI "TARGET";
                                _x disableAI "AUTOTARGET";
                            } forEach (crew _veh);
                            (group (effectiveCommander _veh)) setVariable ["NeroAI_isBaseAssetCrew", true, true];
                            if (_isAir) then {
                                /* LIVE INCIDENT (12-13.09): parked jets and UAVs took off
                                 * on their own and orbited across the map. disableAI
                                 * "MOVE" + engineOn false is not enough for aircraft —
                                 * the pilot FSM, a UAV terminal connection, or vanilla
                                 * Warlords can all restart the engine. An airframe with
                                 * NO FUEL cannot leave the ground no matter who orders
                                 * it; fn_dispatchAir refuels on launch and drains on
                                 * park again. */
                                _veh engineOn false;
                                _veh setFuel 0;
                                _veh setVariable ["NeroAI_airState", "PARKED", true];
                                { _x disableAI "MOVE"; _x disableAI "PATH"; _x setBehaviour "CARELESS"; } forEach (crew _veh);
                            } else {
                                /* Mortars hold position and never wander. */
                                private _g = group (effectiveCommander _veh);
                                if (!isNull _g) then { _g setBehaviour "SAFE"; _g setCombatMode "GREEN"; };
                            };
                        };
                        _spawned pushBack _veh;
                        ["INFO", format ["Base asset %1/%2 spawned: %3 (%4).", _sideKey, _role, _class, if (_needsCrew) then {"crewed"} else {"empty"}]] call NeroAI_fnc_log;
                    };
                };
            };
        } forEach _package;
        _registry set [_sideKey, _spawned];
        missionNamespace setVariable [format ["NeroAI_basePos_%1", _sideKey], _base, true];
        ["INFO", format ["Base asset package for %1 complete: %2 asset(s) at %3.", _sideKey, count _spawned, [round (_base # 0), round (_base # 1)]]] call NeroAI_fnc_log;
    };
} forEach [
    ["BLUE", west,  ["respawn_west", "wl_base_west", "base_west"]],
    ["RED",  east,  ["respawn_east", "wl_base_east", "base_east"]]
];

missionNamespace setVariable ["NeroAI_baseAssets", _registry, true];
missionNamespace setVariable ["NeroAI_baseAssetsSpawned", true, true];
