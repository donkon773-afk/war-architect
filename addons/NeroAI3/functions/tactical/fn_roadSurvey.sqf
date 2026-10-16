/* One background pass after Warlords is ready: the road distance of every
 * linked sector pair through fn_roadRoute, logged as one RPT line per link.
 * It warms the route cache the first marches use and gives the tooling the
 * real road network between objectives (the map shapefile is incomplete).
 * The result is also published as NeroWL_roadLinks for the planner snapshot:
 * [[nameA, nameB, roadKm, straightKm], ...]. */
if (!isServer || {!canSuspend}) exitWith {};
private _sectors = missionNamespace getVariable ["BIS_WL_sectors", []];
if (_sectors isEqualTo []) exitWith {};
private _done = createHashMap;
private _links = [];
private _t0 = diag_tickTime;
{
    private _a = _x;
    {
        private _b = _x;
        private _key = [str _a, str _b];
        _key sort true;
        if (!isNull _b && {!(_key in _done)}) then {
            _done set [_key, true];
            private _path = [getPosATL _a, getPosATL _b, 40000] call NeroAI_fnc_roadRoute;
            private _straight = (_a distance2D _b) / 1000;
            private _road = -1;
            if (_path isNotEqualTo []) then {
                _road = 0;
                private _prev = getPosATL _a;
                {_road = _road + (_prev distance2D _x); _prev = _x;} forEach _path;
                _road = (_road + (_prev distance2D _b)) / 1000;
            };
            private _na = _a getVariable ["BIS_WL_sectorName", _a getVariable ["Name", str _a]];
            private _nb = _b getVariable ["BIS_WL_sectorName", _b getVariable ["Name", str _b]];
            _links pushBack [_na, _nb, (round (_road * 10)) / 10, (round (_straight * 10)) / 10];
            diag_log format ["[NeroWL RoadLink] %1 | %2 | road=%3 km | straight=%4 km | checkpoints=%5", _na, _nb, (round (_road * 10)) / 10, (round (_straight * 10)) / 10, count _path];
            sleep 0.5;
        };
    } forEach (_a getVariable ["BIS_WL_connectedSectors", []]);
} forEach _sectors;
missionNamespace setVariable ["NeroWL_roadLinks", _links, true];
diag_log format ["[NeroWL RoadLink] survey done: %1 links in %2 s", count _links, round (diag_tickTime - _t0)];
