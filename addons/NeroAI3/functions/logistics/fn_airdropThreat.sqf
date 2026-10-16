params ["_side","_point",["_from",[]]];
private _enemy = 1e9;private _aa = 1e9;private _corridor = 1e9;
{
    private _p = _x param [1,[]];
    if (count _p >= 2 && {diag_tickTime-(_x param [3,-1e6]) <= 120}) then {
        _enemy = _enemy min (_p distance2D _point);
        if ([_x param [0,""]] call NeroAI_fnc_airdropClassAA) then {
            _aa = _aa min (_p distance2D _point);
            if (count _from >= 2) then {_corridor = _corridor min ([_p,_from,_point] call NeroAI_fnc_motionPointDistance);};
        };
    };
} forEach ((missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str _side,[]]);
[_enemy,_aa,_corridor]
