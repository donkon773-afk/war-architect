if (!isServer || {!NeroAI_transportReady}) exitWith {};

private _inbox = ["new", "NeroWL_in"] call OO_INIDBI;
private _keys = ["getKeys", "NeroWL_in"] call _inbox;
if (isNil "_keys" || {!(_keys isEqualType [])}) exitWith {};

{
    private _requestId = _x;
    private _entry = ["read", ["NeroWL_in", _requestId]] call _inbox;
    ["deleteKey", ["NeroWL_in", _requestId]] call _inbox;
    if (_entry isEqualType [] && {count _entry >= 2} && {(_entry # 0) isEqualTo "response"}) then {
        [_entry # 1] call NeroAI_fnc_dispatchResponse;
    } else {
        if (_entry isEqualType [] && {count _entry >= 2} && {(_entry # 0) isEqualTo "vision"}) then {
            /* Commander's-eye visual observation. Never a tactical directive; the
             * snapshot builder only folds it into a player-addressed group. */
            missionNamespace setVariable ["NeroAI_visionLatest", [diag_tickTime, _entry # 1]];
        } else {
            ["WARN", format ["Dropped malformed inbox entry %1.", _requestId]] call NeroAI_fnc_log;
        };
    };
} forEach _keys;

/* Time out requests whose bridge response will never arrive. */
private _expired = [];
{
    private _pending = _y;
    if ((diag_tickTime - (_pending # 3)) > 100) then {
        _expired pushBack [_x, _pending];
    };
} forEach NeroAI_pending;
{
    _x params ["_requestId", "_pending"];
    NeroAI_pending deleteAt _requestId;
    private _outbox = ["new", "NeroWL_out"] call OO_INIDBI;
    ["deleteKey", ["NeroWL_out", _requestId]] call _outbox;
    private _origin = if (count _pending > 4) then {_pending # 4} else {"PLAYER"};
    if (_origin isEqualTo "PLAYER") then {
        {
            _x setVariable ["NeroAI_playerRequestsPending", ((_x getVariable ["NeroAI_playerRequestsPending", 1]) - 1) max 0, false];
        } forEach (_pending # 0);
    };
    private _player = _pending # 1;
    if (_origin isEqualTo "PLAYER" && {!isNull _player}) then {
        ["В эфире помехи: NeroAI не ответил за отведённое время."] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
    };
    ["WARN", format ["Request %1 timed out; origin=%2.", _requestId, _origin]] call NeroAI_fnc_log;
} forEach _expired;
