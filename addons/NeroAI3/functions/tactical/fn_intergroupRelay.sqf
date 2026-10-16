/* NeroAI 4.4.0 [Command]
 * Opens one LLM radio dialogue hop from a requesting group to the best-placed
 * friendly NeroAI group after a REQUEST_SUPPORT / SHARE_INTEL / NEGOTIATE.
 * The responder's own reply and actions are produced by the bridge on the
 * INTERGROUP channel; this never chains a second hop (dispatchResponse runs the
 * reply with source "INTERGROUP", which blocks a further relay). */
params ["_requesterGroup", "_kind"];
if (!isServer) exitWith {[false, "Только сервер."]};
if (!(missionNamespace getVariable ["NeroAI_intergroupEnabled", true])) exitWith {[false, "Межгрупповой канал отключён."]};
if (!([_requesterGroup] call NeroAI_fnc_validateGroup)) exitWith {[false, "Группа недоступна."]};

private _now = diag_tickTime;

/* Concurrency: count INTERGROUP requests already in flight. */
private _concurrent = 0;
{ if (((_y isEqualType []) && {count _y >= 3}) && {(_y # 2) isEqualTo "INTERGROUP"}) then {_concurrent = _concurrent + 1;}; } forEach NeroAI_pending;
if (_concurrent >= (missionNamespace getVariable ["NeroAI_intergroupMaxConcurrent", 2])) exitWith {[false, "Межгрупповой канал занят."]};

private _reqLeader = leader _requesterGroup;
private _reqSide = side _reqLeader;
private _reqPos = getPosATL _reqLeader;
private _reqCallsign = _requesterGroup getVariable ["NeroAI_callsign", groupId _requesterGroup];

/* Pick the nearest available same-side active NeroAI group. */
private _responder = grpNull;
private _bestDist = 1e12;
{
    private _cand = _y;
    if (
        _cand != _requesterGroup &&
        {[_cand] call NeroAI_fnc_validateGroup} &&
        {(side _cand) isEqualTo _reqSide} &&
        {(_cand getVariable ["NeroAI_isEnemy", false]) isEqualTo (_requesterGroup getVariable ["NeroAI_isEnemy", false])} &&
        {!(_cand getVariable ["NeroAI_playerHold", false])} &&
        {_now >= (_cand getVariable ["NeroAI_manualOrderUntil", 0])}
    ) then {
        private _d = _reqLeader distance2D (leader _cand);
        if (_d < _bestDist && {_d <= 4000}) then { _bestDist = _d; _responder = _cand; };
    };
} forEach NeroAI_activeGroups;

if (isNull _responder) exitWith {[false, "Нет свободной союзной группы на связи."]};

/* Per-pair cooldown. */
private _pairKey = format ["NeroAI_ig_%1_%2", netId _requesterGroup, netId _responder];
private _pairLast = missionNamespace getVariable [_pairKey, -999];
if ((_now - _pairLast) < (missionNamespace getVariable ["NeroAI_intergroupPairCooldown", 30])) exitWith {[false, "Пара недавно уже обменивалась."]};

private _kindText = switch (_kind) do {
    case "REQUEST_SUPPORT": {"запрашивает подмогу"};
    case "SHARE_INTEL": {"передаёт разведданные"};
    default {"предлагает координацию действий"};
};

/* The requester's own last radio line, if any, is the spoken message. */
private _decision = _requesterGroup getVariable ["NeroAI_lastLlmDecision", []];
private _reqSpeech = if (_decision isEqualType [] && {count _decision >= 2} && {(_decision # 1) isEqualType ""}) then {_decision # 1} else {""};
if (_reqSpeech isEqualTo "") then {
    _reqSpeech = format ["%1 %2, наши координаты %3 %4.", _reqCallsign, _kindText, round (_reqPos # 0), round (_reqPos # 1)];
};

/* Nearest confirmed contact of the requester, for a grounded responder move. */
private _reqIntel = _requesterGroup getVariable ["NeroAI_intel", []];
private _contactPos = [];
if (_reqIntel isEqualType [] && {count _reqIntel > 0} && {(_reqIntel # 0) isEqualType []} && {count ((_reqIntel # 0)) >= 2}) then {
    _contactPos = (_reqIntel # 0) # 1;
};

/* Give the responder a grounded reference to the requester and the threat so an
 * ADVANCE toward them passes the bridge grounded + meaningful filters. */
_responder setVariable ["NeroAI_radioFrom", [_reqCallsign, [round (_reqPos # 0), round (_reqPos # 1)], _contactPos], false];
private _rLog = _responder getVariable ["NeroAI_dialogue", []];
_rLog pushBack [_reqCallsign, _reqSpeech];
private _turns = missionNamespace getVariable ["NeroAI_conversationTurns", 6];
if ((count _rLog) > (_turns * 2)) then { _rLog = _rLog select [(count _rLog) - (_turns * 2), (_turns * 2)]; };
_responder setVariable ["NeroAI_dialogue", _rLog, true];

private _command = format [
    "INTERGROUP от %1: %2. Сообщение: «%3». Позиция запросившего %4 %5. Ближайший контакт запросившего: %6. Ответь по радио и, если можешь, реально помоги (ADVANCE к запросившему или контакту, REQUEST_FIRE, SHARE_INTEL). Один хоп: без нового REQUEST_SUPPORT.",
    _reqCallsign, _kindText, _reqSpeech, round (_reqPos # 0), round (_reqPos # 1),
    if (_contactPos isEqualTo []) then {"нет данных"} else {format ["%1 %2", _contactPos # 0, _contactPos # 1]}
];

private _sent = [[_responder], objNull, "INTERGROUP", _command, "AUTONOMY"] call NeroAI_fnc_sendBridgeRequest;
if (_sent # 0) then {
    missionNamespace setVariable [_pairKey, _now];
    ["INFO", format ["INTERGROUP relay %1 -> %2 (%3).", _reqCallsign, _responder getVariable ["NeroAI_callsign", groupId _responder], _kind]] call NeroAI_fnc_log;
};
_sent
