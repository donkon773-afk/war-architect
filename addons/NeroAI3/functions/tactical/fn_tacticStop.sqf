/* 8.10: end a behaviour template before any new order. LAMBS hunt/rush/creep
 * loops run until the group dies and re-issue "group move" every cycle, and a
 * soft lambs_wp_fnc_taskReset does not stop them — so the spawned task and our
 * watcher are terminated here, then the soft reset (same group object, no new
 * group) clears garrison/defend animations and LAMBS group variables. */
params ["_group"];
if (!isServer || {isNull _group}) exitWith {false};
private _state = _group getVariable ["NeroWL_tactic", []];
{
    private _h = _group getVariable [_x, scriptNull];
    if (!isNull _h && {!scriptDone _h}) then {terminate _h;};
    _group setVariable [_x, nil];
} forEach ["NeroWL_tacticWatcher", "NeroWL_tacticTask"];
_group setVariable ["NeroWL_tactic", nil];
if ((_state param [3, ""]) isEqualTo "EXEC" && {!isNil "lambs_wp_fnc_taskReset"}) then {
    [_group, true, false] call lambs_wp_fnc_taskReset;
};
// Restore the original mission flags, including AUTOCOMBAT and enableAttack,
// which LAMBS taskReset does not restore. Only units still owned by this group.
private _restore = _group getVariable ["NeroWL_tacticRestore",[]];
if (_restore isNotEqualTo []) then {
    _group enableAttack (_restore # 0);
    {
        _x params ["_unit","_flags","_dangerDisabled"];
        if (!isNull _unit && {local _unit} && {!isPlayer _unit} && {group _unit isEqualTo _group}) then {
            {_unit enableAIFeature _x;} forEach _flags;
            _unit setVariable ["lambs_danger_disableAI",_dangerDisabled];
        };
    } forEach (_restore # 1);
};
_group setVariable ["NeroWL_tacticRestore",nil];
_state isNotEqualTo []
