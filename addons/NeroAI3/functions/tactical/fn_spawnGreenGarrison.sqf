if(getNumber(missionConfigFile >> "NeroWL_useDesigner")==1)exitWith{};
/* NeroAI 4.4.0 [Command]: GREEN (partisan) objective garrisons.
 *
 * Every Warlords sector that no army holds gets a scavenged, randomly mixed
 * park instead of bare infantry — deliberately NOT the standardised loadouts
 * BLUE and RED get from vanilla Warlords requisition. Per sector: 1-2
 * vehicles drawn at random (independently, so duplicates are normal) from
 * T-55, T-34, BTR-60, BRDM-2, BMP-1; sometimes an unarmed recon drone;
 * rarely a covering mortar placed ~1 km OFF the objective, not inside it.
 *
 * Bounded on purpose: garrisons are built lazily for sectors near players, once
 * per sector, under a global vehicle cap.
 *
 * Sector source is NeroAI_fnc_warlordsSectors (BIS_WL_sectorsArray or the
 * ModuleWLSector_F objects). `bis_wl_allWarlords`, used in 4.3.0, was the
 * list of AI COMMANDERS, not sectors — garrisons ended up on BLUE's base and
 * on RED squads in the field. Two hard rules survive from that incident:
 *   - a safety check with no data fails CLOSED (no base position → no spawn);
 *   - nothing is ever placed inside the base exclusion radius, mortar included. */
if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_greenGarrisonEnabled", true])) exitWith {};
private _sectors = [] call NeroAI_fnc_warlordsSectors;
if (_sectors isEqualTo []) exitWith {};

private _baseBlue = missionNamespace getVariable ["NeroAI_basePos_BLUE", []];
private _baseRed = missionNamespace getVariable ["NeroAI_basePos_RED", []];
if ((!(_baseBlue isEqualType []) || {(count _baseBlue) < 2}) || {!(_baseRed isEqualType []) || {(count _baseRed) < 2}}) exitWith {
    ["WARN", "GREEN гарнизоны пропущены: позиция базы BLUE или RED ещё не известна — без неё нельзя гарантировать, что гарнизон не встанет на базе."] call NeroAI_fnc_log;
};

private _players = allPlayers select {alive _x};
if (_players isEqualTo []) exitWith {};

private _radius = missionNamespace getVariable ["NeroAI_greenGarrisonRadiusMeters", 5000];
private _cap = missionNamespace getVariable ["NeroAI_greenGarrisonMaxVehicles", 40];
private _spawnedTotal = missionNamespace getVariable ["NeroAI_greenGarrisonVehicles", 0];
if (_spawnedTotal >= _cap) exitWith {};
if (([0] call NeroAI_fnc_greenRoom) <= 0) exitWith {};

/* Has to clear the mortar's own ~1.3 km max standoff too. */
private _baseExclusionMeters = missionNamespace getVariable ["NeroAI_greenBaseExclusionMeters", 2000];

private _done = missionNamespace getVariable ["NeroAI_greenGarrisonDone", createHashMap];
private _usedCentres = missionNamespace getVariable ["NeroAI_greenGarrisonCentres", []];

private _fnc_nearBase = {
    params ["_p"];
    ((_p distance2D _baseBlue) < _baseExclusionMeters) || {(_p distance2D _baseRed) < _baseExclusionMeters}
};

/* 4.7.0 [Any Warlords]: the park is the mission's OWN Independent faction
 * (fn_factionAssets: Warlords group pools + CfgVehicles by faction tag), so a
 * Chernarus/Sahrani/Tanoa port fields ChDKZ/SLA/Syndikat hardware, not Takistani
 * T-55s. The Takistan catalogue (fn_assetCatalog) is only the last resort when the
 * faction has no armed land vehicle at all (pure-infantry resistance). */
private _fnc_class = { params ["_role"]; [_role, "GREEN"] call NeroAI_fnc_assetCatalog };
private _factionPark = createHashMap;
{ _factionPark set [_x, ["GREEN", _x] call NeroAI_fnc_factionAssets]; } forEach ["TANK", "APC", "CAR", "MORTAR", "UAV_RECON"];
private _fnc_kindWeights = {
    /* TANK 35 / APC 40 / CAR 25 — only kinds the faction actually has */
    private _w = [];
    if !((_factionPark get "TANK") isEqualTo []) then { _w append ["TANK", "TANK", "TANK", "TANK", "TANK", "TANK", "TANK"]; };
    if !((_factionPark get "APC") isEqualTo []) then { _w append ["APC", "APC", "APC", "APC", "APC", "APC", "APC", "APC"]; };
    if !((_factionPark get "CAR") isEqualTo []) then { _w append ["CAR", "CAR", "CAR", "CAR", "CAR"]; };
    _w
};
private _kindWeights = [] call _fnc_kindWeights;
private _fnc_pickVehicle = {
    /* -> [class, label] */
    if !(_kindWeights isEqualTo []) then {
        private _k = selectRandom _kindWeights;
        private _class = selectRandom (_factionPark get _k);
        private _dn = getText (configFile >> "CfgVehicles" >> _class >> "displayName");
        [_class, if (_dn isEqualTo "") then {_class} else {_dn}]
    } else {
        private _role = selectRandom _pool;
        [[_role] call _fnc_class, _poolLabel getOrDefault [_role, _role]]
    }
};
private _fnc_pickRole = {
    params ["_kind"];
    private _own = _factionPark getOrDefault [_kind, []];
    if !(_own isEqualTo []) then { selectRandom _own } else { [_kind] call _fnc_class }
};

private _fnc_place = {
    params ["_class", "_centre", "_grp", "_index", ["_spreadDist", 180], ["_spreadBase", 60], ["_angleOverride", -1]];
    if (_class isEqualTo "") exitWith {objNull};
    private _angle = if (_angleOverride >= 0) then {_angleOverride} else {random 360};
    private _dist = _spreadBase + random _spreadDist;
    private _spot = _centre getPos [_dist, _angle];
    private _safe = [_spot, 0, 40, 8, 0, 0.4, 0] call BIS_fnc_findSafePos;
    if (!(_safe isEqualType []) || {(count _safe) < 2}) then { _safe = _spot; };
    private _veh = createVehicle [_class, _safe, [], 20, "NONE"];
    if (isNull _veh) exitWith {objNull};
    _veh setVariable ["NeroAI_ownerSide", resistance, true];
    _veh setDir (random 360);
    createVehicleCrew _veh;
    private _c = crew _veh;
    /* Lobby-wide GREEN cap: the new crew is already counted alive. */
    if (([0] call NeroAI_fnc_greenRoom) < 0) exitWith {
        {_veh deleteVehicleCrew _x;} forEach _c;
        deleteVehicle _veh;
        objNull
    };
    if !(_c isEqualTo []) then {
        _c joinSilent _grp;
    };
    _veh
};

/* The scavenged pool: independently drawn per slot, duplicates expected. */
private _pool = ["TANK_MAIN", "TANK_LEGACY", "APC_BTR60", "APC_BRDM2", "IFV_BMP1"];
private _poolLabel = createHashMap;
_poolLabel set ["TANK_MAIN", "T-55"];
_poolLabel set ["TANK_LEGACY", "T-34"];
_poolLabel set ["APC_BTR60", "БТР-60"];
_poolLabel set ["APC_BRDM2", "БРДМ-2"];
_poolLabel set ["IFV_BMP1", "БМП-1"];

{
    _x params ["_sector", "_pos", "_name", "_ownerKey", "_isBase"];
    private _sid = str _sector;
    /* Only sectors no army holds get a partisan park; base sectors never. */
    if (!(_done getOrDefault [_sid, false]) && {_spawnedTotal < _cap} && {!_isBase} && {_ownerKey in ["NONE", "GREEN"]}) then {
        private _near = (_players findIf {(_x distance2D _pos) <= _radius}) >= 0;
        private _onBase = [_pos] call _fnc_nearBase;
        private _duplicate = (_usedCentres findIf {(_x distance2D _pos) < 300}) >= 0;

        if (_onBase) then {
            ["WARN", format ["GREEN гарнизон на секторе %1 (%2,%3) пропущен: слишком близко к базе.", _name, round (_pos # 0), round (_pos # 1)]] call NeroAI_fnc_log;
            _done set [_sid, true];
        };
        if (_duplicate) then {
            ["WARN", format ["GREEN гарнизон на секторе %1 (%2,%3) пропущен: совпадает с уже использованной позицией.", _name, round (_pos # 0), round (_pos # 1)]] call NeroAI_fnc_log;
            _done set [_sid, true];
        };

        if (_near && {!_onBase} && {!_duplicate}) then {
            _done set [_sid, true];
            _usedCentres pushBack _pos;

            private _grp = createGroup [resistance, true];
            _grp deleteGroupWhenEmpty true;
            _grp setBehaviour "AWARE";
            _grp setCombatMode "YELLOW";
            private _built = 0;
            private _log = [];

            /* 4.5.0: 1-2 vehicles per sector (was 2-4), each an independent random draw. */
            private _count = 1 + (floor random 2);
            for "_i" from 1 to _count do {
                private _pick = [] call _fnc_pickVehicle;
                private _v = [_pick # 0, _pos, _grp, _i] call _fnc_place;
                if (!isNull _v) then { _built = _built + 1; _log pushBack (_pick # 1); };
            };

            /* Sometimes an unarmed spotter drone (a small quadrotor). */
            if (random 1 < (missionNamespace getVariable ["NeroAI_greenDroneChance", 0.15])) then {
                private _v = [["UAV_RECON"] call _fnc_pickRole, _pos, _grp, 60] call _fnc_place;
                if (!isNull _v) then { _built = _built + 1; _log pushBack "БПЛА"; };
            };

            /* Rarely a covering mortar ~1 km off the objective; the offset
             * direction is verified to clear both bases, never assumed. */
            if (random 1 < (missionNamespace getVariable ["NeroAI_greenMortarChance", 0.12])) then {
                private _standoff = missionNamespace getVariable ["NeroAI_greenMortarStandoffMeters", 1000];
                private _angle = -1;
                for "_try" from 1 to 8 do {
                    private _candidateAngle = random 360;
                    private _candidatePos = _pos getPos [_standoff + (_standoff * 0.3), _candidateAngle];
                    if !([_candidatePos] call _fnc_nearBase) exitWith { _angle = _candidateAngle; };
                };
                if (_angle < 0) then {
                    ["WARN", format ["GREEN гарнизон на секторе %1: миномёт прикрытия пропущен — ни одно из 8 направлений не очистило базу.", _name]] call NeroAI_fnc_log;
                } else {
                    private _mortarGrp = createGroup [resistance, true];
                    _mortarGrp deleteGroupWhenEmpty true;
                    _mortarGrp setBehaviour "SAFE";
                    _mortarGrp setCombatMode "GREEN";
                    private _v = [["MORTAR"] call _fnc_pickRole, _pos, _mortarGrp, 1, 300, _standoff, _angle] call _fnc_place;
                    if (!isNull _v) then {
                        _built = _built + 1;
                        _v setVariable ["NeroAI_isMortarAsset", true, true];
                        _log pushBack format ["МИНОМЁТ прикрытия @%1м", _standoff];
                    };
                };
            };

            _spawnedTotal = _spawnedTotal + _built;
            ["INFO", format ["GREEN гарнизон на секторе %1 (%2,%3): %4 машин [%5]; всего %6/%7.",
                _name, round (_pos # 0), round (_pos # 1), _built, _log joinString ", ", _spawnedTotal, _cap]] call NeroAI_fnc_log;
        };
    };
} forEach _sectors;

missionNamespace setVariable ["NeroAI_greenGarrisonDone", _done];
missionNamespace setVariable ["NeroAI_greenGarrisonVehicles", _spawnedTotal];
missionNamespace setVariable ["NeroAI_greenGarrisonCentres", _usedCentres];
