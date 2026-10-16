/* NeroAI 4.4.0 [Command]: bounded air sortie (CAS / armed recon).
 *
 * Aviation doctrine — deliberately cautious:
 *   - a sortie is refused if the aim point is inside the no-fly bubble around
 *     the ENEMY base, or near a known enemy AA asset;
 *   - the run-in point is offset to OUR side of the target, so the aircraft
 *     approaches from friendly airspace instead of overflying the objective;
 *   - the sortie is time-boxed; the aircraft returns to base, lands, parks and
 *     goes cold again, and a watchdog aborts early if it drifts into the
 *     enemy-base bubble or loses its target;
 *   - one sortie per airframe at a time, with a per-airframe cooldown.
 *
 * No waypoints are created or deleted — movement is doMove only — so mission
 * scripting (Warlords) is never disturbed. */
params ["_group", "_targetPos", ["_mission", "CAS"]];
if (!isServer) exitWith {[false, "Не сервер."]};
if (!(missionNamespace getVariable ["NeroAI_airEnabled", true])) exitWith {[false, "Авиация отключена."]};
if (!([_group] call NeroAI_fnc_validateGroup)) exitWith {[false, "Группа недоступна."]};
if (!(_targetPos isEqualType []) || {(count _targetPos) < 2}) exitWith {[false, "Некорректные координаты для авиаудара."]};

private _now = diag_tickTime;
private _side = side (leader _group);
private _sideKey = switch (_side) do { case east: {"RED"}; case resistance: {"GREEN"}; default {"BLUE"} };
private _aim = [_targetPos # 0, _targetPos # 1, 0];

/* --- Enemy base no-fly bubble ------------------------------------------- */
private _noFly = missionNamespace getVariable ["NeroAI_airEnemyBaseNoFlyMeters", 1400];
private _enemyKeys = ["BLUE", "RED"] select {!(_x isEqualTo _sideKey)};
private _blockedBy = "";
{
    private _bp = missionNamespace getVariable [format ["NeroAI_basePos_%1", _x], []];
    if (_bp isEqualType [] && {(count _bp) >= 2} && {(_aim distance2D _bp) < _noFly}) exitWith { _blockedBy = _x; };
} forEach _enemyKeys;
if !(_blockedBy isEqualTo "") exitWith {
    ["WARN", format ["%1 авиавылет отменён: цель в %2 м от базы %3 (запретная зона %4 м).",
        _group getVariable ["NeroAI_callsign", groupId _group], round (_aim distance2D (missionNamespace getVariable [format ["NeroAI_basePos_%1", _blockedBy], [0,0,0]])), _blockedBy, _noFly]] call NeroAI_fnc_log;
    [false, "Отказано: цель в запретной зоне у вражеской базы — авиация не идёт."]
};

/* --- Known enemy air defence near the aim point --------------------------- */
private _aaR = missionNamespace getVariable ["NeroAI_airAaAvoidMeters", 800];
private _known = (missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str _side,[]];
private _aaNear = (_known findIf {
    private _t = toLower (_x param [0,""]);
    private _p = _x param [1,[]];
    count _p >= 2 && {_aim distance2D _p < _aaR} &&
    {(["zsu","shilka","_aa","tunguska","strela","zu23","nasams","skynex","sam"] findIf {_t find _x >= 0}) >= 0}
}) >= 0;
if (_aaNear) exitWith {[false, "Отказано: у цели активное ПВО, авиация не идёт без подавления."]};

if (_mission in ["TRANSPORT","INTERCEPT","ESCORT"]) exitWith {[_group,_aim,_mission] call NeroAI_fnc_paidAirSortie};
/* --- Pick a cold airframe of our side ------------------------------------- */
/* 4.4.0: groups must not overload the air wing — one air request per group
 * per NeroAI_airGroupRequestCooldown, and at most NeroAI_airMaxConcurrentPerSide
 * airframes of a side airborne at once. Helicopters follow exactly the same
 * rules as jets. */
private _grpCool = missionNamespace getVariable ["NeroAI_airGroupRequestCooldown", 240];
private _lastReq = _group getVariable ["NeroAI_lastAirRequest", -1e6];
if ((_now - _lastReq) < _grpCool) exitWith {[false, format ["Отказано: авиацию для этой группы уже поднимали %1 с назад — не перегружай авиакрыло.", round (_now - _lastReq)]]};
if ((vehicles findIf {_x getVariable ["NeroWL_paidAir",false] && {alive _x} && {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) isEqualTo _side}}) >= 0) exitWith {
    [_group,_aim,_mission] call NeroAI_fnc_paidAirSortie
};
private _airborne = {alive _x && {_x isKindOf "Air"} && {([_x] call NeroAI_fnc_getVehicleSide) isEqualTo _side} && {(_x getVariable ["NeroAI_airState", "PARKED"]) isEqualTo "SORTIE"}} count vehicles;
if (_airborne >= (missionNamespace getVariable ["NeroAI_airMaxConcurrentPerSide", 2])) exitWith {[false, "Отказано: в воздухе уже максимум бортов стороны — дождись возвращения."]};
/* 4.5.0: the only scripted airframe is the side's armed drone — it flies both
 * the bounded RECON sortie and the CAS strike. Manned aviation is whatever the
 * vanilla scenario provides and is not dispatched by NeroAI. */
private _wantRoles = if (_mission isEqualTo "RECON") then {["UAV_ARMED", "UAV_RECON"]} else {["UAV_ARMED"]};
private _cool = missionNamespace getVariable ["NeroAI_airSortieCooldownSeconds", 180];
private _fleet = (vehicles select {
    /* damage, not canMove: a parked airframe is deliberately dry (fuel 0). */
    alive _x && {(damage _x) < 0.8} && {canFire _x} && {_x isKindOf "Air"} &&
    {((_x getVariable ["NeroAI_assetRole", ""]) in _wantRoles)} &&
    {([_x] call NeroAI_fnc_getVehicleSide) isEqualTo _side} &&
    {(_x getVariable ["NeroAI_airState", "PARKED"]) isEqualTo "PARKED"} &&
    {(_now - (_x getVariable ["NeroAI_lastSortie", -1e6])) >= _cool} &&
    {(crew _x findIf {alive _x}) >= 0}
});
if (_fleet isEqualTo []) exitWith {[false, "Нет готового борта: все на задании, на перезарядке или потеряны."]};

/* Nearest suitable airframe to the target. */
private _air = _fleet # 0;
{ if ((_x distance2D _aim) < (_air distance2D _aim)) then { _air = _x; }; } forEach _fleet;

private _home = _air getVariable ["NeroAI_homeBase", getPosATL _air];
/* Run-in point: back off from the target along the bearing to our own base, so
 * the approach stays on our side of the line instead of overflying it. */
private _standoff = missionNamespace getVariable ["NeroAI_airStandoffMeters", 1100];
private _bearingHome = _aim getDir _home;
private _approach = _aim getPos [_standoff, _bearingHome];

private _isHeli = _air isKindOf "Helicopter";
private _height = if (_isHeli) then {120} else {450};
private _airGroup = group (effectiveCommander _air);

_air setVariable ["NeroAI_airState", "SORTIE", true];
_air setVariable ["NeroAI_lastSortie", _now, true];
_air setVariable ["NeroAI_sortieTarget", _aim, true];
_group setVariable ["NeroAI_lastAirRequest", _now, true];
{ _x enableAI "MOVE"; _x enableAI "PATH"; _x setBehaviour "AWARE"; } forEach (crew _air);
_air setFuel 1;
_air engineOn true;
_air flyInHeight _height;
if (!isNull _airGroup) then { _airGroup setCombatMode "RED"; _airGroup setBehaviour "AWARE"; };
_air doMove _approach;

private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
["ACTION", format ["%1 авиавылет %2: борт %3, заход с %4 м (азимут %5), цель %6,%7.",
    _callsign, _mission, typeOf _air, _standoff, round _bearingHome, round (_aim # 0), round (_aim # 1)]] call NeroAI_fnc_log;

/* --- Bounded sortie watchdog: strike window, then RTB and go cold. -------- */
[_air, _aim, _approach, _home, _height, _noFly, _sideKey] spawn {
    params ["_air", "_aim", "_approach", "_home", "_height", "_noFly", "_sideKey"];
    private _window = missionNamespace getVariable ["NeroAI_airSortieSeconds", 150];
    private _deadline = diag_tickTime + _window;
    private _onStation = false;
    private _abort = false;

    while {alive _air && {diag_tickTime < _deadline} && {!_abort}} do {
        /* Abort immediately if the airframe drifts into an enemy-base bubble. */
        {
            private _bp = missionNamespace getVariable [format ["NeroAI_basePos_%1", _x], []];
            if (_bp isEqualType [] && {(count _bp) >= 2} && {(_air distance2D _bp) < _noFly}) exitWith { _abort = true; };
        } forEach (["BLUE", "RED"] select {!(_x isEqualTo _sideKey)});

        if (!_onStation && {(_air distance2D _approach) < 350}) then {
            _onStation = true;
            _air doMove _aim;
            { _x doWatch _aim; } forEach (crew _air);
        };
        uiSleep 5;
    };

    if (alive _air) then {
        if (_abort) then {
            ["WARN", format ["Борт %1 отозван: вошёл в запретную зону вражеской базы.", typeOf _air]] call NeroAI_fnc_log;
        };
        _air flyInHeight (_height max 300);
        { _x doWatch objNull; } forEach (crew _air);
        private _g = group (effectiveCommander _air);
        if (!isNull _g) then { _g setCombatMode "GREEN"; _g setBehaviour "CARELESS"; };
        _air doMove _home;

        /* Give it time to get home, then park cold again. */
        private _rtb = diag_tickTime + (missionNamespace getVariable ["NeroAI_airRtbSeconds", 240]);
        waitUntil { uiSleep 5; (!alive _air) || {(_air distance2D _home) < 250} || {diag_tickTime > _rtb} };
        if (alive _air) then {
            _air setVariable ["NeroAI_airState", "PARKED", true];
            _air engineOn false;
            _air setFuel 0;
            { _x disableAI "MOVE"; _x disableAI "PATH"; _x setBehaviour "CARELESS"; } forEach (crew _air);
            ["INFO", format ["Борт %1 вернулся на базу и поставлен в готовность.", typeOf _air]] call NeroAI_fnc_log;
        };
    };
};

[true, format ["Авиация поднята: %1, заход со стороны своих, цель %2 %3.", typeOf _air, round (_aim # 0), round (_aim # 1)]]
