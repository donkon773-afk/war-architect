params ["_groups", "_player", "_channel", "_command", ["_origin", "PLAYER"]];
if (missionNamespace getVariable ["NeroAI_rulesMode", false]) exitWith {[false, "Тактический ИИ без LLM: мост и модели в этом запуске не используются."]};
if (!isServer || {!NeroAI_transportReady}) exitWith {[false, "Мост NeroAI недоступен: INIDBI2 не инициализирован."]};
_origin = toUpper _origin;
private _autonomyBudget = missionNamespace getVariable ["NeroAI_maxPendingAutonomy", 3];
if (_origin isEqualTo "AUTONOMY" && {(count NeroAI_pending) >= _autonomyBudget}) exitWith {[false, "Планировщик занят; автономный цикл будет повторён позже."]};
if (_origin isEqualTo "PLAYER" && {(count NeroAI_pending) >= (_autonomyBudget + 2)}) exitWith {[false, "NeroAI уже обрабатывает несколько планов. Дождитесь ближайшего ответа."]};

private _fnc_byteLen = {
    params ["_str"];
    private _b = 0;
    {
        if (_x <= 127) then { _b = _b + 1; } else { _b = _b + (if (_x <= 2047) then {2} else {3}); };
    } forEach (toArray _str);
    _b
};

private _requestId = call NeroAI_fnc_makeRequestId;
private _targetIds = _groups apply {netId _x};
private _snapshot = [_groups, _player, _channel, _command] call NeroAI_fnc_buildSnapshot;
private _snapshotLimit = missionNamespace getVariable ["NeroAI_maxSnapshotBytes", missionNamespace getVariable ["NeroAI_maxSnapshotChars", 7400]];
private _snapBytes = [_snapshot] call _fnc_byteLen;
if (_snapBytes > _snapshotLimit) exitWith {[false, "Тактический снимок превышает лимит транспорта даже после сокращения вторичного контекста."]};

private _wire = ["request", [3, _requestId, _channel, _targetIds, _snapshot, _origin]];
private _wireBytes = [str _wire] call _fnc_byteLen;
private _wireLimit = missionNamespace getVariable ["NeroAI_maxWireBytes", 7900];

/* INIDBI2 hard limit is 8 KB per value: a wire that would not fit is split into
 * one request per group (each with its own, smaller snapshot) rather than lost. */
if (_wireBytes > _wireLimit && {(count _groups) > 1}) exitWith {
    private _sentAny = false;
    { private _r = [[_x], _player, _channel, _command, _origin] call NeroAI_fnc_sendBridgeRequest; if (_r # 0) then { _sentAny = true; }; } forEach _groups;
    ["WARN", format ["Request for %1 groups exceeded the 8K transport limit (%2 bytes) — split into per-group requests.", count _groups, _wireBytes]] call NeroAI_fnc_log;
    [_sentAny, if (_sentAny) then {"Приказ передан в NeroAI (по группам)."} else {"Приказ не передан: транспорт переполнен."}]
};
if (_wireBytes > _wireLimit) exitWith {
    ["WARN", format ["Request %1 dropped: wire size %2 bytes exceeds %3 byte limit.", _requestId, _wireBytes, _wireLimit]] call NeroAI_fnc_log;
    [false, "Тактический снимок превышает лимит транспорта 8 КБ."]
};
private _outbox = ["new", "NeroWL_out"] call OO_INIDBI;
private _writeSuccess = ["write", ["NeroWL_out", _requestId, _wire]] call _outbox;
if (_writeSuccess isEqualType false && {!_writeSuccess}) exitWith {
    ["WARN", format ["IniDBI: write failed for request %1 (%2 bytes) — outbox rejected data.", _requestId, _wireBytes]] call NeroAI_fnc_log;
    [false, "Сбой записи в транспортную очередь INIDBI2."]
};
private _guardTokens = _groups apply {[_x, _x getVariable ["NeroAI_opToken", 0]]};
if (_origin isEqualTo "PLAYER") then {
    {
        _x setVariable ["NeroAI_playerRequestsPending", (_x getVariable ["NeroAI_playerRequestsPending", 0]) + 1, false];
    } forEach _groups;
};
NeroAI_pending set [_requestId, [_groups, _player, _channel, diag_tickTime, _origin, _guardTokens]];
["DEBUG", format ["Outbox request %1 queued for %2 group(s); origin=%3.", _requestId, count _groups, _origin]] call NeroAI_fnc_log;
[true, if (_origin isEqualTo "PLAYER") then {"Приказ передан в NeroAI."} else {"Автономный тактический запрос поставлен в очередь."}]
