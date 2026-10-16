/* 11.10 Tactical AI without LLM — PURE force allocation for one side.
 *
 *   [groups, threats, posture] call NeroAI_fnc_rulesAllocate -> [[key, kind, threatIndex], ...]
 *
 * groups  [[key, strength, distances, currentKind, currentThreat, weak], ...]
 *         distances[i] = metres from the group to threats[i]
 * threats [[key, need, maxDist], ...] in priority order (the HQ first);
 *         maxDist < 0 = any distance (the HQ is worth a long march)
 * posture 0 defensive, 1 balanced, 2 offensive
 * kind    "DEFEND" (threatIndex = which sector), "RESERVE" or "ATTACK" (-1).
 *
 * Rules: defenders are the nearest groups, current defenders of the same sector
 * are kept (no churn), the share of the army that may defend depends on the
 * posture, a balanced/defensive army of 4+ keeps one reserve, badly weakened
 * squads regroup even when this leaves no attacking group.
 * Optional row fields: 6 assaultReady, 7 available (player/logistics guard). */
params [["_groups", [], [[]]], ["_threats", [], [[]]], ["_posture", 1, [0]],["_counterattack",false,[false]]];
_posture = (round _posture) max 0 min 2;
private _n = count _groups;
private _out = [];
if (_n isEqualTo 0) exitWith {_out};

private _kinds = [];
private _idx = [];
for "_i" from 0 to (_n - 1) do {
    _kinds pushBack (if ((_groups # _i) param [7,true]) then {""} else {"MANUAL"});
    _idx pushBack -1;
};

private _hqThreat = (_threats findIf {(_x param [2, 0]) < 0}) >= 0;
private _share = if (_hqThreat) then {0.7} else {[0.6, 0.4, 0.25] # _posture};
private _budget = if (_threats isEqualTo []) then {0} else {(ceil (_n * _share)) max 1 min _n};
/* Under siege, reserve a ready infantry group for an eligible lost approach.
 * Manual/repair groups do not count as available defenders. A sole surviving
 * or unready group is never sent on a token counterattack. */
if (_hqThreat && {_counterattack}) then {
    private _available = [];
    {if ((_kinds # _forEachIndex) isEqualTo "" && {(_x param [1,0]) > 0}) then {_available pushBack _forEachIndex;};} forEach _groups;
    if (count _available >= 2) then {
        private _pick = -1;private _score = 1e12;
        {
            private _row = _groups # _x;
            private _ready = _row param [6,(_row param [1,0]) >= 6];
            private _canCounter = _row param [9,_ready];
            if (_ready && {_canCounter} && {!(_row param [5,false])}) then {
                private _value = (_row param [8,1e9]) - ((_row param [1,0]) min 20)*10;
                if (_value < _score) then {_pick = _x;_score = _value;};
            };
        } forEach _available;
        if (_pick >= 0) then {_kinds set [_pick,"ATTACK"];_budget = _budget min ((count _available)-1);};
    };
};

{
    private _ti = _forEachIndex;
    _x params [["_tKey", ""], ["_need", 1], ["_maxDist", 3500]];
    _need = (round _need) max 1;
    private _candidates = [];
    {
        _x params [["_key", ""], ["_strength", 0], ["_dists", []], ["_curKind", ""], ["_curThreat", -1], ["_weak", false]];
        private _d = _dists param [_ti, 1e9];
        if ((_kinds # _forEachIndex) isEqualTo "" && {_strength > 0} && {_maxDist < 0 || {_d <= _maxDist}}) then {
            private _eff = _d;
            if (_curKind isEqualTo "DEFEND" && {_curThreat isEqualTo _ti}) then {_eff = _eff - 800;};
            if (_weak) then {_eff = _eff + 400;};
            _candidates pushBack [_eff, _forEachIndex];
        };
    } forEach _groups;
    /* Nearest first (explicit minimum search: the result must not depend on
     * the engine's sort of mixed arrays). */
    while {_need > 0 && {_budget > 0} && {_candidates isNotEqualTo []}} do {
        private _best = 0;
        { if ((_x # 0) < ((_candidates # _best) # 0)) then {_best = _forEachIndex;}; } forEach _candidates;
        private _gi = (_candidates # _best) # 1;
        _candidates deleteAt _best;
        _kinds set [_gi, "DEFEND"];
        _idx set [_gi, _ti];
        _need = _need - 1;
        _budget = _budget - 1;
    };
} forEach _threats;

/* Reserve / regroup. */
private _free = [];
{ if ((_kinds # _forEachIndex) isEqualTo "") then {_free pushBack _forEachIndex;}; } forEach _groups;
private _weakFree = _free select {
    private _row = _groups # _x;
    (_row param [5,false]) || {!(_row param [6,(_row param [1,0]) >= 6])}
};
{
    _kinds set [_x, "RESERVE"];
    _free = _free - [_x];
} forEach _weakFree;
if (_posture < 2 && {(count _free) >= 4} && {!("RESERVE" in _kinds)}) then {
    private _gi = _free # 0;
    { if (((_groups # _x) param [1, 0]) < ((_groups # _gi) param [1, 0])) then {_gi = _x;}; } forEach _free;
    _kinds set [_gi, "RESERVE"];
};
{
    private _kind = _kinds # _forEachIndex;
    if (_kind isEqualTo "") then {_kind = "ATTACK";};
    _out pushBack [_x param [0, ""], _kind, if (_kind isEqualTo "DEFEND") then {_idx # _forEachIndex} else {-1}];
} forEach _groups;
_out
