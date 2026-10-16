params ["_response"];
if (!isServer || {!(_response isEqualType [])} || {count _response < 4}) exitWith {};

private _requestId = _response # 1;
private _speechLimit = missionNamespace getVariable ["NeroAI_maxSpeechChars", 700];
private _speech = [_response # 2, _speechLimit] call NeroAI_fnc_normalizeText;
private _actions = _response # 3;
private _pending = NeroAI_pending get _requestId;
if (isNil "_pending") exitWith {
    ["WARN", format ["Received response for unknown request %1.", _requestId]] call NeroAI_fnc_log;
};
NeroAI_pending deleteAt _requestId;

private _outbox = ["new", "NeroWL_out"] call OO_INIDBI;
["deleteKey", ["NeroWL_out", _requestId]] call _outbox;
private _groups = _pending # 0;
private _player = _pending # 1;
private _channel = _pending # 2;
private _origin = if (count _pending > 4) then {_pending # 4} else {"PLAYER"};
private _guardTokens = if (count _pending > 5) then {_pending # 5} else {[]};
if (_origin isEqualTo "PLAYER") then {
    {
        _x setVariable ["NeroAI_playerRequestsPending", ((_x getVariable ["NeroAI_playerRequestsPending", 1]) - 1) max 0, false];
    } forEach _groups;
};
if ((diag_tickTime - (_pending # 3)) > 95) exitWith {
    ["WARN", format ["Dropped stale response %1.", _requestId]] call NeroAI_fnc_log;
};

_groups = _groups select {[_x] call NeroAI_fnc_validateGroup};
if (_origin isEqualTo "AUTONOMY") then {
    _groups = _groups select {
        private _group = _x;
        private _guardIndex = _guardTokens findIf {(_x # 0) isEqualTo _group};
        private _tokenUnchanged = _guardIndex >= 0 && {(_group getVariable ["NeroAI_opToken", 0]) isEqualTo ((_guardTokens # _guardIndex) # 1)};
        private _playerPending = (_group getVariable ["NeroAI_playerRequestsPending", 0]) > 0;
        private _manualBusy = diag_tickTime < (_group getVariable ["NeroAI_manualOrderUntil", 0]);
        _tokenUnchanged && {!_playerPending} && {!_manualBusy} && {!(_group getVariable ["NeroAI_playerHold", false])}
    };
};
if (_groups isEqualTo []) exitWith {
    private _reason = if (_origin isEqualTo "AUTONOMY") then {
        "autonomous plan superseded by player intent or newer group state"
    } else {
        "no surviving controlled target group"
    };
    ["WARN", format ["Response %1 dropped: %2.", _requestId, _reason]] call NeroAI_fnc_log;
    if (_origin isEqualTo "PLAYER" && {!isNull _player}) then {["Приказ не выполнен: адресованная группа больше недоступна."] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];};
};
if !(_actions isEqualType []) then { _actions = []; };

private _allowedActionTypes = [
    "ADVANCE", "ASSAULT", "HOLD", "RETREAT", "RECON", "REQUEST_FIRE",
    "BOARD", "DISEMBARK", "REPAIR", "SET_ROE", "SET_SECTOR", "REPORT", "CANCEL",
    "REQUEST_SUPPORT", "SHARE_INTEL", "NEGOTIATE", "DESIGNATE", "AUTONOMY", "BUY", "ASSIGN_ROLE", "AIR_TASK"
];

private _validActions = [];
{
    private _act = _x;
    if (_act isEqualType [] && {count _act >= 3}) then {
        private _type = _act # 0;
        private _pos = _act # 1;
        private _arg = _act # 2;
        private _isValid = true;

        if !(_type isEqualType "" && {_pos isEqualType []} && {_arg isEqualType ""}) then {
            _isValid = false;
        } else {
            _type = toUpper _type;
            if !(_type in _allowedActionTypes) then {
                _isValid = false;
            } else {
                if (count _pos > 0 && {!((count _pos in [2, 3]) && {({_x isEqualType 0} count _pos) isEqualTo count _pos})}) then {
                    _isValid = false;
                };
                if (_isValid && {_type isEqualTo "SET_ROE"} && {!((toUpper _arg) in ["HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"])}) then {
                    _isValid = false;
                };
                if (_isValid && {_type isEqualTo "REQUEST_FIRE"} && {!((toUpper _arg) in ["ARTILLERY", "MORTAR", "CAS"])}) then {
                    _isValid = false;
                };
                if (_isValid && {_type == "ASSIGN_ROLE"} && {!(_arg in ["INFANTRY","MECHANIZED","ARMOR","RECON","AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"])}) then {_isValid=false;};
                if (_isValid && {_type == "AIR_TASK"} && {!(_arg in ["CAS","RECON","TRANSPORT","INTERCEPT","ESCORT"])}) then {_isValid=false;};
                if (_isValid && {_type isEqualTo "BUY"} && {!((toUpper _arg) in ["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"])}) then {
                    _isValid = false;
                };
            };
        };

        if (_isValid) then {
            _validActions pushBack [_type, _pos, _arg];
        } else {
            ["WARN", format ["Dropped invalid action from response %1: %2.", _requestId, _act]] call NeroAI_fnc_log;
        };
    } else {
        ["WARN", format ["Dropped malformed action from response %1: %2.", _requestId, _act]] call NeroAI_fnc_log;
    };
} forEach _actions;

_actions = _validActions;
_actions resize ((count _actions) min (missionNamespace getVariable ["NeroAI_maxActions", 5]));

["INFO", format ["Response %1 accepted: %2 action(s) for %3 group(s).", _requestId, count _actions, count _groups]] call NeroAI_fnc_log;

// An INTERGROUP reply executes as its own source: still autonomous for the
// self-move guard and player-priority checks, but it must not spawn a second
// inter-group relay hop.
private _execSource = if (_channel isEqualTo "INTERGROUP") then {"INTERGROUP"} else {_origin};

private _failures = [];
private _successCount = 0;
private _scheduledCount = 0;

{
    private _group = _x;
    _group setVariable ["NeroAI_lastLlmDecision", [diag_tickTime, _speech, +_actions], true];
    private _oldThread = _group getVariable ["NeroAI_planThread", scriptNull];
    if (!isNull _oldThread) then { terminate _oldThread; };

    private _groupActions = +_actions;
    if !(_groupActions isEqualTo []) then {
        private _firstAction = _groupActions # 0;
        private _result = [_group, _firstAction # 0, _firstAction # 1, _firstAction # 2, _execSource] call NeroAI_fnc_executeMacro;
        
        if (_result isEqualType [] && {count _result >= 2} && {_result # 0}) then {
            _successCount = _successCount + 1;
        } else {
            private _reason = if (_result isEqualType [] && {count _result >= 2}) then {_result # 1} else {"движок не подтвердил действие"};
            _failures pushBack format ["%1: %2", _group getVariable ["NeroAI_callsign", groupId _group], _reason];
        };
        
        if (count _groupActions > 1) then {
            _scheduledCount = _scheduledCount + (count _groupActions) - 1;
            private _token = _group getVariable ["NeroAI_opToken", 0];
            private _restActions = +_groupActions;
            _restActions deleteAt 0;
            private _planThread = [_group, _restActions, _token, _execSource] spawn {
                params ["_group", "_actions", "_token", "_execSource"];
                {
                    private _action = _x;
                    private _deadline = diag_tickTime + 360;
                    waitUntil {
                        uiSleep 1;
                        ((!((_group getVariable ["NeroAI_vehicleState", ""]) in ["BOARDING", "PARTIAL_BOARDING"])) &&
                            {diag_tickTime >= (_group getVariable ["NeroAI_purchaseHoldUntil", 0])} &&
                            {diag_tickTime >= (_group getVariable ["NeroWL_logisticsUntil", 0])}) ||
                            {isNull _group} || {(_group getVariable ["NeroAI_opToken", 0]) != _token} || {diag_tickTime >= _deadline}
                    };
                    if (isNull _group || {(_group getVariable ["NeroAI_opToken", 0]) != _token}) exitWith {};
                    if (diag_tickTime >= _deadline) exitWith {
                        ["WARN", format ["%1 deferred plan expired while waiting for logistics.", groupId _group]] call NeroAI_fnc_log;
                    };
                    private _deferredSource = if (_execSource isEqualTo "PLAYER") then {"PLAYER_DEFERRED"} else {_execSource};
                    private _result=[_group, _action # 0, _action # 1, _action # 2, _deferredSource] call NeroAI_fnc_executeMacro;
                    ["INFO",format ["%1 deferred %2: %3",groupId _group,_action # 0,_result]] call NeroAI_fnc_log;
                } forEach _actions;
            };
            _group setVariable ["NeroAI_planThread", _planThread, false];
        };
    };

    /* Anti-loop: count autonomous plans that produced no manoeuvre. A group that
     * keeps re-issuing RECON / SET_SECTOR / SHARE_INTEL / REPORT / REQUEST_FIRE
     * for the same spot backs off its scheduled planning (see fn_tacticalAutonomy). */
    if (_origin isEqualTo "AUTONOMY" && {!(_channel isEqualTo "INTERGROUP")}) then {
        private _maneuvered = (_groupActions findIf {
            (_x isEqualType []) && {(_x # 0) in ["ADVANCE", "ASSAULT", "RETREAT", "BOARD", "DISEMBARK"]}
        }) >= 0;
        private _streak = _group getVariable ["NeroAI_idlePlanStreak", 0];
        _group setVariable ["NeroAI_idlePlanStreak", (if (_maneuvered) then {0} else {_streak + 1}), true];
    };
} forEach _groups;

private _finalSpeech = _speech;
if !(_failures isEqualTo []) then {
    private _reason = _failures # 0;
    _finalSpeech = if (_successCount > 0) then {format ["Приказ выполнен частично. %1", _reason]} else {format ["Не могу выполнить приказ. %1", _reason]};
};

/* Rolling per-group conversation memory: the group's own last line, so the next
 * snapshot lets the model stay consistent with what it just said on the radio. */
private _turns = missionNamespace getVariable ["NeroAI_conversationTurns", 6];
{
    if !(_finalSpeech isEqualTo "") then {
        private _log = _x getVariable ["NeroAI_dialogue", []];
        private _entry = [_x getVariable ["NeroAI_callsign", groupId _x], _finalSpeech];
        private _last = if (_log isEqualTo []) then {[]} else {_log select [(count _log) - 1, 1] # 0};
        if !(_entry isEqualTo _last) then {
            _log pushBack _entry;
            if ((count _log) > (_turns * 2)) then { _log = _log select [(count _log) - (_turns * 2), (_turns * 2)]; };
            _x setVariable ["NeroAI_dialogue", _log, true];
        };
    };
} forEach _groups;

private _canSpeak = true;
if (_origin isEqualTo "AUTONOMY" && {!(_channel isEqualTo "INTERGROUP")}) then {
    private _lastRadio = (_groups # 0) getVariable ["NeroAI_lastAutonomyRadio", -60];
    private _cooldown = missionNamespace getVariable ["NeroAI_autonomyRadioCooldownSeconds", 20];
    _canSpeak = (diag_tickTime - _lastRadio) >= _cooldown;
    if (_canSpeak) then {(_groups # 0) setVariable ["NeroAI_lastAutonomyRadio", diag_tickTime, true];};
};
/* 8.10 radio silence: an AI-to-AI plan without a radio line stays off the air,
 * including the failure note (it is still kept in NeroAI_dialogue above). */
private _silentPlan = (_speech isEqualTo "") && {(_origin isEqualTo "AUTONOMY") || {_channel isEqualTo "INTERGROUP"}};
if (_canSpeak && {!_silentPlan}) then {[_groups, _player, _channel, [_finalSpeech, _speechLimit] call NeroAI_fnc_normalizeText] call NeroAI_fnc_broadcastSpeech;};
if (_channel isEqualTo "INTERGROUP") then { { _x setVariable ["NeroAI_radioFrom", [], true]; } forEach _groups; };
["INFO", format ["Response %1 dispatched: accepted=%2 failed=%3 deferred=%4.", _requestId, _successCount, count _failures, _scheduledCount]] call NeroAI_fnc_log;
