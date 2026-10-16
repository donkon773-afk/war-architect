params ["_player", "_mode", ["_payload", ""], ["_extra", ""]];
if (!isServer || {isNull _player} || {!isPlayer _player}) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner != 0} && {remoteExecutedOwner != owner _player}) exitWith {
    ["Запрос NeroAI отклонён: неверный владелец клиента."] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
};

private _uid = getPlayerUID _player;
if (_uid isEqualTo "") then { _uid = str (owner _player); };

if (isNil "NeroAI_clientRateLimits") then {
    NeroAI_clientRateLimits = createHashMap;
};

private _rateRecord = NeroAI_clientRateLimits getOrDefault [_uid, [-60, [], []]];
private _now = diag_tickTime;

/* The two-element menu payload or TOGGLE mode is the path which toggles control. */
if (_mode isEqualTo "TOGGLE" || {_mode isEqualType grpNull} || {_payload isEqualType grpNull}) exitWith {
    private _toggleHistory = (_rateRecord # 2) select {_now - _x < 60};
    if (count _toggleHistory >= 10) exitWith {
        private _earliest = _toggleHistory # 0;
        private _waitTime = ceil (60 - (_now - _earliest)) max 1;
        ["WARN", format ["Rate limit exceeded for UID %1 (TOGGLE count=%2 in 60s).", _uid, count _toggleHistory]] call NeroAI_fnc_log;
        [format ["Слишком частое переключение: подождите %1 с.", _waitTime]] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
    };
    _toggleHistory pushBack _now;
    _rateRecord set [2, _toggleHistory];
    NeroAI_clientRateLimits set [_uid, _rateRecord];

    private _targetGroup = if (_payload isEqualType grpNull) then {_payload} else {_mode};
    if !(_targetGroup isEqualType grpNull) exitWith {};
    private _result = [_player, _targetGroup] call NeroAI_fnc_registerGroup;
    [_result # 1] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
};

if !(_mode isEqualTo "SIDE") exitWith {};
if (missionNamespace getVariable ["NeroAI_rulesMode", false]) exitWith {
    ["Тактический ИИ без LLM: текстовые приказы не разбираются. Меню NeroAI подключает и отключает отряды; цель выбирается голосованием Warlords."] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
};

private _command = [_payload, missionNamespace getVariable ["NeroAI_maxPlayerCommandChars", 400]] call NeroAI_fnc_normalizeText;
if (_command isEqualTo "") exitWith {};
private _groups = [_player, _mode, _command] call NeroAI_fnc_resolveTargets;
if (_groups isEqualTo []) exitWith {
    private _available = (allGroups select {
        [_x] call NeroAI_fnc_validateGroup &&
        {_x getVariable ["NeroAI_active", false]} &&
        {side _x isEqualTo side group _player}
    }) apply {_x getVariable ["NeroAI_callsign", groupId _x]};
    ["DEBUG", format ["Command mode=%1 resolved 0 groups; chars=%2; available=%3.", _mode, count _command, _available joinString " | "]] call NeroAI_fnc_log;
    /* 4.4.0: no addressee (or an unrecognisable one) — the two nearest groups
     * ask on the radio instead of a silent UI hint, in character. */
    private _nearest = (allGroups select {
        [_x] call NeroAI_fnc_validateGroup && {_x getVariable ["NeroAI_active", false]} && {side _x isEqualTo side group _player}
    }) apply { [(leader _x) distance _player, _x] };
    _nearest sort true;
    _nearest resize ((count _nearest) min 2);
    {
        private _g = _x # 1;
        private _cs = _g getVariable ["NeroAI_callsign", groupId _g];
        private _line = selectRandom [
            format ["%1 на связи. Кому приказ? Не разобрал позывной — повтори.", _cs],
            format ["%1: это нам? Назови позывной, приём.", _cs],
            format ["%1 слушает. Уточни, кому — или скажи «все».", _cs]
        ];
        [[_g], _player, "SIDE", _line] call NeroAI_fnc_broadcastSpeech;
    } forEach _nearest;
    if (_nearest isEqualTo []) then {
        ["В канале фракции укажите позывной активной группы или напишите «все»."] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
    };
};

["DEBUG", format ["Command mode=%1 resolved %2 group(s); chars=%3.", _mode, count _groups, count _command]] call NeroAI_fnc_log;
/* 4.5.1 T25 F3 (curator review): the limiter counts only orders that resolved to a
 * group — unaddressed faction chat and the "кому приказ?" round-trip cost nothing.
 * 3 s between resolved orders, 10 resolved orders per minute per UID. */
private _lastSideCmd = _rateRecord # 0;
if ((_now - _lastSideCmd) < 3) exitWith {
    private _waitTime = ceil (3 - (_now - _lastSideCmd)) max 1;
    ["WARN", format ["Rate limit exceeded for UID %1 (interval < 3s, dt=%2s).", _uid, round (_now - _lastSideCmd)]] call NeroAI_fnc_log;
    [format ["Подождите %1 с перед следующим приказом.", _waitTime]] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
};

private _sideHistory = (_rateRecord # 1) select {_now - _x < 60};
if (count _sideHistory >= 10) exitWith {
    private _earliest = _sideHistory # 0;
    private _waitTime = ceil (60 - (_now - _earliest)) max 1;
    ["WARN", format ["Rate limit exceeded for UID %1 (SIDE count=%2 in 60s).", _uid, count _sideHistory]] call NeroAI_fnc_log;
    [format ["Подождите %1 с перед следующим приказом.", _waitTime]] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
};

_sideHistory pushBack _now;
_rateRecord set [0, _now];
_rateRecord set [1, _sideHistory];
NeroAI_clientRateLimits set [_uid, _rateRecord];


/* Rolling conversation memory: record the player's line for every addressed
 * group so the model can answer questions and hold a conversation in context. */
private _turns = missionNamespace getVariable ["NeroAI_conversationTurns", 6];
{
    private _log = _x getVariable ["NeroAI_dialogue", []];
    _log pushBack ["player", _command];
    if ((count _log) > (_turns * 2)) then { _log = _log select [(count _log) - (_turns * 2), (_turns * 2)]; };
    _x setVariable ["NeroAI_dialogue", _log, true];
} forEach _groups;

private _result = [_groups, _player, _mode, _command] call NeroAI_fnc_sendBridgeRequest;
[_result # 1] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
