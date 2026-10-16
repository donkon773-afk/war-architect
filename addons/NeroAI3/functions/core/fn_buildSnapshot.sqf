params ["_groups", "_player", "_channel", "_command"];
if (_groups isEqualTo []) exitWith {""};
private _snapshotSide = side (_groups # 0);
_groups = _groups select {[_x] call NeroAI_fnc_validateGroup && {side _x isEqualTo _snapshotSide}};
if (_groups isEqualTo []) exitWith {""};
// An enemy player must never become this side's observer or camera source.
if (!isNull _player && {!(side (group _player) isEqualTo _snapshotSide)}) then {_player = objNull;};
if (isNil "NeroAI_memorySession") then {NeroAI_memorySession = format ["%1/%2/%3",worldName,missionName,diag_tickTime];};

private _groupStates = [];
{
    private _group = _x;
    if ([_group] call NeroAI_fnc_validateGroup) then {
        private _memorySide = _group getVariable ["NeroAI_memorySide",_snapshotSide];
        if !(_memorySide isEqualTo _snapshotSide) then {
            {_group setVariable [_x,[]];} forEach ["NeroAI_intel","NeroAI_lastLlmDecision","NeroAI_lastActionResult","NeroAI_events","NeroAI_dialogue","NeroAI_radioFrom","NeroAI_counterBattery"];
        };
        _group setVariable ["NeroAI_memorySide",_snapshotSide];
        private _living = (units _group) select {alive _x};
        /* 4.5.0: the group's purse — its warlord's Warlords CP (-1 = no purse,
         * i.e. a sector garrison / response team that cannot BUY anything). */
        private _cp = -1;
        if (!isNil "BIS_WL_allWarlords") then {
            private _wls = missionNamespace getVariable ["BIS_WL_allWarlords", []];
            private _wl = _living select {_x in _wls};
            if !(_wl isEqualTo []) then {
                private _f = (_wl # 0) getVariable ["BIS_WL_funds", 0];
                if (_f isEqualType 0) then { _cp = round _f; };
            };
        };
        private _intel = +(_group getVariable ["NeroAI_intel", []]);
        _intel resize ((count _intel) min 12);
        private _initial = _group getVariable ["NeroAI_initialStrength", count _living];
        private _capabilities = [_group] call NeroAI_fnc_analyzeGroupCapabilities;
        /* 4.4.0 token economy: one row per (unit class, mount) with counts and
         * averages instead of up to 16 near-identical per-man rows — a six-man
         * tank crew used to cost six rows saying the same thing. */
        private _agg = createHashMap;
        {
            private _vehicle = vehicle _x;
            private _mount = if (_vehicle isEqualTo _x) then {"ON_FOOT"} else {typeOf _vehicle};
            private _k = format ["%1|%2", typeOf _x, _mount];
            private _row = _agg getOrDefault [_k, [typeOf _x, 0, 0, 0, 0, _mount]];
            _row set [1, (_row # 1) + 1];
            _row set [2, (_row # 2) + damage _x];
            _row set [3, (_row # 3) + getFatigue _x];
            _row set [4, (_row # 4) + getSuppression _x];
            _agg set [_k, _row];
        } forEach _living;
        private _unitStates = [];
        {
            private _n = _y # 1;
            _unitStates pushBack [_y # 0, _n, round ((_y # 2) / _n * 100), round ((_y # 3) / _n * 100), round ((_y # 4) / _n * 100), _y # 5];
        } forEach _agg;
        _unitStates resize ((count _unitStates) min 6);
        private _decisionMemory = +(_group getVariable ["NeroAI_lastLlmDecision", []]);
        /* keep [time, actions] only — the previous speech is ~200 Cyrillic chars
         * the model never needs to see again */
        if (_decisionMemory isEqualType [] && {(count _decisionMemory) >= 3}) then { _decisionMemory set [1, ""]; };
        private _actionMemory = _group getVariable ["NeroAI_lastActionResult", []];
        private _routeState = _group getVariable ["NeroWL_routeState",""];
        if (_routeState find "BLOCKED" == 0) then {_actionMemory = [diag_tickTime,"MOVE",false,_routeState];};
        _groupStates pushBack [
            _group getVariable ["NeroAI_callsign", groupId _group],
            "VANILLA",
            [round ((getPosATL (leader _group)) # 0), round ((getPosATL (leader _group)) # 1)],
            count _living,
            _initial,
            (_initial - count _living) max 0,
            _cp,
            _intel,
            round (getDir (leader _group)),
            _capabilities,
            _group getVariable ["NeroAI_playerROE", ""],
            _group getVariable ["NeroAI_vehicleState", "ON_FOOT"],
            _group getVariable ["NeroAI_playerHold", false],
            [_group getVariable ["NeroAI_mobility", ["UNKNOWN", [], 0, 0, 0, [0, false]]]] call {
                private _m = +(_this # 0);
                if ((count _m) > 1 && {(_m # 1) isEqualType []} && {(count (_m # 1)) >= 2}) then { _m set [1, [round ((_m # 1) # 0), round ((_m # 1) # 1)]]; };
                if ((count _m) > 2 && {(_m # 2) isEqualType 0}) then { _m set [2, round (_m # 2)]; };
                _m
            },
            _unitStates,
            [_decisionMemory, _actionMemory],
            /* 8.10: running behaviour template [name, MARCH|EXEC, seconds] or [] */
            [_group getVariable ["NeroWL_tactic", []]] call {
                private _t = _this # 0;
                if (_t isEqualTo []) exitWith {[]};
                [_t # 0, _t # 3, round (diag_tickTime - (_t # 2))]
            }
        ];
    };
} forEach _groups;

private _landmarks = [];
{
    private _nearbyHouses = nearestObjects [leader _x, ["House"], 250];
    _nearbyHouses resize ((count _nearbyHouses) min 3);
    {
        private _pos = getPosATL _x;
        _landmarks pushBackUnique [typeOf _x, [round (_pos # 0), round (_pos # 1)]];
    } forEach _nearbyHouses;
} forEach _groups;
_landmarks resize ((count _landmarks) min 4);

private _locations = [];
{
    private _nearbyLocations = nearestLocations [getPosATL (leader _x), ["NameCityCapital", "NameCity", "NameVillage", "NameLocal", "Hill"], 3500];
    _nearbyLocations resize ((count _nearbyLocations) min 3);
    {
        private _pos = locationPosition _x;
        _locations pushBackUnique [text _x, type _x, [round (_pos # 0), round (_pos # 1)]];
    } forEach _nearbyLocations;
} forEach _groups;
_locations resize ((count _locations) min 5);

/* 4.4.0: the real Warlords objectives, nearest first, with who holds them —
 * without this the planner had nothing to attack and dithered 50 m from its
 * own base ("groups do not carry out orders"). Owner keys: BLUE/RED/GREEN/NONE
 * (NONE = unowned, i.e. the vanilla partisan garrison). */
private _sectors = [];
if !(_groups isEqualTo []) then {
    private _anchor = getPosATL (leader (_groups # 0));
    private _byDist = [];
    {
        _x params ["_sObj", "_sPos", "_sName", "_sOwner", "_sIsBase"];
        _byDist pushBack [round (_anchor distance2D _sPos), _sName, [round (_sPos # 0), round (_sPos # 1)], _sOwner, _sIsBase];
    } forEach ([] call NeroAI_fnc_warlordsSectors);
    _byDist sort true;
    _byDist resize ((count _byDist) min 8);
    /* [name, [x,y], owner, distM, isBase] */
    _sectors = _byDist apply { [_x # 1, _x # 2, _x # 3, _x # 0, _x # 4] };
};
/* 4.7.0 [Any Warlords]: the terrain line is surveyed from the map by
 * fn_scenarioProfile ("Chernarus | hills, forest, villages"); the factions are the
 * mission's own, so the model speaks as ChDKZ or Syndikat, not always Takistan. */
private _terrain = missionNamespace getVariable ["NeroAI_terrainLine", missionNamespace getVariable ["NeroAI_terrainProfile", "TAKISTAN"]];
private _factionNames = missionNamespace getVariable ["NeroAI_factionNames", createHashMap];
private _factions = [_factionNames getOrDefault ["BLUE", ""], _factionNames getOrDefault ["RED", ""], _factionNames getOrDefault ["GREEN", ""]];
/* 4.4.0: side key so the bridge can route each side to its own model. */
private _sideKeyOut = if (_groups isEqualTo []) then {"BLUE"} else {
    switch (side (leader (_groups # 0))) do { case east: {"RED"}; case resistance: {"GREEN"}; default {"BLUE"} }
};
/* 4.7.0b: the PLAYER's side, so the bridge can put "my army" on one brain and
 * "the enemy" on another whichever Warlords army the player picked. The
 * addressed player if there is one, else the first live player on the server. */
private _playerRef = if (isNull _player) then { (allPlayers select {alive _x}) param [0, objNull] } else { _player };
private _playerSideOut = if (isNull _playerRef) then {"BLUE"} else {
    switch (side (group _playerRef)) do { case civilian: {"NONE"}; case east: {"RED"}; case resistance: {"GREEN"}; default {"BLUE"} }
};

/* 4.5.0: what the side's CP can buy — [kind, minCost, maxCost] per kind
 * (vanilla requisition list of this side, cached per side). Lets the planner
 * decide BUY TANK vs BUY INFANTRY without seeing the whole catalogue. */
private _shop = [];
if (!(_groups isEqualTo []) && {!isNil "BIS_WL_allWarlords"}) then {
    private _shopSide = side (leader (_groups # 0));
    private _shopCache = missionNamespace getVariable ["NeroAI_shopCache", createHashMap];
    private _shopKey = str _shopSide;
    private _shopHit = _shopCache getOrDefault [_shopKey, [-1e6, []]];
    if ((diag_tickTime - (_shopHit # 0)) < 30) then {
        _shop = +(_shopHit # 1);
    } else {
        private _list = missionNamespace getVariable [format ["BIS_WL_purchasable%1", _shopSide], nil];
        if (isNil "_list") then {
            private _wls = (missionNamespace getVariable ["BIS_WL_allWarlords", []]) select {!isNull _x && {side (group _x) isEqualTo _shopSide}};
            if !(_wls isEqualTo []) then { _list = (_wls # 0) getVariable ["BIS_WL_purchasable", nil]; };
        };
        if (!isNil "_list" && {_list isEqualType []} && {(count _list) >= 2}) then {
            private _cfgV = configFile >> "CfgVehicles";
            private _ranges = createHashMap;
            private _fnc_note = {
                params ["_kind", "_cost"];
                private _r = _ranges getOrDefault [_kind, [1e9, 0]];
                _ranges set [_kind, [(_r # 0) min _cost, (_r # 1) max _cost]];
            };
            { if (_x isEqualType [] && {(count _x) >= 2} && {(_x # 1) isEqualType 0}) then { ["INFANTRY", _x # 1] call _fnc_note; }; } forEach (_list # 0);
            {
                if (_x isEqualType [] && {(count _x) >= 2} && {(_x # 0) isEqualType ""} && {(_x # 1) isEqualType 0}) then {
                    private _c = _x # 0;
                    private _k = [_c] call NeroAI_fnc_groundAssetKind;
                    if !(_k isEqualTo "") then { [_k, _x # 1] call _fnc_note; };
                };
            } forEach (_list # 1);
            if (count _list >= 5) then {
                {
                    private _class = _x # 0;
                    private _kind = if (getNumber (_cfgV >> _class >> "isUav") == 1) then {"UAV"} else {
                        if (_class isKindOf "Helicopter") then {"HELICOPTER"} else {"PLANE"}
                    };
                    [_kind,_x # 1] call _fnc_note;
                } forEach (_list # 4);
            };
            { _shop pushBack [_x, _y # 0, _y # 1]; } forEach _ranges;
        };
        _shopCache set [_shopKey, [diag_tickTime, +_shop]];
        missionNamespace setVariable ["NeroAI_shopCache", _shopCache];
    };
};

/* Vehicles and the shared radio picture are compact tactical facts, not lore. */
private _assets = [];
{
    private _vehicle = _x;
    private _nearControlledGroup = false;
    {
        if (_vehicle distance2D (leader _x) <= 650) exitWith {_nearControlledGroup = true;};
    } forEach _groups;
    if (_nearControlledGroup && {alive _vehicle} && {canMove _vehicle} && {([_vehicle] call NeroAI_fnc_getVehicleSide) isEqualTo _snapshotSide}) then {
        private _kind = if (_vehicle isKindOf "Air") then {"AIR"} else {[typeOf _vehicle] call NeroAI_fnc_groundAssetKind};
        if (_kind=="") then {_kind="LAND";};
        private _pos = getPosATL _vehicle;
        _assets pushBack [
            typeOf _vehicle,
            _kind,
            [round (_pos # 0), round (_pos # 1)],
            count crew _vehicle,
            ((_vehicle emptyPositions "driver") max 0) + ((_vehicle emptyPositions "gunner") max 0) + ((_vehicle emptyPositions "commander") max 0) + ((_vehicle emptyPositions "cargo") max 0),
            round (damage _vehicle * 100),
            round (fuel _vehicle * 100),
            canFire _vehicle
        ];
    };
} forEach vehicles;
_assets resize ((count _assets) min 8);

private _sharedIntel = [];
if !(_groups isEqualTo []) then {
    private _sideKey = str (side (leader (_groups # 0)));
    _sharedIntel = +(NeroAI_sharedIntel getOrDefault [_sideKey, []]);
    _sharedIntel = _sharedIntel select {(_x isEqualType []) && {count _x >= 4} && {diag_tickTime - (_x # 3) <= (missionNamespace getVariable ["NeroAI_intelTtlSeconds",180])}};
    _sharedIntel resize ((count _sharedIntel) min 6);
};

/* 4.2.0 context: recent ambush / combat events, the rolling player<->group
 * conversation, and any visual observation the squad reported. */
private _turns = missionNamespace getVariable ["NeroAI_conversationTurns", 6];
private _nowSnap = diag_tickTime;
private _events = [];
private _dialogue = [];
private _vision = [];
private _radioFrom = [];
/* 4.3.0: what this group can actually call on, and any live counter-battery
 * hunt. Both are compact rows — the model needs to know a tube exists and is
 * ready, not the whole motor pool. */
private _support = [];
private _cbTask = [];
if !(_groups isEqualTo []) then {
    {
        private _ge = _x getVariable ["NeroAI_events", []];
        if (_ge isEqualType []) then {
            {
                private _row = _x;
                if (_row isEqualType [] && {count _row >= 5}) then {
                    /* Replace the stored timestamp with elapsed seconds for the model. */
                    _events pushBack [_row # 0, _row # 1, _row # 2, _row # 3, round (_nowSnap - (_row # 4))];
                };
            } forEach _ge;
        };
    } forEach _groups;
    _events resize ((count _events) min 6);
    private _lead = _groups # 0;

    /* Support availability for the lead group's side: [role, count, readyCount].
     * Recomputed at most once every few seconds and cached per side — a snapshot
     * is built several times per autonomy tick and `vehicles` is a long list. */
    private _leadSide = side (leader _lead);
    private _nowSup = diag_tickTime;
    private _supCache = missionNamespace getVariable ["NeroAI_supportCache", createHashMap];
    private _sideKeyCache = str _leadSide;
    private _cached = _supCache getOrDefault [_sideKeyCache, [-1e6, []]];
    if ((_nowSup - (_cached # 0)) < (missionNamespace getVariable ["NeroAI_supportCacheSeconds", 5])) then {
        _support = +(_cached # 1);
    } else {
        private _roles = createHashMap;
        private _cooldown = missionNamespace getVariable ["NeroAI_airSortieCooldownSeconds", 180];
        {
            private _veh = _x;
            private _role = _veh getVariable ["NeroAI_assetRole", ""];
            if (!(_role isEqualTo "") && {alive _veh} && {([_veh] call NeroAI_fnc_getVehicleSide) isEqualTo _leadSide}) then {
                private _row = _roles getOrDefault [_role, [0, 0]];
                private _ready = if (_veh isKindOf "Air") then {
                    ((_veh getVariable ["NeroAI_airState", "PARKED"]) in ["PARKED","READY"]) &&
                    {(_nowSup - (_veh getVariable ["NeroAI_lastSortie", -1e6])) >= _cooldown} &&
                    {!(_veh getVariable ["NeroWL_paidAir",false]) || {fuel _veh > 0.25 && {damage _veh < 0.4} && {alive driver _veh}}}
                } else {
                    canFire _veh
                };
                _roles set [_role, [(_row # 0) + 1, (_row # 1) + (if (_ready) then {1} else {0})]];
            };
        } forEach vehicles;
        { _support pushBack [_x, _y # 0, _y # 1]; } forEach _roles;
        _support resize ((count _support) min 10);
        _supCache set [_sideKeyCache, [_nowSup, +_support]];
        missionNamespace setVariable ["NeroAI_supportCache", _supCache];
    };

    /* Live counter-battery hunt handed to this group, if any. */
    private _cb = _lead getVariable ["NeroAI_counterBattery", []];
    if (_cb isEqualType [] && {(count _cb) >= 5} && {(diag_tickTime - (_cb # 4)) <= 300}) then {
        _cbTask = [_cb # 0, _cb # 1, _cb # 2, _cb # 3, round (diag_tickTime - (_cb # 4))];
    };
    _dialogue = +(_lead getVariable ["NeroAI_dialogue", []]);
    if ((count _dialogue) > _turns) then { _dialogue = _dialogue select [(count _dialogue) - _turns, _turns]; };
    /* Machine vision: only the player-addressed group gets the commander's-eye
     * frame, and only while it is fresh. Never fed to autonomous or enemy squads,
     * and it carries no coordinates or allegiance — description only. */
    if (!isNull _player) then {
        private _vl = missionNamespace getVariable ["NeroAI_visionLatest", []];
        if (_vl isEqualType [] && {count _vl >= 2} && {(_nowSnap - (_vl # 0)) <= 30}) then {
            private _payload = _vl # 1;
            _vision = ["COMMANDER_CAM", round (_nowSnap - (_vl # 0)), _payload param [0, ""], _payload param [1, []]];
        };
    };
    private _rf = _lead getVariable ["NeroAI_radioFrom", []];
    if (_rf isEqualType [] && {count _rf > 0}) then { _radioFrom = _rf; };
};

private _army=[];
private _armySide=side (leader (_groups # 0));
{
 private _g=group _x;
 if (side _g == _armySide && {!isPlayer _x} && {alive _x}) then {
  _army pushBack [_g getVariable ["NeroAI_callsign",groupId _g],_g getVariable ["NeroWL_role","INFANTRY"],count ((units _g) select {alive _x}),round (_x getVariable ["BIS_WL_funds",0]),count (_g getVariable ["BIS_WL_groupVehs",[]])];
 };
} forEach (missionNamespace getVariable ["BIS_WL_allWarlords",[]]);
_army resize ((count _army) min 16);
private _normalizedOrder = [_command, 900] call NeroAI_fnc_normalizeText;
private _observer = if (isNull _player) then {leader (_groups # 0)} else {_player};
/* 7.10: real road distances (fn_roadSurvey) for links touching this side's current
 * objective, so the planner knows when the road is much longer than the straight line. */
private _objectiveName = (missionNamespace getVariable [format ["BIS_WL_currentSector_%1", side (_groups # 0)], objNull]) getVariable ["BIS_WL_sectorName", ""];
private _roadLinks = ((missionNamespace getVariable ["NeroWL_roadLinks", []]) select {_objectiveName != "" && {_objectiveName in [_x # 0, _x # 1]}});
_roadLinks resize ((count _roadLinks) min 4);
private _encode = {
    str [
        "v", 3,
        "session", NeroAI_memorySession,
        "ch", _channel,
        "garrison", (_groups # 0) getVariable ["NeroWL_garrison",false],
        "army", _army,
        "role", (_groups # 0) getVariable ["NeroWL_role","INFANTRY"],
        "greenRole", if (getNumber (missionConfigFile >> "NeroWL_threeSides")==1) then {getText (missionConfigFile >> "CfgNeroDesign" >> "greenRole")} else {"defender"},
        "economy", [missionNamespace getVariable ["NeroAI_purchaseReserveCP",1500],missionNamespace getVariable ["BIS_WL_dropCost",25],missionNamespace getVariable ["NeroAI_purchaseSideCooldownSeconds",75]],
        "logistics", round (((_groups # 0) getVariable ["NeroWL_logisticsUntil",0]) - diag_tickTime) max 0,
        "observer", [round ((getPosATL _observer) # 0), round ((getPosATL _observer) # 1)],
        "observerDir", round (getDir _observer),
        "groups", _groupStates,
        "landmarks", _landmarks,
        "locations", _locations,
        "sectors", _sectors,
        "roadLinks", _roadLinks,
        "terrain", _terrain,
        "factions", _factions,
        "side", _sideKeyOut,
        "playerSide", _playerSideOut,
        "assets", _assets,
        "support", _support,
        "shop", _shop,
        "counterBattery", _cbTask,
        "sharedIntel", _sharedIntel,
        "events", _events,
        "dialogue", _dialogue,
        "vision", _vision,
        "radioFrom", _radioFrom,
        "order", _normalizedOrder
        ,"warlordsSettings", [missionNamespace getVariable ["NeroWL_aggression",1],missionNamespace getVariable ["NeroAI_airEnabled",true],missionNamespace getVariable ["NeroWL_airLimit",1]]
    ]
};
private _fnc_byteLen = {
    params ["_str"];
    private _b = 0;
    {
        if (_x <= 127) then { _b = _b + 1; } else { _b = _b + (if (_x <= 2047) then {2} else {3}); };
    } forEach (toArray _str);
    _b
};

private _limit = missionNamespace getVariable ["NeroAI_maxSnapshotBytes", missionNamespace getVariable ["NeroAI_maxSnapshotChars", 7400]];
private _encoded = call _encode;

/* Never cut an SQF value in the middle: reduce optional context until the
 * transport remains syntactically complete. The player's order and every
 * addressed group are retained. */
while {([_encoded] call _fnc_byteLen) > _limit && {!(_assets isEqualTo [])}} do {
    _assets deleteAt ((count _assets) - 1);
    _encoded = call _encode;
};
while {([_encoded] call _fnc_byteLen) > _limit && {!(_sharedIntel isEqualTo [])}} do {
    _sharedIntel deleteAt ((count _sharedIntel) - 1);
    _encoded = call _encode;
};
while {([_encoded] call _fnc_byteLen) > _limit && {!(_landmarks isEqualTo [])}} do {
    _landmarks deleteAt ((count _landmarks) - 1);
    _encoded = call _encode;
};
while {([_encoded] call _fnc_byteLen) > _limit && {!(_locations isEqualTo [])}} do {
    _locations deleteAt ((count _locations) - 1);
    _encoded = call _encode;
};
while {([_encoded] call _fnc_byteLen) > _limit && {!(_vision isEqualTo [])}} do {
    _vision deleteAt ((count _vision) - 1);
    _encoded = call _encode;
};
while {([_encoded] call _fnc_byteLen) > _limit && {(count _dialogue) > 1}} do {
    _dialogue deleteAt 0;
    _encoded = call _encode;
};
if (([_encoded] call _fnc_byteLen) > _limit) then {
    { _x set [7, []]; } forEach _groupStates;
    _encoded = call _encode;
};
/* Multi-group player orders: unit rows and plan memory go before the order itself. */
if (([_encoded] call _fnc_byteLen) > _limit) then {
    { _x set [14, []]; } forEach _groupStates;
    _encoded = call _encode;
};
if (([_encoded] call _fnc_byteLen) > _limit) then {
    { _x set [15, []]; } forEach _groupStates;
    _sectors resize ((count _sectors) min 3);
    _encoded = call _encode;
};
if (([_encoded] call _fnc_byteLen) > _limit) then {
    { _x set [14, []]; } forEach _groupStates;
    _encoded = call _encode;
};
if (([_encoded] call _fnc_byteLen) > _limit) then {
    { _x set [15, [[], []]]; } forEach _groupStates;
    _encoded = call _encode;
};
/* 4.7.0a: INIDBI2 treats "|" as its argument separator and truncates the value
 * at the first pipe (19.09: the terrain line "Алтис | …" cut every request).
 * Nothing NeroAI sends may contain one — map, faction, sector and player text
 * are all foreign strings, so the whole encoded snapshot is scrubbed here. */
if ((_encoded find "|") >= 0) then { _encoded = (_encoded splitString "|") joinString "/"; };
_encoded
