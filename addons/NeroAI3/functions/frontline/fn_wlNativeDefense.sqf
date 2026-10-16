/* NeroAI owns its enrolled groups; native commanders use a bounded HQ split. */
params ["_unit","_base"];
private _group = group _unit;
if (_group getVariable ["NeroAI_active",false] || {isPlayer _unit}) exitWith {false};
if (!(_base in [missionNamespace getVariable ["BIS_WL_currentSector_WEST",objNull],missionNamespace getVariable ["BIS_WL_currentSector_EAST",objNull]])) exitWith {false};
private _side = side _group;
private _cacheKey = format ["NeroWL_nativeHQSplit_%1",_side];
private _cache = missionNamespace getVariable [_cacheKey,[-1e6,[]]];
if (diag_tickTime-(_cache # 0) >= 2) then {
    private _counter = [_side] call NeroAI_fnc_wlCounterTarget;
    private _groups = [];
    {
        private _g = group _x;
        if (alive _x && {!isPlayer _x} && {side _g isEqualTo _side} && {!(_g getVariable ["NeroAI_active",false])} && {!([_g] call NeroAI_fnc_isAirCrewGroup)}
            && {((units _g) findIf {isPlayer _x}) < 0}) then {_groups pushBackUnique _g;};
    } forEach (missionNamespace getVariable ["BIS_WL_allWarlords",[]]);
    private _rows = _groups apply {
        private _facts = [_x] call NeroAI_fnc_rulesCombatFacts;
        private _defending = (netId _x) in (_cache # 1);
        [netId _x,if (_facts # 3) then {_facts # 9} else {_facts # 0},[(leader _x) distance2D _base],if (_defending) then {"DEFEND"} else {""},if (_defending) then {0} else {-1},!(_facts # 2),_facts # 2,
            !(_x getVariable ["NeroAI_playerHold",false]) && {diag_tickTime >= (_x getVariable ["NeroAI_manualOrderUntil",0])},
            if (isNull _counter) then {1e9} else {(leader _x) distance2D _counter},(_facts # 2) && {!(_facts # 3)}]
    };
    private _plan = [_rows,[[netId _base,(ceil (count _groups*0.6)) max 1,-1]],1,!isNull _counter] call NeroAI_fnc_rulesAllocate;
    /* Exhausted reserves hold the rear; only actual ATTACK assignments go to
     * the counter target. "Not a defender" must never mean "ready to attack". */
    _cache = [diag_tickTime,(_plan select {(_x # 1) in ["DEFEND","RESERVE"]}) apply {_x # 0}];
    missionNamespace setVariable [format ["NeroWL_nativeHQCounter_%1",_side],(_plan select {(_x # 1) isEqualTo "ATTACK"}) apply {_x # 0}];
    missionNamespace setVariable [_cacheKey,_cache];
};
(netId _group) in (_cache # 1)
