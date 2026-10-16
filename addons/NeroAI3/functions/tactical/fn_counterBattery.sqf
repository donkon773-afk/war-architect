/* NeroAI 4.4.0 [Command]: hostile mortar / artillery tracking and counter-battery tasking.
 *
 * Indirect fire is the one threat vanilla AI never answers. This watcher finds
 * hostile tubes, hangs a Fired handler on each so we know when one actually
 * shoots, and hands the nearest suitable NeroAI group a counter-battery task —
 * which the LLM then turns into a recon push, a UAV sweep or a strike.
 *
 * A battery only becomes a task once it has FIRED (not merely existed), which
 * keeps the AI from omnisciently hunting tubes nobody has heard yet. */
if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_counterBatteryEnabled", true])) exitWith {};

private _now = diag_tickTime;
private _batteries = missionNamespace getVariable ["NeroAI_hostileBatteries", createHashMap];
private _scanRange = missionNamespace getVariable ["NeroAI_counterBatteryRangeMeters", 3000];
private _ttl = missionNamespace getVariable ["NeroAI_counterBatteryTtlSeconds", 300];

/* --- 1. Hang a Fired handler on every indirect-fire tube we can see. ------ */
{
    private _veh = _x;
    /* cbChecked latches on EVERY vehicle, tube or not, so the expensive
     * getArtilleryAmmo probe runs once per vehicle for the whole mission
     * instead of on every 10-second pass over a several-hundred-vehicle map. */
    if (alive _veh && {!(_veh getVariable ["NeroAI_cbChecked", false])}) then {
        _veh setVariable ["NeroAI_cbChecked", true, false];
        private _isTube = (_veh isKindOf "StaticMortar") ||
            {_veh getVariable ["NeroAI_isMortarAsset", false]} ||
            {"mortar" in (toLower (typeOf _veh))} ||
            {!((getArtilleryAmmo [_veh]) isEqualTo [])};
        if (_isTube) then {
            _veh setVariable ["NeroAI_cbWatched", true, true];
            _veh addEventHandler ["Fired", {
                params ["_shooter"];
                private _log = missionNamespace getVariable ["NeroAI_hostileBatteries", createHashMap];
                private _id = netId _shooter;
                private _entry = _log getOrDefault [_id, []];
                private _rounds = if ((count _entry) >= 5) then {(_entry # 4) + 1} else {1};
                _log set [_id, [getPosATL _shooter, side _shooter, diag_tickTime, _shooter, _rounds]];
                missionNamespace setVariable ["NeroAI_hostileBatteries", _log];
            }];
        };
    };
} forEach vehicles;

/* --- 2. Age out silent or destroyed batteries. ---------------------------- */
private _stale = [];
{
    private _entry = _y;
    private _dead = (count _entry) < 4 || {isNull (_entry # 3)} || {!(alive (_entry # 3))};
    private _old = (count _entry) >= 3 && {(_now - (_entry # 2)) > _ttl};
    if (_dead || {_old}) then { _stale pushBack _x; };
} forEach _batteries;
{ _batteries deleteAt _x; } forEach _stale;
missionNamespace setVariable ["NeroAI_hostileBatteries", _batteries];
if ((count _batteries) isEqualTo 0) exitWith {};

/* --- 3. Task the nearest hostile NeroAI group with the hunt. -------------- */
private _cool = missionNamespace getVariable ["NeroAI_counterBatteryTaskCooldown", 120];
{
    private _entry = _y;
    if ((count _entry) >= 5) then {
        private _pos = _entry # 0;
        private _batSide = _entry # 1;
        private _tube = _entry # 3;

        private _hunter = grpNull;
        private _best = _scanRange;
        {
            private _grp = _y;
            if ([_grp] call NeroAI_fnc_validateGroup) then {
                private _ldr = leader _grp;
                private _gs = side _ldr;
                if ((_gs getFriend _batSide) < 0.6) then {
                    private _d = _ldr distance2D _pos;
                    private _busy = (_now - (_grp getVariable ["NeroAI_lastCounterBatteryTask", -1e6])) < _cool;
                    if (_d < _best && {!_busy}) then { _best = _d; _hunter = _grp; };
                };
            };
        } forEach NeroAI_activeGroups;

        if (!isNull _hunter) then {
            private _ldr = leader _hunter;
            private _bearing = round (_ldr getDir _pos);
            private _dist = round (_ldr distance2D _pos);
            _hunter setVariable ["NeroAI_counterBattery", [[round (_pos # 0), round (_pos # 1)], _bearing, _dist, _entry # 4, _now], true];
            _hunter setVariable ["NeroAI_lastCounterBatteryTask", _now, true];
            _hunter setVariable ["NeroAI_forcePlan", true, true];

            private _events = _hunter getVariable ["NeroAI_events", []];
            _events pushBack ["ENEMY_MORTAR", _bearing, _dist, _entry # 4, _now];
            if ((count _events) > 4) then { _events = _events select [(count _events) - 4, 4]; };
            _hunter setVariable ["NeroAI_events", _events, true];

            private _callsign = _hunter getVariable ["NeroAI_callsign", groupId _hunter];
            private _shout = format ["%1: работает миномёт противника, азимут %2, дистанция %3 — выдвигаю разведку на подавление.", _callsign, _bearing, _dist];
            [_ldr, _shout, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
            ["WARN", format ["%1 counter-battery task: hostile tube %2 @%3,%4 (%5 round(s)).",
                _callsign, typeOf _tube, round (_pos # 0), round (_pos # 1), _entry # 4]] call NeroAI_fnc_log;
        };
    };
} forEach _batteries;
