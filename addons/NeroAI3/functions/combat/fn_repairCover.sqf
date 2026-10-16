params ["_group","_vehicle"];
private _covered = false;
{
    private _support = _y getVariable ["NeroAI_supporting",[]];
    if (_y != _group && {[_y] call NeroAI_fnc_validateGroup} && {(side _y) isEqualTo side _group}
        && {count _support >= 3} && {(_support # 0) isEqualTo netId _group} && {diag_tickTime-(_support # 2) < 180}
        && {(_support param [3,""]) != "REPAIR"} && {(leader _y) distance2D _vehicle < 250}
        && {([_y] call NeroAI_fnc_rulesCombatFacts) # 2}) exitWith {_covered = true;};
} forEach NeroAI_activeGroups;
_covered
