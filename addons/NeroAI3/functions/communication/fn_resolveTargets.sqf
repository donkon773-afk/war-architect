/*
 * NeroAI uses the faction chat channel as its one radio command surface.
 * "все" addresses every active friendly group; otherwise the message should
 * name a NeroAI callsign. Engine groupId and leader names are deliberately not
 * aliases: they can be duplicated or change with scenario state.
 *
 * 4.4.0: a callsign with a typo ("Алфа 12", "альфа12", "Альфа-12й") still
 * routes when it is unambiguous — the word part must be within a small edit
 * distance of exactly one prefix in use and the number must match exactly.
 * When nothing routes, the CALLER asks on the radio who the order is for
 * (fn_receiveClientCommand); this function only ever returns groups it is
 * sure about, never a guess between two.
 */
params ["_player", "_mode", "_command"];
private _friendlyActive = allGroups select {
    [_x] call NeroAI_fnc_validateGroup && {_x getVariable ["NeroAI_active", false]} && {side _x isEqualTo side group _player}
};
if !(_mode isEqualTo "SIDE") exitWith {[]};

private _needle = toLower _command;
private _allTokens = (_needle splitString " ,.;:!?()[]{}") apply {toLower _x};
if (({"все" isEqualTo _x || {"всем" isEqualTo _x} || {"all" isEqualTo _x}} count _allTokens) > 0) exitWith {
    _friendlyActive
};

private _containsCompleteCallsign = {
    params ["_callsign", "_message"];
    if (_callsign isEqualTo "") exitWith {false};
    private _index = _message find _callsign;
    if (_index < 0) exitWith {false};
    /* Prevent "Альфа 1-1" from matching "Альфа 1-10". */
    private _endIndex = _index + count _callsign;
    if (_endIndex >= count _message) exitWith {true};
    private _nextCode = (toArray _message) # _endIndex;
    !(_nextCode in [45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57])
};

private _matches = _friendlyActive select {
    private _callsign = toLower (_x getVariable ["NeroAI_callsign", ""]);
    [_callsign, _needle] call _containsCompleteCallsign
};
if ((count _matches) isEqualTo 1) exitWith {_matches};
if ((count _matches) > 1) exitWith {
    private _best = _matches # 0;
    { if ((_x getVariable ["NeroAI_enrolledAt", 0]) > (_best getVariable ["NeroAI_enrolledAt", 0])) then {_best = _x;}; } forEach _matches;
    ["DEBUG", format ["Callsign matched %1 groups; routed to the freshest enrolment.", count _matches]] call NeroAI_fnc_log;
    [_best]
};

/* --- Fuzzy pass ---------------------------------------------------------- */
private _fnc_editDistance = {
    params ["_a", "_b"];
    private _ca = toArray _a; private _cb = toArray _b;
    private _n = count _ca; private _m = count _cb;
    if (_n isEqualTo 0) exitWith {_m};
    if (_m isEqualTo 0) exitWith {_n};
    private _prev = []; for "_j" from 0 to _m do { _prev pushBack _j; };
    for "_i" from 1 to _n do {
        private _cur = [_i];
        for "_j" from 1 to _m do {
            private _cost = if ((_ca # (_i - 1)) isEqualTo (_cb # (_j - 1))) then {0} else {1};
            _cur pushBack ((( (_prev # _j) + 1) min ((_cur # (_j - 1)) + 1)) min ((_prev # (_j - 1)) + _cost));
        };
        _prev = _cur;
    };
    _prev # _m
};
private _fnc_digits = {
    params ["_s"];
    private _out = "";
    { if (_x >= 48 && {_x <= 57}) then { _out = _out + toString [_x]; }; } forEach (toArray _s);
    _out
};
private _fnc_letters = {
    params ["_s"];
    private _out = "";
    { if (!(_x >= 48 && {_x <= 57}) && {_x != 45}) then { _out = _out + toString [_x]; }; } forEach (toArray _s);
    _out
};

/* Message tokens as (letters, digits) pairs, joining "алфа 12" into one candidate. */
private _cands = [];
{
    private _tok = _x;
    if !(_tok isEqualTo "") then {
        private _l = [_tok] call _fnc_letters;
        private _d = [_tok] call _fnc_digits;
        if !(_d isEqualTo "") then {
            if (_l isEqualTo "" && {(count _cands) > 0} && {((_cands # ((count _cands) - 1)) # 1) isEqualTo ""}) then {
                /* "алфа" then "12": attach the number to the previous word */
                (_cands # ((count _cands) - 1)) set [1, _d];
            } else {
                _cands pushBack [_l, _d];
            };
        } else {
            _cands pushBack [_l, ""];
        };
    };
} forEach _allTokens;

private _fuzzy = [];
{
    private _grp = _x;
    private _cs = toLower (_grp getVariable ["NeroAI_callsign", ""]);
    private _csL = [_cs] call _fnc_letters;
    private _csD = [_cs] call _fnc_digits;
    if (!(_csD isEqualTo "") && {(_cands findIf {
        (_x # 1) isEqualTo _csD && {([(_x # 0), _csL] call _fnc_editDistance) <= 2}
    }) >= 0}) then { _fuzzy pushBack _grp; };
} forEach _friendlyActive;

if ((count _fuzzy) isEqualTo 1) exitWith {
    ["INFO", format ["Callsign fuzzy-matched to %1 from '%2'.", (_fuzzy # 0) getVariable ["NeroAI_callsign", ""], _command]] call NeroAI_fnc_log;
    _fuzzy
};
[]
