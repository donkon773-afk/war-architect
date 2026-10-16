/* Road-first march for one land vehicle, or for a squad on foot (the mover is
 * then the leading pedestrian and the other pedestrians follow him).
 *   Out of contact: the engine road planner (calculatePath, SAFE) gives a road
 *   route, bridges included; the mover drives it checkpoint by checkpoint. Only
 *   the last <= 350 m from the road to the objective is driven cross-country.
 *   In contact (known enemy within 700 m or COMBAT behaviour): short flat
 *   corridors straight at the objective, cross-country allowed.
 * Live 7.10: the old corridor-only planner drove BMDs into trees and treated
 * every sample over water as impassable, so bridges near the bases blocked
 * whole columns. No teleport, no map-wide search, no per-frame work. */
params ["_mover","_group","_target",["_followers",[]]];
private _onFoot = _mover isKindOf "CAManBase";
if (!local _mover || {!alive _mover}) exitWith {false};
if (!_onFoot && {!(_mover isKindOf "LandVehicle") || {_mover isKindOf "StaticWeapon"} || {isPlayer driver _mover}}) exitWith {false};
if (_onFoot && {isPlayer _mover}) exitWith {false};
if (!_onFoot && {!isNull attachedTo _mover}) exitWith {false};
if (!_onFoot && {isNull driver _mover || {group driver _mover != _group}}) exitWith {false};
private _owner = _mover getVariable ["NeroWL_motionOwner",[]];
if (count _owner >= 2 && {(_owner # 0) != _group} && {!scriptDone (_mover getVariable ["NeroWL_routeScript",scriptNull])}) exitWith {false};
private _blocked = _mover getVariable ["NeroWL_motionBlocked",[[],0,-1]];
if (diag_tickTime < (_blocked # 1) && {(_blocked # 0) distance2D _target < 60} && {(_blocked param [2,-1]) == (_group getVariable ["NeroAI_opToken",0])}) exitWith {false};
_target = [_target # 0, _target # 1, 0];
// The native autonomy reissues the same objective every 120 s: keep a live route.
private _old = _mover getVariable ["NeroWL_routeScript",scriptNull];
private _oldTarget = _mover getVariable ["NeroWL_routeTarget",[]];
if (!scriptDone _old && {count _oldTarget >= 2} && {(_oldTarget distance2D _target) < 60} && {(_mover getVariable ["NeroWL_routeEpoch",-1]) == (_group getVariable ["NeroWL_routeEpoch",0])}) exitWith {true};
if (!scriptDone _old) then {terminate _old;};
[_mover] call NeroAI_fnc_motionRestore;
private _epoch = _group getVariable ["NeroWL_routeEpoch",0];
private _movers = (_group getVariable ["NeroWL_routeMovers",[]]) select {!isNull _x};
if (_movers isEqualTo []) then {_group setVariable ["NeroWL_routeDangerBefore",[_group getVariable ["lambs_danger_disableGroupAI",false]]];};
_movers pushBackUnique _mover;
_group setVariable ["NeroWL_routeMovers",_movers];
_mover setVariable ["NeroWL_routeTarget",+_target];
_mover setVariable ["NeroWL_routeEpoch",_epoch];
_mover setVariable ["NeroWL_motionOwner",[_group,_epoch]];
private _routeDriver = if (_onFoot) then {_mover} else {driver _mover};
_mover setVariable ["NeroWL_motionRestore",[_routeDriver,_routeDriver checkAIFeature "PATH",_routeDriver checkAIFeature "MOVE",getForcedSpeed _mover,_routeDriver getVariable ["lambs_danger_disableAI",false]]];
_routeDriver setVariable ["lambs_danger_disableAI",true];
private _handle = [_mover,_group,+_target,_epoch,_onFoot,_followers] spawn {
    params ["_mover","_group","_target","_epoch","_onFoot","_followers"];
    private _driverOf = {if (_onFoot) then {_mover} else {driver _mover}};
    private _alive = {alive _mover && {alive (call _driverOf)} && {local _mover} && {!isPlayer (call _driverOf)} && {_onFoot || {canMove _mover}}};
    private _current = {
        private _d = call _driverOf;
        [_group getVariable ["NeroWL_routeEpoch",0],_epoch,(_mover getVariable ["NeroWL_motionOwner",[]]) isEqualTo [_group,_epoch],local _mover,alive _mover,alive _d,isPlayer _d,group _d isEqualTo _group] call NeroAI_fnc_motionAuthority
    };
    private _recoveries = 0;private _blockedRoads = [];
    /* A real firefight only: an enemy seen within 400 m in the last 20 s, or a
     * loss in the last 30 s. Live 7.10 the old test (COMBAT behaviour, which
     * the AI and ASSAULT keep for minutes, or any remembered enemy within
     * 700 m) sent whole columns cross-country for kilometres into the hills. */
    private _inContact = {
        private _l = leader _group;
        (((_l targets [true, 400, [], 20]) select {alive _x}) isNotEqualTo []) ||
        {(diag_tickTime - (_group getVariable ["NeroAI_lastLossReport", -1e6])) < 30}
    };
    private _go = {
        params ["_pos"];
        if !(call _current) exitWith {};
        private _d = call _driverOf;
        _d enableAI "PATH"; _d enableAI "MOVE";
        _d doMove _pos;
        {if (alive _x && {vehicle _x isEqualTo _x}) then {_x doFollow _mover;};} forEach (_followers - [_mover]);
    };
    /* Drive to one point; returns "REACHED" | "STALLED" | "CONTACT" | "CANCELLED" | "LOST". */
    private _driveTo = {
        params ["_pos",["_radius",30],["_watchContact",true]];
        [_pos] call _go;
        private _deadline = diag_tickTime + (90 max ((_mover distance2D _pos) / 3));
        private _anchor = getPosATL _mover;
        private _lastProgress = diag_tickTime;
        private _bestRemaining = _mover distance2D _pos;
        private _queueUntil = -1;
        private _outcome = "";
        waitUntil {
            sleep (if (_onFoot) then {4} else {1});
            if (_onFoot && {_mover distance2D _anchor > 8}) then {_anchor = getPosATL _mover; _lastProgress = diag_tickTime;};
            private _mobility = "MOVING";
            if (!_onFoot) then {
                private _queued = false;
                private _front = (nearestObjects [_mover,["LandVehicle"],18]) select {
                    _x != _mover && {((side _group) getFriend (side group driver _x)) >= 0.6} && {abs speed _x < 4} && {alive _x} && {!isNull driver _x}
                    && {abs (((_mover getDir _x)-getDir _mover+540) mod 360-180) < 30}
                };
                if (_front isNotEqualTo []) then {
                    if (_queueUntil < 0) then {_queueUntil = diag_tickTime+10;};
                    private _other = _front # 0;
                    private _opposing = abs ((getDir _other-getDir _mover+540) mod 360-180) > 120;
                    private _ids = [netId _mover,netId _other];_ids sort true;
                    /* Only the stable lower-priority participant attempts to yield. */
                    _queued = diag_tickTime < _queueUntil || {_opposing && {(_ids # 0) isEqualTo netId _mover}};
                    if (_opposing && {diag_tickTime > _queueUntil+26}) then {_queued = false;};
                } else {_queueUntil = -1;};
                private _progress = [_mover distance2D _pos,_bestRemaining,_lastProgress,diag_tickTime,getForcedSpeed _mover != 0,canMove _mover && {fuel _mover > 0},_queued,speed _mover,8] call NeroAI_fnc_motionProgress;
                _mobility = _progress # 0;_bestRemaining = _progress # 1;_lastProgress = _progress # 2;
                _mover setVariable ["NeroWL_motionState",_mobility,true];
            };
            _outcome = switch (true) do {
                case (!(call _current)): {"CANCELLED"};
                case (!_onFoot && {alive _mover} && {!canMove _mover || {fuel _mover <= 0}}): {"DAMAGED"};
                case (!(call _alive)): {"LOST"};
                case (_mover distance2D _pos < _radius): {"REACHED"};
                case (_watchContact && {call _inContact}): {"CONTACT"};
                case (_mobility isEqualTo "HOLD"): {"HELD"};
                case (_mobility isEqualTo "STALLED" || {_onFoot && {diag_tickTime - _lastProgress > 35}} || {diag_tickTime > _deadline}): {"STALLED"};
                default {""};
            };
            _outcome != ""
        };
        _outcome
    };
    /* One recovery episode per route: two local attempts, shared 26 s cap. */
    private _unstick = {
        if (_onFoot || {_recoveries >= 1}) exitWith {"BLOCKED"};
        _recoveries = _recoveries+1;
        [_mover,_group,_epoch,_target] call NeroAI_fnc_motionRecover
    };
    private _markBlocked = {
        private _roads = (getPosATL _mover) nearRoads 25;
        if (_roads isNotEqualTo []) then {private _best = _roads # 0;{if (_x distance2D _mover < _best distance2D _mover) then {_best = _x;};} forEach _roads;_blockedRoads pushBackUnique _best;};
    };
    private _roadPath = {
        params ["_from"];
        private _type = if (_onFoot) then {"car"} else {if (_mover isKindOf "Tank" || {_mover isKindOf "Tracked_APC_F"}) then {"tank"} else {"wheeled_APC"}};
        private _roads = _target nearRoads 350;
        private _end = +_target;
        if (_roads isNotEqualTo []) then {
            private _best = _roads # 0;
            {if ((_x distance2D _target) < (_best distance2D _target)) then {_best = _x;};} forEach _roads;
            _end = getPosATL _best;
        };
        /* Own A* over the live road network first; the engine planner is the fallback. */
        private _astar = [_from, _target,30000,_blockedRoads] call NeroAI_fnc_roadRoute;
        if (_astar isNotEqualTo []) exitWith {_group setVariable ["NeroWL_routeMethod","ASTAR"]; _astar};
        if (_blockedRoads isNotEqualTo []) exitWith {[]};
        _group setVariable ["NeroWL_routeMethod","ENGINE"];
        private _key = format ["NeroWL_path_%1_%2", netId _mover, diag_tickTime];
        missionNamespace setVariable [_key, []];
        private _agent = calculatePath [_type, "SAFE", _from, _end];
        if (isNull _agent) exitWith {[]};
        _mover setVariable ["NeroWL_pathAgent",_agent];
        _mover setVariable ["NeroWL_pathKey",_key];
        _agent setVariable ["NeroWL_key", _key];
        _agent addEventHandler ["PathCalculated", {
            params ["_agent","_path"];
            private _k = _agent getVariable ["NeroWL_key",""];
            if (_k != "" && {count _path > count (missionNamespace getVariable [_k,[]])}) then {missionNamespace setVariable [_k, _path];};
        }];
        private _t = diag_tickTime + 15;
        waitUntil {sleep 1; !(call _current) || {diag_tickTime > _t} || {count (missionNamespace getVariable [_key,[]]) > 0 && {diag_tickTime > _t - 12}}};
        private _raw = missionNamespace getVariable [_key, []];
        deleteVehicle _agent;
        _mover setVariable ["NeroWL_pathAgent",nil];
        _mover setVariable ["NeroWL_pathKey",nil];
        missionNamespace setVariable [_key, nil];
        if !(call _current) exitWith {[]};
        // Checkpoints every ~110 m along the engine route, end point kept.
        private _points = [];
        private _last = _from;
        {
            if ((_x distance2D _last) >= 110) then {_points pushBack [_x # 0, _x # 1, 0]; _last = _x;};
        } forEach _raw;
        if (_raw isNotEqualTo []) then {private _e = _raw select (count _raw - 1); _points pushBack [_e # 0, _e # 1, 0];};
        _points
    };
    /* Contact mode: the previous bounded corridor search, but a sample over
     * water with a road under it is a bridge, not an obstacle. */
    private _corridorStep = {
        params [["_roadsOnly",false]];
        private _start = getPosATL _mover;
        private _remaining = _start distance2D _target;
        private _step = 220 min _remaining;
        private _bearing = _start getDir _target;
        private _choices = [];
        {
            private _pos = _start getPos [_step,_bearing + _x];
            if (abs _x < 1 && {_remaining < 220}) then {_pos = +_target;};
            _choices pushBack [_pos,false];
        } forEach [0,-25,25,-50,50,-80,80];
        private _roads = (_start getPos [_step,_bearing]) nearRoads 180;
        _roads resize ((count _roads) min 16);
        {_choices pushBack [getPosATL _x,true];} forEach _roads;
        // Road mode without an engine route: stay on the road network when it is there.
        if (_roadsOnly) then {_choices = _choices select {_x # 1};};
        private _ranked = [];
        {
            _x params ["_pos","_road"];
            private _distance = _start distance2D _pos;
            private _safe = _distance > 40 && {(_blockedRoads findIf {_x distance2D _pos < 30}) < 0};
            private _worst = 1;
            for "_i" from 1 to (ceil (_distance / 25)) do {
                private _p = _start getPos [(_i * 25) min _distance,_start getDir _pos];
                private _z = (surfaceNormal _p) # 2;
                private _bridge = surfaceIsWater _p && {(_p nearRoads 12) isNotEqualTo []};
                if (!_bridge) then {_worst = _worst min _z;};
                if ((surfaceIsWater _p && {!_bridge}) || {!_bridge && {_z < 0.97}}) exitWith {_safe = false;};
            };
            if (_safe && {(_pos distance2D _target) < _remaining + 30}) then {
                _ranked pushBack [(_pos distance2D _target) + _distance*0.15 + (1-_worst)*1500 - (if (_road) then {60} else {0}),_pos];
            };
        } forEach _choices;
        _ranked sort true;
        if (_ranked isEqualTo []) then {[]} else {(_ranked # 0) # 1}
    };

    _group setVariable ["NeroWL_routeState","MOVING",true];
    private _until = diag_tickTime + 1800;
    private _state = "";
    private _replans = 0;
    private _stalls = 0;
    while {_state == "" && {diag_tickTime < _until}} do {
        if (!(call _current)) exitWith {_state = "CANCELLED";};
        if (!_onFoot && {alive _mover} && {!canMove _mover || {fuel _mover <= 0}}) exitWith {_state = "DAMAGED";};
        if (!(call _alive)) exitWith {_state = "LOST";};
        if (_mover distance2D _target < 45) exitWith {_state = "ARRIVED";};
        if (call _inContact || {_mover distance2D _target < 400}) then {
            /* Fight or short final leg: cross-country toward the objective in short hops. */
            _group setVariable ["NeroWL_routeMode","CONTACT"];
            /* 8.10: LAMBS Danger.fsm (if loaded) fights the contact and the last leg. */
            _group setVariable ["lambs_danger_disableGroupAI", nil];
            private _pick = [false] call _corridorStep;
            if (_pick isEqualTo []) then {_pick = +_target;};
            private _r = [_pick,35,false] call _driveTo;
            if (_r in ["CANCELLED","LOST","DAMAGED","HELD"]) exitWith {_state = _r;};
            if (_r == "STALLED") then {private _recovered = call _unstick;if (_recovered != "RECOVERED") then {_state = _recovered;};_stalls = _stalls+1;} else {_stalls = 0;};
            if (_stalls >= 4) exitWith {_state = "BLOCKED";};
        } else {
            _group setVariable ["NeroWL_routeMode","ROAD"];
            /* 8.10: no LAMBS on a road march: it breaks columns and dismounts crews. */
            _group setVariable ["lambs_danger_disableGroupAI", true];
            private _points = [getPosATL _mover] call _roadPath;
            ["INFO",format ["%1 route plan mode=ROAD method=%5 mover=%2 checkpoints=%3 distance=%4",groupId _group,typeOf _mover,count _points,round (_mover distance2D _target),_group getVariable ["NeroWL_routeMethod","NONE"]]] call NeroAI_fnc_log;
            if (_points isEqualTo []) then {
                /* No road route: one bounded corridor hop, then plan again. */
                private _pick = [true] call _corridorStep;
                if (_pick isEqualTo []) then {_stalls = _stalls + 1;} else {
                    private _r = [_pick,35,true] call _driveTo;
                    if (_r in ["CANCELLED","LOST","DAMAGED","HELD"]) then {_state = _r;};
                    if (_r == "STALLED") then {private _recovered = call _unstick;if (_recovered != "RECOVERED") then {_state = _recovered;};_stalls = _stalls+1;} else {_stalls = 0;};
                };
                if (_stalls >= 4) then {_state = "BLOCKED_TERRAIN";};
            } else {
                private _outcome = "REACHED";
                {
                    private _r = [_x,30,true] call _driveTo;
                    if (_r == "STALLED") then {private _recovered = call _unstick;_r = if (_recovered == "RECOVERED") then {[_x,30,true] call _driveTo} else {_recovered};};
                    if (_r != "REACHED") exitWith {_outcome = _r;};
                } forEach _points;
                switch (_outcome) do {
                    case "CANCELLED";
                    case "LOST"; case "DAMAGED"; case "HELD": {_state = _outcome;};
                    case "BLOCKED": {_replans = _replans+1;call _markBlocked;if (_replans >= 2) then {_state = "BLOCKED";};};
                    case "CONTACT": {};
                    case "STALLED": {_replans = _replans + 1; if (_replans >= 3) then {_state = "BLOCKED";};};
                    default {
                        /* On the road nearest the objective: the short last leg. */
                        private _r = [_target,45,true] call _driveTo;
                        if (_r == "STALLED" && {!_onFoot}) then {private _recovered = call _unstick;_r = if (_recovered == "RECOVERED") then {[_target,45,true] call _driveTo} else {_recovered};};
                        if (_r == "BLOCKED") then {_state = "BLOCKED";};
                        if (_r == "REACHED") then {_state = "ARRIVED";};
                        if (_r in ["CANCELLED","LOST","DAMAGED","HELD"]) then {_state = _r;};
                        if (_r == "STALLED") then {_replans = _replans + 1; if (_replans >= 3) then {_state = "BLOCKED";};};
                    };
                };
            };
        };
    };
    if (_state == "") then {_state = "BLOCKED";};
    if ((_mover getVariable ["NeroWL_motionOwner",[]]) isEqualTo [_group,_epoch]) then {
        [_mover] call NeroAI_fnc_motionRestore;
        _mover setVariable ["NeroWL_motionOwner",nil];
        if (_state in ["BLOCKED","BLOCKED_TERRAIN","DAMAGED"]) then {
            if (local driver _mover && {!isPlayer driver _mover}) then {doStop driver _mover;};
            _mover setVariable ["NeroWL_motionBlocked",[_target,diag_tickTime+60,_group getVariable ["NeroAI_opToken",0]]];
            _group setVariable ["NeroWL_routeBlockedPlayerToken",_group getVariable ["NeroAI_opToken",0]];
        };
        _mover setVariable ["NeroWL_motionState",_state,true];
    };
    if (_state == "CANCELLED" || {(_group getVariable ["NeroWL_routeEpoch",0]) != _epoch}) exitWith {};
    _group setVariable ["NeroWL_routeMovers",(_group getVariable ["NeroWL_routeMovers",[]]) - [_mover]];
    if ((_group getVariable ["NeroWL_routeMovers",[]]) isEqualTo []) then {
        private _danger = _group getVariable ["NeroWL_routeDangerBefore",[]];
        if (_danger isNotEqualTo []) then {_group setVariable ["lambs_danger_disableGroupAI",_danger # 0];};
        _group setVariable ["NeroWL_routeDangerBefore",nil];
    };
    _group setVariable ["NeroWL_routeState",_state,true];
    if (_state in ["BLOCKED","BLOCKED_TERRAIN"]) then {
        ["WARN",format ["%1 route=%2; mover=%3; mode=%4; destination=%5",groupId _group,_state,typeOf _mover,_group getVariable ["NeroWL_routeMode",""],_target]] call NeroAI_fnc_log;
    };
};
_mover setVariable ["NeroWL_routeScript",_handle];
true
