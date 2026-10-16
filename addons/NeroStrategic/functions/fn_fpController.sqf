/*
 * Author: KBA Studio
 * Takes ownership of an FP-5 projectile immediately after launch and drives the
 * forward climb, terrain-following cruise, route waypoints, and terminal dive profile.
 *
 * Arguments:
 * Fired event handler array:
 * 0: Launcher <OBJECT>
 * 1: Weapon <STRING>
 * 2: Muzzle <STRING>
 * 3: Mode <STRING>
 * 4: Ammo <STRING>
 * 5: Magazine <STRING>
 * 6: Projectile <OBJECT>
 * 7: Gunner <OBJECT> (optional)
 *
 * Return Value:
 * Controller state <HASHMAP or BOOL>
 *
 * Example:
 * _this call FP5_fnc_initMissileCtrl
 *
 * Public: No
 */

#define FP5_CONST_LAUNCH_SPEED 45
#define FP5_CONST_CLIMB_SPEED 100
#define FP5_CONST_CRUISE_SPEED 277.777778
#define FP5_CONST_TERMINAL_SPEED 277.777778
#define FP5_CONST_CLIMB_ACCELERATION 6
#define FP5_CONST_CRUISE_ACCELERATION 10
#define FP5_CONST_DECELERATION 18
#define FP5_CONST_CRUISE_ALT_AGL 150
#define FP5_CONST_TERMINAL_RANGE 1400
#define FP5_CONST_IMPACT_DISTANCE 12
#define FP5_CONST_CLIMB_TURN_RATE 70
#define FP5_CONST_CRUISE_TURN_RATE 24
#define FP5_CONST_DIVE_TURN_RATE 70
#define FP5_CONST_TERRAIN_LOOKAHEAD 5000
#define FP5_CONST_TERRAIN_NEAR_SAMPLE 100
#define FP5_CONST_TERRAIN_SAMPLE 220
#define FP5_CONST_TERRAIN_CORRIDOR 220
#define FP5_CONST_TERRAIN_CLEARANCE 160
#define FP5_CONST_TERRAIN_REFRESH 0.20
#define FP5_CONST_CLIMB_AHEAD 1100
#define FP5_CONST_WAYPOINT_RADIUS 220
#define FP5_CONST_DISPERSION_RADIUS 14

params [
    ["_launcher", objNull, [objNull]],
    ["_weapon", "", [""]],
    ["_muzzle", "", [""]],
    ["_mode", "", [""]],
    ["_ammo", "", [""]],
    ["_magazine", "", [""]],
    ["_missile", objNull, [objNull]],
    ["_gunner", objNull, [objNull]]
];

if (_ammo != "Flamingo_CruiseMissile") exitWith {false};
if (isNull _launcher || {isNull _missile}) exitWith {false};
if (!local _missile) exitWith {false};

[_launcher] spawn {params ["_launcher"];sleep 3;if (alive _launcher && {local _launcher} && {someAmmo _launcher}) then {_launcher setVariable ["FP5_var_tubeEmpty",false,true];_launcher animateSource ["tubel_hide_full",0,true];_launcher animateSource ["tubel_hide_empty",1,true];};};

private _fnc_applyDispersion = {
    params [["_targetASL", [0, 0, 0], [[]]]];

    private _angle = random 360;
    private _radius = (sqrt (random 1)) * FP5_CONST_DISPERSION_RADIUS;
    private _x = (_targetASL select 0) + ((sin _angle) * _radius);
    private _y = (_targetASL select 1) + ((cos _angle) * _radius);
    private _z = (getTerrainHeightASL [_x, _y]) + 0.5;

    [_x, _y, _z]
};

// Sample a wide forward corridor so rising terrain is detected before the
// missile reaches the near-field obstacle zone.
private _fnc_scanTerrain = {
    params [
        ["_originASL", [0, 0, 0], [[]]],
        ["_direction2D", [0, 1, 0], [[]]],
        ["_distance", FP5_CONST_TERRAIN_LOOKAHEAD, [0]]
    ];

    private _direction = [_direction2D select 0, _direction2D select 1, 0];
    if ((vectorMagnitude _direction) < 0.001) exitWith {
        [-1e6, 0, _originASL]
    };
    _direction = vectorNormalized _direction;

    private _side = [-(_direction select 1), _direction select 0, 0];
    private _scanDistance = (_distance max FP5_CONST_TERRAIN_NEAR_SAMPLE) min FP5_CONST_TERRAIN_LOOKAHEAD;
    private _sampleCount = ceil ((_scanDistance - FP5_CONST_TERRAIN_NEAR_SAMPLE) / FP5_CONST_TERRAIN_SAMPLE);
    private _sampleDistances = [FP5_CONST_TERRAIN_NEAR_SAMPLE min _scanDistance];
    for "_index" from 1 to _sampleCount do {
        private _sampleDistance = (FP5_CONST_TERRAIN_NEAR_SAMPLE + (_index * FP5_CONST_TERRAIN_SAMPLE)) min _scanDistance;
        _sampleDistances pushBack _sampleDistance;
    };
    private _highestTerrainASL = -1e6;
    private _highestDistance = 0;
    private _highestPoint = _originASL;

    {
        private _sampleDistance = _x;
        private _center = _originASL vectorAdd (_direction vectorMultiply _sampleDistance);

        {
            private _samplePoint = _center vectorAdd (_side vectorMultiply _x);
            private _terrainASL = getTerrainHeightASL [
                _samplePoint select 0,
                _samplePoint select 1
            ];

            if (_terrainASL > _highestTerrainASL) then {
                _highestTerrainASL = _terrainASL;
                _highestDistance = _sampleDistance;
                _highestPoint = [_samplePoint select 0, _samplePoint select 1, _terrainASL];
            };
        } forEach [-FP5_CONST_TERRAIN_CORRIDOR, 0, FP5_CONST_TERRAIN_CORRIDOR];
    } forEach _sampleDistances;

    [_highestTerrainASL, _highestDistance, _highestPoint]
};

[_launcher, _missile, true] call FP5_fnc_handleAnim;
if (!isNil "NeroOP_fnc_campaignCruiseTrack") then {[_missile,_launcher,0] spawn NeroOP_fnc_campaignCruiseTrack;};

private _launcherDir = vectorDir _launcher;
private _muzzleStartASL = _launcher modelToWorldWorld (_launcher selectionPosition ["usti hlavne", "Memory"]);
private _muzzleEndASL = _launcher modelToWorldWorld (_launcher selectionPosition ["konec hlavne", "Memory"]);
private _muzzleAxisDir = _muzzleEndASL vectorFromTo _muzzleStartASL;
private _launchDir = [_muzzleAxisDir select 0, _muzzleAxisDir select 1, 0];

if ((vectorMagnitude _launchDir) < 0.35) then {
    private _weaponDir = _launcher weaponDirection _weapon;
    if (_weaponDir isEqualType [] && {count _weaponDir >= 3}) then {
        _launchDir = [_weaponDir select 0, _weaponDir select 1, 0];
    };
};
if ((vectorMagnitude _launchDir) < 0.001) then {
    private _velocityDir = velocity _missile;
    _launchDir = [_velocityDir select 0, _velocityDir select 1, 0];
};
if ((vectorMagnitude _launchDir) < 0.001) then {
    _launchDir = [_launcherDir select 0, _launcherDir select 1, 0];
};
if ((vectorMagnitude _launchDir) < 0.001) then {
    _launchDir = [0, 1, 0];
};
_launchDir = vectorNormalized _launchDir;

private _launchForwardDir = [_launchDir select 0, _launchDir select 1, 0];
if ((vectorMagnitude _launchForwardDir) < 0.001) then {
    _launchForwardDir = [_launcherDir select 0, _launcherDir select 1, 0];
};
if ((vectorMagnitude _launchForwardDir) < 0.001) then {
    _launchForwardDir = [0, 1, 0];
};
_launchForwardDir = vectorNormalized _launchForwardDir;

private _launchSide = _launchDir vectorCrossProduct (vectorUp _launcher);
if ((vectorMagnitude _launchSide) < 0.001) then {
    _launchSide = _launchDir vectorCrossProduct [0, 0, 1];
};
if ((vectorMagnitude _launchSide) < 0.001) then {
    _launchSide = [1, 0, 0];
};
private _launchUp = vectorNormalized (_launchSide vectorCrossProduct _launchDir);
_missile setVectorDirAndUp [_launchDir, _launchUp];
/* Clear the tube and launcher geometry before native collision simulation ticks. */
private _exitASL=(getPosASL _missile) vectorAdd (_launchForwardDir vectorMultiply 8);_exitASL set [2,(_exitASL#2) max (getTerrainHeightASL _exitASL+6)];_missile setPosASL _exitASL;_missile disableCollisionWith _launcher;_launcher disableCollisionWith _missile;_missile setVelocity ((_launchDir vectorMultiply FP5_CONST_LAUNCH_SPEED) vectorAdd [0,0,15]);
diag_log format ["[NeroOP FP5] LAUNCH posASL=%1 controller=local",_exitASL];

private _fallbackTargetASL = (getPosASL _launcher) vectorAdd (_launchForwardDir vectorMultiply 8000);
_fallbackTargetASL set [2, getTerrainHeightASL [_fallbackTargetASL select 0, _fallbackTargetASL select 1]];

private _displayTargetASL = _missile getVariable ["NeroOP_artyTargetASL",missileTargetPos _missile];
if !(_displayTargetASL isEqualType [] && {count _displayTargetASL >= 3}) then {
    _displayTargetASL = +_fallbackTargetASL;
};
if (((abs (_displayTargetASL select 0)) + (abs (_displayTargetASL select 1))) < 1) then {
    _displayTargetASL = +_fallbackTargetASL;
};

private _displayTargetTerrainASL = getTerrainHeightASL [_displayTargetASL select 0, _displayTargetASL select 1];
_displayTargetASL set [2, ((_displayTargetASL select 2) max (_displayTargetTerrainASL + 0.5))];

private _targetASL = [_displayTargetASL] call _fnc_applyDispersion;

_missile setVariable ["FP5_var_targetASL", _targetASL, true];
_missile setVariable ["FP5_var_targetATL", ASLToATL _targetASL, true];
_missile setVariable ["FP5_var_routeASL", [_targetASL], true];
_missile setVariable ["FP5_var_routeDisplayASL", [_displayTargetASL], true];
_missile setVariable ["FP5_var_routeIndex", 0, true];
_missile setVariable ["FP5_var_routeRevision", 0, true];
_missile setVariable ["FP5_var_launchTime", time, true];
_missile setVariable ["FP5_var_phase", "climb", true];
_missile setVariable ["FP5_var_launcher", _launcher, true];
_missile setMissileTargetPos (ASLToATL _targetASL);

private _activeMissiles = _launcher getVariable ["FP5_var_activeMissiles", []];
_activeMissiles = _activeMissiles select {!isNull _x && {alive _x}};
_activeMissiles pushBackUnique _missile;
_launcher setVariable ["FP5_var_activeMissiles", _activeMissiles, true];
_launcher setVariable ["FP5_var_lastMissile", _missile, true];
_launcher setVariable ["FP5_var_tubeEmpty", true, true];

private _missilePosASL = getPosASL _missile;
private _initialTerrainASL = getTerrainHeightASL [
    _missilePosASL select 0,
    _missilePosASL select 1
];

if (!isNil "NeroOP_fnc_campaignCruiseTrack") then {[_missile,_launcher,[west,east] find side group effectiveCommander _launcher] spawn NeroOP_fnc_campaignCruiseTrack;};
private _launchSide=_launcher getVariable ["NeroOP_side",[west,east] find side group effectiveCommander _launcher];_missile setVariable ["NeroOP_side",_launchSide,true];_missile setVariable ["NeroOP_source",_launcher,true];
private _state = createHashMapFromArray [
    ["launcher", _launcher],
    ["missile", _missile],
    ["gunner", _gunner],
    ["targetASL", _targetASL],
    ["phase", "climb"],
    ["dir", _launchDir],
    ["up", _launchUp],
    ["launchDir", _launchDir],
    ["launchForwardDir", _launchForwardDir],
    ["lastTargetASL", _targetASL],
    ["lastSimTime", time],
    ["born",time],["terminalAt",-1],["terminalStart",277.777778],
    ["routeIndex", 0],
    ["routeRevision", 0],
    ["speed", FP5_CONST_LAUNCH_SPEED],
    ["terrainCeilingASL", _initialTerrainASL],
    ["terrainDistance", 0],
    ["terrainPointASL", _missilePosASL],
    ["lastTerrainScan", time],
    ["terrainScanDirection", _launchForwardDir],
    ["terrainScanner", _fnc_scanTerrain]
];

private _handlerId = addMissionEventHandler ["EachFrame", {
    _thisArgs params ["_state"];

    private _missile = _state get "missile";
    private _launcher = _state get "launcher";

    if (isNull _missile || {!alive _missile}) exitWith {
        removeMissionEventHandler ["EachFrame", _thisEventHandler];

        if (!isNull _launcher) then {
            private _activeMissiles = _launcher getVariable ["FP5_var_activeMissiles", []];
            _activeMissiles = _activeMissiles select {!isNull _x && {alive _x} && {!(_x isEqualTo _missile)}};
            _launcher setVariable ["FP5_var_activeMissiles", _activeMissiles, true];

            if ((_launcher getVariable ["FP5_var_lastMissile", objNull]) isEqualTo _missile) then {
                _launcher setVariable ["FP5_var_lastMissile", objNull, true];
            };
        };
    };

    private _simTime = time;
    private _lastSimTime = _state get "lastSimTime";
    if (isNil "_lastSimTime") then {
        _lastSimTime = _simTime;
    };

    private _dt = _simTime - _lastSimTime;
    _state set ["lastSimTime", _simTime];
    if (_dt <= 0) exitWith {};
    _dt = _dt min 0.05;

    private _posASL = getPosASL _missile;
    private _routeASL = _missile getVariable ["FP5_var_routeASL", []];
    if (_routeASL isEqualType []) then {
        _routeASL = _routeASL select {_x isEqualType [] && {count _x >= 3}};
    } else {
        _routeASL = [];
    };

    if ((count _routeASL) == 0) then {
        private _fallbackTarget = _missile getVariable ["FP5_var_targetASL", _state get "targetASL"];
        if !(_fallbackTarget isEqualType [] && {count _fallbackTarget >= 3}) then {
            _fallbackTarget = _state get "targetASL";
        };
        _routeASL = [_fallbackTarget];
    };

    private _routeIndex = _missile getVariable ["FP5_var_routeIndex", _state get "routeIndex"];
    if !(_routeIndex isEqualType 0) then {
        _routeIndex = 0;
    };
    _routeIndex = (round _routeIndex) max 0;
    _routeIndex = _routeIndex min ((count _routeASL) - 1);

    private _routeRevision = _missile getVariable ["FP5_var_routeRevision", _state get "routeRevision"];
    if !(_routeRevision isEqualType 0) then {
        _routeRevision = _state get "routeRevision";
    };
    if !(_routeRevision isEqualTo (_state get "routeRevision")) then {
        _state set ["routeRevision", _routeRevision];
        _state set ["routeIndex", _routeIndex];
        _state set ["lastTargetASL", []];
    };

    private _targetASL = +(_routeASL select _routeIndex);
    private _targetTerrainASL = getTerrainHeightASL [_targetASL select 0, _targetASL select 1];
    _targetASL set [2, ((_targetASL select 2) max (_targetTerrainASL + 0.5))];

    private _dx = (_targetASL select 0) - (_posASL select 0);
    private _dy = (_targetASL select 1) - (_posASL select 1);
    private _horizontalDistance = sqrt ((_dx * _dx) + (_dy * _dy));
    private _distanceToTarget = _posASL distance _targetASL;
    private _lastRouteIndex = (count _routeASL) - 1;
    private _isFinalWaypoint = _routeIndex >= _lastRouteIndex;

    if (!_isFinalWaypoint && {_horizontalDistance <= FP5_CONST_WAYPOINT_RADIUS}) then {
        _routeIndex = _routeIndex + 1;
        _missile setVariable ["FP5_var_routeIndex", _routeIndex, true];
        _state set ["routeIndex", _routeIndex];

        _targetASL = +(_routeASL select _routeIndex);
        _targetTerrainASL = getTerrainHeightASL [_targetASL select 0, _targetASL select 1];
        _targetASL set [2, ((_targetASL select 2) max (_targetTerrainASL + 0.5))];

        _dx = (_targetASL select 0) - (_posASL select 0);
        _dy = (_targetASL select 1) - (_posASL select 1);
        _horizontalDistance = sqrt ((_dx * _dx) + (_dy * _dy));
        _distanceToTarget = _posASL distance _targetASL;
        _isFinalWaypoint = _routeIndex >= _lastRouteIndex;
    };

    if !(_targetASL isEqualTo (_state get "lastTargetASL")) then {
        _state set ["lastTargetASL", +_targetASL];
        _state set ["targetASL", +_targetASL];
        _missile setVariable ["FP5_var_targetASL", _targetASL, true];
        _missile setVariable ["FP5_var_targetATL", ASLToATL _targetASL, true];
        _missile setMissileTargetPos (ASLToATL _targetASL);
    };

    private _phase = _state get "phase";
    private _terrainHereASL = getTerrainHeightASL [_posASL select 0, _posASL select 1];
    private _altitudeAGL = (_posASL select 2) - _terrainHereASL;

    private _terrainScanner = _state get "terrainScanner";
    private _terrainScanDirection = _state get "terrainScanDirection";
    private _currentDirection = _state get "dir";
    private _currentDirection2D = [_currentDirection select 0, _currentDirection select 1, 0];
    if ((vectorMagnitude _currentDirection2D) < 0.001) then {
        _currentDirection2D = _terrainScanDirection;
    };
    _currentDirection2D = vectorNormalized _currentDirection2D;

    private _scanDot = ((_terrainScanDirection vectorDotProduct _currentDirection2D) max -1) min 1;
    private _directionChanged = (acos _scanDot) > 8;
    private _lastTerrainScan = _state get "lastTerrainScan";
    if ((_simTime - _lastTerrainScan) >= FP5_CONST_TERRAIN_REFRESH || {_directionChanged}) then {
        private _terrainScanDistance = (_horizontalDistance max FP5_CONST_TERRAIN_NEAR_SAMPLE) min FP5_CONST_TERRAIN_LOOKAHEAD;
        private _terrainScan = [_posASL, _currentDirection2D, _terrainScanDistance] call _terrainScanner;
        _state set ["terrainCeilingASL", _terrainScan select 0];
        _state set ["terrainDistance", _terrainScan select 1];
        _state set ["terrainPointASL", _terrainScan select 2];
        _state set ["lastTerrainScan", _simTime];
        _state set ["terrainScanDirection", _currentDirection2D];
    };

    private _terrainCeilingASL = _state get "terrainCeilingASL";
    private _terrainDistance = _state get "terrainDistance";
    private _terrainPointASL = _state get "terrainPointASL";
    private _terminalTerrainClear = _terrainCeilingASL <= (_targetTerrainASL + FP5_CONST_TERRAIN_CLEARANCE);

    if (_phase == "climb" && {_altitudeAGL >= FP5_CONST_CRUISE_ALT_AGL}) then {
        _phase = "cruise";
        _missile setVariable ["FP5_var_phase", _phase, true];
    };
    if (_phase == "dive" && {
        !_isFinalWaypoint ||
        {_horizontalDistance > FP5_CONST_TERMINAL_RANGE} ||
        {!_terminalTerrainClear}
    }) then {
        _phase = "cruise";
        _missile setVariable ["FP5_var_phase", _phase, true];
    };
    if (_phase != "dive" && {
        _isFinalWaypoint &&
        {_horizontalDistance <= FP5_CONST_TERMINAL_RANGE} &&
        {_terminalTerrainClear}
    }) then {
        _phase = "dive";
        _missile setVariable ["FP5_var_phase", _phase, true];
    };

    private _desiredDir = _state get "launchDir";
    private _turnRate = FP5_CONST_CLIMB_TURN_RATE;

    if (_phase == "climb") then {
        private _launchForwardDir = _state get "launchForwardDir";
        private _climbAheadASL = _posASL vectorAdd (_launchForwardDir vectorMultiply FP5_CONST_CLIMB_AHEAD);
        private _climbTerrainASL = getTerrainHeightASL [_climbAheadASL select 0, _climbAheadASL select 1];
        _climbTerrainASL = _climbTerrainASL max _terrainCeilingASL;
        private _climbTargetASL = [
            _climbAheadASL select 0,
            _climbAheadASL select 1,
            _climbTerrainASL + FP5_CONST_TERRAIN_CLEARANCE
        ];
        if (_terrainDistance > 0 && {(_terrainPointASL select 2) > (_terrainHereASL + 20)}) then {
            _climbTargetASL = [
                _terrainPointASL select 0,
                _terrainPointASL select 1,
                (_terrainPointASL select 2) + FP5_CONST_TERRAIN_CLEARANCE
            ];
        };
        _desiredDir = _posASL vectorFromTo _climbTargetASL;
    };

    if (_phase == "cruise") then {
        private _requiredCruiseHeight = (_terrainHereASL max _terrainCeilingASL) + FP5_CONST_TERRAIN_CLEARANCE;
        private _cruiseHeight = (_posASL select 2) max _requiredCruiseHeight;
        private _cruiseTargetASL = [_targetASL select 0, _targetASL select 1, _cruiseHeight];
        private _terrainThreat = _terrainDistance > 0 && {(_terrainPointASL select 2) > (_terrainHereASL + 20)};
        if (_terrainThreat) then {
            _cruiseTargetASL = [
                _terrainPointASL select 0,
                _terrainPointASL select 1,
                (_terrainPointASL select 2) + FP5_CONST_TERRAIN_CLEARANCE
            ];
            _turnRate = FP5_CONST_CLIMB_TURN_RATE;
        } else {
            _turnRate = FP5_CONST_CRUISE_TURN_RATE;
        };
        _desiredDir = _posASL vectorFromTo _cruiseTargetASL;
    };

    if (_phase == "dive") then {
        _desiredDir = _posASL vectorFromTo _targetASL;
        _turnRate = FP5_CONST_DIVE_TURN_RATE;
    };

    if ((vectorMagnitude _desiredDir) < 0.001) then {
        _desiredDir = _state get "dir";
    };

    private _currentDir = _state get "dir";
    private _dot = ((_currentDir vectorDotProduct _desiredDir) max -1) min 1;
    private _angle = acos _dot;
    private _turnFraction = 1;
    if (_angle > 0.01) then {
        _turnFraction = ((_turnRate * _dt) / _angle) min 1;
    };

    private _newDir = vectorNormalized ((_currentDir vectorMultiply (1 - _turnFraction)) vectorAdd (_desiredDir vectorMultiply _turnFraction));
    if ((vectorMagnitude _newDir) < 0.001) then {
        _newDir = _desiredDir;
    };

    private _speed = _state get "speed";
    if (isNil "_speed") then {
        _speed = FP5_CONST_LAUNCH_SPEED;
    };

    private _targetSpeed = FP5_CONST_CRUISE_SPEED;
    private _acceleration = FP5_CONST_CRUISE_ACCELERATION;
    if (_phase == "climb") then {
        _targetSpeed = FP5_CONST_CLIMB_SPEED;
        _acceleration = FP5_CONST_CLIMB_ACCELERATION;
    };
    if (_phase == "dive") then {
        _targetSpeed = FP5_CONST_TERMINAL_SPEED;
    };

    if (_speed < _targetSpeed) then {
        _speed = (_speed + (_acceleration * _dt)) min _targetSpeed;
    } else {
        _speed = (_speed - (FP5_CONST_DECELERATION * _dt)) max _targetSpeed;
    };

    private _newProfile=getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "flamingoProfile")==1;
    if (_newProfile) then {
        private _terminalAt=_state get "terminalAt";
        private _finalTarget=_missile getVariable ["FP5_var_targetASL",_state get "targetASL"];
        if (_terminalAt<0 && {_posASL distance _finalTarget<=1500}) then {_terminalAt=time;_state set ["terminalAt",time];_state set ["terminalStart",_speed];};
        _speed=[time-(_state get "born"),if (_terminalAt<0) then {-1} else {time-_terminalAt},_state get "terminalStart"] call FP5_fnc_flightProfile;
        _missile setVariable ["NeroOP_terminal",_terminalAt>=0,true];
    };
    if (_launcher getVariable ["NeroOP_fpEvade",false] && {_missile getVariable ["NeroOP_interceptorUntil",0]>time} && {if (_newProfile) then {(_state get "terminalAt")<0} else {_missile distance2D (_state get "targetASL")>1800}}) then {_newDir=vectorNormalized (_newDir vectorAdd ((_newDir vectorCrossProduct [0,0,1]) vectorMultiply (sin(time*150)*.18)));};
    private _side = _newDir vectorCrossProduct [0, 0, 1];
    if ((vectorMagnitude _side) < 0.001) then {
        _side = [1, 0, 0];
    };
    private _newUp = vectorNormalized (_side vectorCrossProduct _newDir);
    private _velocity = _newDir vectorMultiply _speed;
    private _nextPosASL = _posASL vectorAdd (_velocity vectorMultiply _dt);

    _missile setVectorDirAndUp [_newDir, _newUp];
    _missile setVelocityTransformation [
        _posASL,
        _nextPosASL,
        velocity _missile,
        _velocity,
        vectorDir _missile,
        _newDir,
        vectorUp _missile,
        _newUp,
        1
    ];

    _state set ["phase", _phase];
    _state set ["dir", _newDir];
    _state set ["up", _newUp];
    _state set ["speed", _speed];
    _state set ["routeIndex", _routeIndex];

    if (_isFinalWaypoint && {_phase == "dive" && {_distanceToTarget <= FP5_CONST_IMPACT_DISTANCE || {((_posASL select 2) - _terrainHereASL) <= 1.5}}}) then {
        triggerAmmo _missile;

        if (!isNull _launcher) then {
            private _activeMissiles = _launcher getVariable ["FP5_var_activeMissiles", []];
            _activeMissiles = _activeMissiles select {!isNull _x && {alive _x} && {!(_x isEqualTo _missile)}};
            _launcher setVariable ["FP5_var_activeMissiles", _activeMissiles, true];

            if ((_launcher getVariable ["FP5_var_lastMissile", objNull]) isEqualTo _missile) then {
                _launcher setVariable ["FP5_var_lastMissile", objNull, true];
            };
        };

        removeMissionEventHandler ["EachFrame", _thisEventHandler];
    };
}, [_state]];

_state set ["handlerId", _handlerId];
_missile setVariable ["FP5_var_controller", _handlerId];

_state
