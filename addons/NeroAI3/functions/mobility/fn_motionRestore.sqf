/* Restore only the settings owned by this controller, including after cancel. */
params ["_mover"];
private _restore = _mover getVariable ["NeroWL_motionRestore",[]];
if (_restore isNotEqualTo []) then {
    _restore params ["_driver","_path","_move","_forcedSpeed",["_dangerDisabled",false]];
    if (!isNull _driver && {local _driver} && {!isPlayer _driver}) then {
        _driver setVariable ["lambs_danger_disableAI",_dangerDisabled];
        _driver enableAIFeature ["PATH",_path];_driver enableAIFeature ["MOVE",_move];
    };
    if (local _mover) then {_mover forceSpeed _forcedSpeed;};
};
_mover setVariable ["NeroWL_motionRestore",nil];
true
