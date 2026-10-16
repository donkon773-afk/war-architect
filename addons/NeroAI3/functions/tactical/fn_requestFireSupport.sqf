/* NeroAI 4.4.0 [Command]: indirect fire and CAS marking.
 *
 * 4.3.0 SAFETY: a plan position is a model-supplied grid. It can be stale (the
 * enemy has moved on), and friendlies — including the human player — can be
 * standing on it by the time the rounds land. Before any round is fired we now
 * require:
 *   1. no living friendly inside the danger-close radius (larger for players),
 *   2. a real, currently-known hostile near the aim point (not a stale grid),
 *   3. that grid not to have been shelled in the last cooldown window.
 * Any failure is a refusal, never a "fire anyway". */
params ["_group", "_position", "_supportType"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};
_supportType = toUpper _supportType;
private _friendlySide = side (leader _group);
if !(_supportType in ["ARTILLERY", "MORTAR", "CAS"]) exitWith {[false, "Нераспознанный тип огневой поддержки."]};

private _cooldown = missionNamespace getVariable ["NeroAI_fireSupportCooldownSeconds", 45];
private _now = diag_tickTime;
private _lastFireSupport = _group getVariable ["NeroAI_lastFireSupport", -_cooldown];
if ((_now - _lastFireSupport) < _cooldown) exitWith {[false, "Огневая поддержка для этой группы временно на перезарядке."]};

if (!(_position isEqualType []) || {(count _position) < 2}) exitWith {[false, "Некорректные координаты цели."]};
private _aim = [_position # 0, _position # 1, 0];

/* --- Guard 1: danger close. Never drop rounds on our own people. ---------- */
private _safeR = missionNamespace getVariable ["NeroAI_fireSafetyRadius", 180];
private _playerR = missionNamespace getVariable ["NeroAI_firePlayerSafetyRadius", 250];
private _nearby = _aim nearEntities [["Man", "LandVehicle", "Air", "Ship"], _playerR + 50];
private _blockerIndex = _nearby findIf {
    alive _x && {
        private _s = side _x;
        ((_s isEqualTo _friendlySide) || {(_friendlySide getFriend _s) >= 0.6}) &&
        {(_x distance2D _aim) < (if (isPlayer _x) then {_playerR} else {_safeR})}
    }
};
private _blocker = if (_blockerIndex >= 0) then {_nearby # _blockerIndex} else {objNull};

if (!isNull _blocker) exitWith {
    private _who = if (isPlayer _blocker) then {"игрок"} else {"свои"};
    ["WARN", format ["%1 REQUEST_FIRE(%2) @%3,%4 ОТКЛОНЁН: %5 в %6 м от точки падения.",
        _group getVariable ["NeroAI_callsign", groupId _group], _supportType,
        round (_aim # 0), round (_aim # 1), _who, round (_blocker distance2D _aim)]] call NeroAI_fnc_log;
    _group setVariable ["NeroAI_lastFireDenied", [_now, "DANGER_CLOSE"], true];
    [false, "Отказано: свои войска в опасной близости от точки падения."]
};

/* --- Guard 2: the aim point must still hold a known hostile. -------------- */
private _driftR = missionNamespace getVariable ["NeroAI_fireTargetMaxDriftMeters", 150];
private _candidates = _aim nearEntities [["Man", "LandVehicle", "Air", "Ship", "StaticWeapon"], _driftR];
private _hostileNear = (_candidates findIf {
    alive _x && {(_friendlySide getFriend (side _x)) < 0.6}
}) >= 0;

if (!_hostileNear) exitWith {
    ["WARN", format ["%1 REQUEST_FIRE(%2) @%3,%4 ОТКЛОНЁН: цели в радиусе %5 м нет (устаревшая точка).",
        _group getVariable ["NeroAI_callsign", groupId _group], _supportType,
        round (_aim # 0), round (_aim # 1), _driftR]] call NeroAI_fnc_log;
    _group setVariable ["NeroAI_lastFireDenied", [_now, "NO_TARGET"], true];
    [false, "Отказано: по этим координатам противника уже нет — нужна свежая разведка."]
};

/* --- Guard 3: do not hammer the same grid over and over. ------------------ */
private _gridKey = format ["%1_%2", floor ((_aim # 0) / 100), floor ((_aim # 1) / 100)];
private _gridCooldown = missionNamespace getVariable ["NeroAI_fireGridCooldownSeconds", 90];
private _struck = missionNamespace getVariable ["NeroAI_fireGridLog", createHashMap];
private _lastStrike = _struck getOrDefault [_gridKey, -1e6];
if ((_now - _lastStrike) < _gridCooldown) exitWith {
    ["WARN", format ["%1 REQUEST_FIRE(%2) @%3,%4 ОТКЛОНЁН: квадрат %5 уже обстрелян %6 сек назад.",
        _group getVariable ["NeroAI_callsign", groupId _group], _supportType,
        round (_aim # 0), round (_aim # 1), _gridKey, round (_now - _lastStrike)]] call NeroAI_fnc_log;
    _group setVariable ["NeroAI_lastFireDenied", [_now, "GRID_COOLDOWN"], true];
    [false, "Отказано: по этому квадрату только что работали, ждём результат."]
};

if (_supportType isEqualTo "CAS") exitWith {
    /* 4.3.0: a real, bounded sortie from the base air package when one is ready;
     * otherwise fall back to marking the target for the mission dispatcher. */
    private _sortie = [_group, _aim, "CAS"] call NeroAI_fnc_dispatchAir;
    if (_sortie # 0) exitWith {
        _struck set [_gridKey, _now];
        missionNamespace setVariable ["NeroAI_fireGridLog", _struck];
        _group setVariable ["NeroAI_pendingCAS", [_aim, _now], true];
        _group setVariable ["NeroAI_lastFireSupport", _now, true];
        _sortie
    };

    private _aircraft = vehicles select {
        private _asset = _x;
        private _assetSide = [_asset] call NeroAI_fnc_getVehicleSide;
        alive _asset && {canMove _asset} && {canFire _asset} && {_asset isKindOf "Air"} &&
        {(crew _asset findIf {private _crewman = _x; alive _crewman}) >= 0} &&
        {(_assetSide isEqualTo _friendlySide) || {(_friendlySide getFriend _assetSide) >= 0.6}}
    };
    if (_aircraft isEqualTo []) exitWith {[false, format ["Авиация недоступна: %1", _sortie # 1]]};
    _struck set [_gridKey, _now];
    missionNamespace setVariable ["NeroAI_fireGridLog", _struck];
    _group setVariable ["NeroAI_pendingCAS", [_aim, _now], true];
    _group setVariable ["NeroAI_lastFireSupport", _now, true];
    [true, "CAS отмечен для миссионного диспетчера; NeroAI не отдаёт самолёту прямой огневой приказ."]
};

private _assets = vehicles select {
    private _asset = _x;
    private _assetSide = [_asset] call NeroAI_fnc_getVehicleSide;
    private _classLower = toLower (typeOf _asset);
    private _isMortar = _asset isKindOf "StaticMortar" || {"mortar" in _classLower};
    private _typeMatches = if (_supportType isEqualTo "MORTAR") then {_isMortar} else {!_isMortar};
    alive _asset && {local _asset} && {canFire _asset} && {_typeMatches} &&
    {(crew _asset findIf {private _crewman = _x; alive _crewman}) >= 0} &&
    {(_assetSide isEqualTo _friendlySide) || {(_friendlySide getFriend _assetSide) >= 0.6}} &&
    {!((getArtilleryAmmo [_asset]) isEqualTo [])}
};
private _selected = objNull;
private _magazine = "";
{
    private _asset = _x;
    {
        if (_aim inRangeOfArtillery [[_asset], _x]) exitWith {
            _selected = _asset;
            _magazine = _x;
        };
    } forEach (getArtilleryAmmo [_asset]);
    if (!isNull _selected) exitWith {};
} forEach _assets;

if (isNull _selected) exitWith {
    ["WARN", format ["%1 REQUEST_FIRE(%2) @%3,%4 ОТКЛОНЁН: нет своей артиллерии/миномёта в досягаемости (%5 кандидат(ов) осмотрено).",
        _group getVariable ["NeroAI_callsign", groupId _group], _supportType,
        round (_aim # 0), round (_aim # 1), count _assets]] call NeroAI_fnc_log;
    [false, "Нет союзной артиллерии или миномёта в досягаемости цели."]
};

/* Bounded salvo, logged with the safety decision so the RPT shows why it flew. */
private _rounds = missionNamespace getVariable ["NeroAI_fireRoundsPerMission", 3];
_selected doArtilleryFire [_aim, _magazine, _rounds];
_struck set [_gridKey, _now];
missionNamespace setVariable ["NeroAI_fireGridLog", _struck];
_group setVariable ["NeroAI_lastFireSupport", _now, true];
["ACTION", format ["%1 огонь %2 @%3,%4 (%5, %6 выстр.): свои чисты, цель подтверждена.",
    _group getVariable ["NeroAI_callsign", groupId _group], _supportType,
    round (_aim # 0), round (_aim # 1), typeOf _selected, _rounds]] call NeroAI_fnc_log;
[true, format ["Огневая поддержка назначена: %1.", typeOf _selected]]
