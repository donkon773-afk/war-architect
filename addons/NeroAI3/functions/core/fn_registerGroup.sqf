params ["_player", "_group", ["_isEnemyParam", false]];
if (!isServer || {isNull _group}) exitWith {[false, "Сервер не принял выбор группы."]};

if (!isNull _player && {!_isEnemyParam} && {side _group != side group _player}) exitWith {
    ["WARN", format ["Player %1 attempted cross-side registerGroup on group %2 (player side %3 vs group side %4).", getPlayerUID _player, groupId _group, side group _player, side _group]] call NeroAI_fnc_log;
    [false, "Группа другой стороны."]
};

if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {[false, "Ботами командует штатный ИИ Arma — NeroAI выключен в настройках запуска."]};

private _isEnemy = _isEnemyParam || (isNull _player) || (!isNull _player && {side _group != side group _player});

if (!_isEnemy && {!(missionNamespace getVariable ["NeroAI_friendlyLLMEnabled",true])}) exitWith {[false,"Подключение союзников к LLM выключено в параметрах миссии."]};
if (!_isEnemy) then {
    if (!isPlayer _player || {isPlayer leader _group} || {({isPlayer _x} count units _group) > 0}) exitWith {
        [false, "NeroAI принимает только полностью ИИ-управляемую дружественную группу без игроков в составе."]
    };
};

if (!local (leader _group)) exitWith {
    [false, "Группа принадлежит Headless Client. NeroAI принимает только серверные ИИ-группы."]
};

if (!([_group, false] call NeroAI_fnc_validateGroup)) exitWith {
    [false, "У выбранной группы нет живого командира."]
};
/* 4.5.1: every enrolment path — menu toggle included — refuses aircraft crews. */
if (!(_group getVariable ["NeroAI_active", false]) && {[_group] call NeroAI_fnc_isAirCrewGroup}) exitWith {
    [false, format ["Группа %1 — экипаж БПЛА/авиации: NeroAI не берёт её под управление.", groupId _group]]
};

private _isActive = _group getVariable ["NeroAI_active", false];
if (_isActive) exitWith {
    _group setVariable ["NeroAI_active", false, true];
    /* A manual switch-off is sticky: fn_manageFriendlyAI will not re-enroll
     * this group until a player toggles it back on. */
    _group setVariable ["NeroAI_optOut", true, true];
    NeroAI_activeGroups deleteAt (netId _group);
    private _msg = format ["NeroAI снят с управления группой %1.", groupId _group];
    [true, _msg]
};

/* Drop stale entries (groups wiped by the scenario) so they neither hold a
 * callsign nor pad the count used for a new one. */
{
    if (!([_y, false] call NeroAI_fnc_validateGroup)) then { NeroAI_activeGroups deleteAt _x; };
} forEach (+NeroAI_activeGroups);

private _grpSide = side _group;
private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
if (_callsign isEqualTo "" || {_callsign isEqualTo (groupId _group)}) then {
    private _prefix = [_grpSide] call NeroAI_fnc_callsignPrefix;
    /* Monotonic sequence, then bump past any callsign still held by a live group. */
    private _taken = [];
    { _taken pushBack (_y getVariable ["NeroAI_callsign", ""]); } forEach NeroAI_activeGroups;
    _callsign = "";
    while {_callsign isEqualTo "" || {_callsign in _taken}} do {
        NeroAI_callsignSeq = NeroAI_callsignSeq + 1;
        _callsign = _prefix + str NeroAI_callsignSeq;
    };
};

_group setVariable ["NeroAI_callsign", _callsign, true];
_group setGroupIdGlobal [_callsign];
_group setVariable ["NeroAI_active", true, true];
/* Only waypoints recorded by our native adapter belong to this handoff. */
private _nativeWaypoints = _group getVariable ["NeroWL_nativeWaypoints",[]];
private _nativeIndices = _nativeWaypoints select {(_x # 0) isEqualTo _group};
_nativeIndices = _nativeIndices apply {_x # 1};_nativeIndices sort false;
{if (_x > 0 && {_x < count waypoints _group}) then {deleteWaypoint [_group,_x];};} forEach _nativeIndices;
_group setVariable ["NeroWL_nativeWaypoints",[]];
_group setVariable ["NeroAI_optOut", false, true];
_group setVariable ["NeroAI_isEnemy", _isEnemy, true];
_group setVariable ["NeroAI_factionSide", _grpSide, true];
_group setVariable ["NeroAI_enrolledAt", diag_tickTime, true];
_group setVariable ["NeroAI_controllerUid", if (isNull _player) then {"SERVER"} else {getPlayerUID _player}, true];
_group setVariable ["NeroAI_controlMode", "VANILLA_AUTONOMOUS", true];
_group setVariable ["NeroAI_initialStrength", {alive _x} count units _group, true];
_group setVariable ["NeroAI_lastKnownStrength", {alive _x} count units _group, true];
_group setVariable ["NeroAI_forcePlan", true, true];

NeroAI_activeGroups set [netId _group, _group];
{ [_x] call NeroAI_fnc_installUnitWatchers; } forEach (units _group);

["INFO", format ["Group %1 (%2, isEnemy=%3) enrolled into NeroAI.", _callsign, _grpSide, _isEnemy]] call NeroAI_fnc_log;
[true, format ["NeroAI подключил группу %1 (%2).", _callsign, _grpSide]]
