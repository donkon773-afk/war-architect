/* Road route over the engine's own road network: A* on road segments
 * (roadsConnectedTo, plus nearRoads links of up to 25 m that bridge the gaps
 * at junctions and bridges). The map's road shapefile covers only part of the
 * network (Australia: 162 km, main highways missing), so the live road objects
 * are the source of truth. Returns ATL checkpoints about every 100 m from the
 * road nearest to _from to the road nearest to _to, or [] when the two are not
 * connected within the expansion budget. Scheduled only (spawned callers).
 * Results are cached per start/goal road pair for the mission. */
params ["_from","_to",["_maxExpand",30000],["_avoidRoads",[]]];
if (!canSuspend) exitWith {[]};
private _nearest = {
    params ["_pos","_radius"];
    private _roads = (_pos nearRoads _radius) select {isOnRoad (getPosATL _x)};
    if (_roads isEqualTo []) then {_roads = _pos nearRoads _radius;};
    if (_roads isEqualTo []) exitWith {objNull};
    private _best = _roads # 0;
    {if ((_x distance2D _pos) < (_best distance2D _pos)) then {_best = _x;};} forEach _roads;
    _best
};
private _start = [_from, 300] call _nearest;
private _goal = [_to, 400] call _nearest;
if (isNull _start || {isNull _goal}) exitWith {[]};
private _cache = missionNamespace getVariable ["NeroWL_roadRouteCache", createHashMap];
private _cacheKey = (str _start) + "|" + (str _goal);
if (_avoidRoads isEqualTo [] && {_cacheKey in _cache}) exitWith {+(_cache get _cacheKey)};

private _goalPos = getPosATL _goal;
private _objects = createHashMap;   // key -> road object
private _gScore = createHashMap;    // key -> cost so far
private _cameFrom = createHashMap;  // key -> previous key
private _closed = createHashMap;
private _heap = [];                 // binary min-heap of [f, key]
private _push = {
    params ["_f","_k"];
    _heap pushBack [_f,_k];
    private _i = (count _heap) - 1;
    while {_i > 0} do {
        private _p = floor ((_i - 1) / 2);
        if (((_heap # _p) # 0) <= _f) exitWith {};
        private _tmp = _heap # _p; _heap set [_p, _heap # _i]; _heap set [_i, _tmp];
        _i = _p;
    };
};
private _pop = {
    private _top = _heap # 0;
    private _last = _heap deleteAt ((count _heap) - 1);
    if (_heap isNotEqualTo []) then {
        _heap set [0, _last];
        private _i = 0;
        private _n = count _heap;
        while {true} do {
            private _l = 2 * _i + 1;
            private _r = _l + 1;
            private _m = _i;
            if (_l < _n && {((_heap # _l) # 0) < ((_heap # _m) # 0)}) then {_m = _l;};
            if (_r < _n && {((_heap # _r) # 0) < ((_heap # _m) # 0)}) then {_m = _r;};
            if (_m == _i) exitWith {};
            private _tmp = _heap # _m; _heap set [_m, _heap # _i]; _heap set [_i, _tmp];
            _i = _m;
        };
    };
    _top
};
private _startKey = str _start;
private _goalKey = str _goal;
_objects set [_startKey, _start];
_gScore set [_startKey, 0];
[_start distance2D _goalPos, _startKey] call _push;
private _found = false;
private _expanded = 0;
while {_heap isNotEqualTo [] && {_expanded < _maxExpand}} do {
    private _key = (call _pop) # 1;
    if !(_key in _closed) then {
        _closed set [_key, true];
        _expanded = _expanded + 1;
        if (_key == _goalKey) exitWith {_found = true;};
        private _road = _objects get _key;
        private _g = _gScore get _key;
        private _next = roadsConnectedTo _road;
        if ((count _next) < 2) then {_next append ((getPosATL _road) nearRoads 25);};
        {
            if !(isNull _x || {_x isEqualTo _road} || {_x in _avoidRoads}) then {
                private _k = str _x;
                if !(_k in _closed) then {
                    private _cost = _g + (_road distance2D _x);
                    if (_cost < (_gScore getOrDefault [_k, 1e12])) then {
                        _gScore set [_k, _cost];
                        _cameFrom set [_k, _key];
                        _objects set [_k, _x];
                        [_cost + (_x distance2D _goalPos), _k] call _push;
                    };
                };
            };
        } forEach _next;
    };
    if (_found) exitWith {};
    if ((_expanded mod 400) == 0) then {sleep 0.01;};
};
if (!_found) exitWith {
    ["WARN", format ["roadRoute: no road connection within %1 expansions from %2 to %3", _expanded, getPosATL _start apply {round _x}, _goalPos apply {round _x}]] call NeroAI_fnc_log;
    if (_avoidRoads isEqualTo []) then {_cache set [_cacheKey, []];};
    missionNamespace setVariable ["NeroWL_roadRouteCache", _cache];
    []
};
private _chain = [];
private _k = _goalKey;
while {_k != ""} do {
    _chain pushBack (_objects get _k);
    _k = _cameFrom getOrDefault [_k, ""];
};
reverse _chain;
private _points = [];
private _last = getPosATL _start;
{
    private _p = getPosATL _x;
    if ((_p distance2D _last) >= 100) then {_points pushBack [_p # 0, _p # 1, 0]; _last = _p;};
} forEach _chain;
_points pushBack [_goalPos # 0, _goalPos # 1, 0];
if ((count _cache) > 400) then {_cache = createHashMap;};
if (_avoidRoads isEqualTo []) then {_cache set [_cacheKey, +_points];};
missionNamespace setVariable ["NeroWL_roadRouteCache", _cache];
_points
