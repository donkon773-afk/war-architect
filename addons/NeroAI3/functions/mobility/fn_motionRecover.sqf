/* Runs inside the one vehicle route worker. All checks and manoeuvres share
 * one 26 s budget and at most two attempts. Never creates a second driver loop. */
params ["_mover","_group","_epoch","_goal"];
if (!canSuspend || {!local _mover} || {!(_mover isKindOf "LandVehicle")}) exitWith {"BLOCKED"};
private _current = {
    [_group getVariable ["NeroWL_routeEpoch",-1],_epoch,(_mover getVariable ["NeroWL_motionOwner",[]]) isEqualTo [_group,_epoch],local _mover,alive _mover,alive driver _mover,isPlayer driver _mover,group driver _mover isEqualTo _group] call NeroAI_fnc_motionAuthority
};
if (!(call _current)) exitWith {"CANCELLED"};
if (!canMove _mover || {fuel _mover <= 0}) exitWith {"DAMAGED"};
private _until = diag_tickTime + 26;
private _box = 2 boundingBoxReal _mover;
private _width = (((_box # 1) # 0)-((_box # 0) # 0)) max 1;
private _length = (((_box # 1) # 1)-((_box # 0) # 1)) max 3;
if (_width > 12 || {_length > 20}) exitWith {"BLOCKED"};
private _candidates = [getPosATL _mover,getDir _mover,_width,_length] call NeroAI_fnc_motionCandidates;
private _ranked = [];
{
    if (!(call _current) || {diag_tickTime >= _until}) exitWith {};
    _x params ["_name","_points"];
    if ([_mover,_points,_width,_length] call NeroAI_fnc_motionCorridor) then {
        private _last = _points # ((count _points)-1);
        _ranked pushBack [(_last distance2D _goal)+(if (_name isEqualTo "BACK") then {8} else {0}),_name,_points];
    };
    sleep 0.01;
} forEach _candidates;
private _attempts = 0;private _result = "BLOCKED";
while {_ranked isNotEqualTo [] && {_attempts < 2} && {diag_tickTime < _until}} do {
    if (!(call _current)) exitWith {_result = "CANCELLED";};
    private _best = 0;{if ((_x # 0) < ((_ranked # _best) # 0)) then {_best = _forEachIndex;};} forEach _ranked;
    private _pick = _ranked deleteAt _best;private _points = _pick # 2;
    /* Recheck dynamic obstacles immediately before issuing the path. */
    if ([_mover,_points,_width,_length] call NeroAI_fnc_motionCorridor) then {
        _attempts = _attempts+1;
        _mover setVariable ["NeroWL_motionState","RECOVERING",true];
        private _forced = getForcedSpeed _mover;
        private _slow = if (_forced < 0) then {1.8} else {_forced min 1.8};
        _mover forceSpeed _slow;
        doStop driver _mover;
        private _last = _points # ((count _points)-1);
        private _origin = getPosATL _mover;
        private _pathLength = 0;private _previous = _origin;
        {_pathLength = _pathLength+(_previous distance2D _x);_previous = _x;} forEach _points;
        private _deadline = (diag_tickTime+((_pathLength/(_slow max 0.1)+2) max 7)) min _until;
        if (isAISteeringComponentEnabled _mover) then {
            _mover setDriveOnPath (_points apply {_x + [_slow]});
        } else {driver _mover doMove _last;};
        waitUntil {sleep 0.5;!(call _current) || {!canMove _mover} || {_mover distance2D _last < 3} || {diag_tickTime >= _deadline}};
        if (call _current) then {
            doStop driver _mover;
            _mover forceSpeed _forced;
            if (_mover distance2D _last < 3 && {_mover distance2D _origin >= 3}) then {_result = "RECOVERED";};
        } else {_result = "CANCELLED";};
    };
    if (_result != "BLOCKED") exitWith {};
};
if (!canMove _mover || {fuel _mover <= 0}) then {_result = "DAMAGED";};
_mover setVariable ["NeroWL_motionState",_result,true];
["INFO",format ["MOBILITY %1 %2 attempts=%3 result=%4",groupId _group,typeOf _mover,_attempts,_result]] call NeroAI_fnc_log;
_result
