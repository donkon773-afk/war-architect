/*
 * Author: KBA Studio
 * Opens a map-click correction interface for the latest in-flight FP-5 missile.
 * LMB begins or replaces a route; the first Shift+LMB begins a new route and later Shift+LMB clicks append waypoints.
 *
 * Arguments:
 * 0: Launcher or missile <OBJECT>
 * 1: Close map after first non-shift click <BOOL> (default: false)
 *
 * Return Value:
 * True if interface opened <BOOL>
 *
 * Example:
 * [cursorObject] call FP5_fnc_openMapCorrection
 *
 * Public: Yes
 */

#define FP5_CONST_DISPERSION_RADIUS 14

params [
    ["_source", objNull, [objNull]],
    ["_closeAfterClick", false, [false]]
];

if (!hasInterface) exitWith {false};

private _missile = objNull;
if (!isNull _source && {typeOf _source == "Flamingo_CruiseMissile"}) then {
    _missile = _source;
} else {
    if (!isNull _source) then {
        private _activeMissiles = _source getVariable ["FP5_var_activeMissiles", []];
        _activeMissiles = _activeMissiles select {!isNull _x && {alive _x}};
        if ((count _activeMissiles) > 0) then {
            _missile = _activeMissiles select ((count _activeMissiles) - 1);
        } else {
            _missile = _source getVariable ["FP5_var_lastMissile", objNull];
        };
    };
};

if (isNull _missile || {!alive _missile}) exitWith {
    hintSilent "No FP-5 missile is currently in flight.";
    false
};

private _oldMarkers = missionNamespace getVariable ["FP5_var_mapCorrectionMarkers", []];
{
    deleteMarkerLocal _x;
} forEach _oldMarkers;
missionNamespace setVariable ["FP5_var_mapCorrectionMarkers", []];
missionNamespace setVariable ["FP5_var_mapCorrectionMarker", ""];

private _routeDisplayASL = [];

private _markerSeed = floor (diag_tickTime * 1000);
private _markers = [];
{
    private _markerName = format ["FP5_var_mapCorrectionMarker_%1_%2", _markerSeed, _forEachIndex];
    private _marker = createMarkerLocal [_markerName, [_x select 0, _x select 1]];
    _marker setMarkerTypeLocal (["mil_dot", "mil_objective"] select (_forEachIndex == ((count _routeDisplayASL) - 1)));
    _marker setMarkerColorLocal "ColorWEST";
    _marker setMarkerTextLocal format ["FP-5 WP %1", _forEachIndex + 1];
    _markers pushBack _marker;
} forEach _routeDisplayASL;
missionNamespace setVariable ["FP5_var_mapCorrectionMarkers", _markers];

missionNamespace setVariable ["FP5_var_mapCorrectionMissile", _missile];
missionNamespace setVariable ["FP5_var_mapCorrectionCloseAfterClick", _closeAfterClick];
missionNamespace setVariable ["FP5_var_mapCorrectionRouteASL", []];
missionNamespace setVariable ["FP5_var_mapCorrectionRouteDisplayASL", []];
missionNamespace setVariable ["FP5_var_mapCorrectionRouteStarted", false];

private _oldCleanup = missionNamespace getVariable ["FP5_var_mapCorrectionCleanup", scriptNull];
if (!isNull _oldCleanup) then {
    terminate _oldCleanup;
};

onMapSingleClick {
    private _missile = missionNamespace getVariable ["FP5_var_mapCorrectionMissile", objNull];
    if (isNull _missile || {!alive _missile}) exitWith {
        onMapSingleClick "";
        openMap [false, false];
        true
    };

    private _rawTargetASL = [_pos select 0, _pos select 1, (getTerrainHeightASL [_pos select 0, _pos select 1]) + 0.5];
    private _angle = random 360;
    private _radius = (sqrt (random 1)) * FP5_CONST_DISPERSION_RADIUS;
    private _targetX = (_rawTargetASL select 0) + ((sin _angle) * _radius);
    private _targetY = (_rawTargetASL select 1) + ((cos _angle) * _radius);
    private _targetASL = [_targetX, _targetY, (getTerrainHeightASL [_targetX, _targetY]) + 0.5];

    private _routeASL = missionNamespace getVariable ["FP5_var_mapCorrectionRouteASL", []];
    if (_routeASL isEqualType []) then {
        _routeASL = _routeASL select {_x isEqualType [] && {count _x >= 3}};
    } else {
        _routeASL = [];
    };

    private _routeDisplayASL = missionNamespace getVariable ["FP5_var_mapCorrectionRouteDisplayASL", []];
    if (_routeDisplayASL isEqualType []) then {
        _routeDisplayASL = _routeDisplayASL select {_x isEqualType [] && {count _x >= 3}};
    } else {
        _routeDisplayASL = [];
    };

    private _routeStarted = missionNamespace getVariable ["FP5_var_mapCorrectionRouteStarted", false];
    if (!_shift || {!_routeStarted} || {(count _routeASL) == 0}) then {
        _routeASL = [];
        _routeDisplayASL = [];
        _missile setVariable ["FP5_var_routeIndex", 0, true];
    };

    _routeASL pushBack _targetASL;
    _routeDisplayASL pushBack _rawTargetASL;
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteASL", _routeASL];
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteDisplayASL", _routeDisplayASL];
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteStarted", true];

    private _routeIndex = _missile getVariable ["FP5_var_routeIndex", 0];
    if !(_routeIndex isEqualType 0) then {
        _routeIndex = 0;
    };
    if (!_shift) then {
        _routeIndex = 0;
    };
    _routeIndex = ((round _routeIndex) max 0) min ((count _routeASL) - 1);

    private _currentTargetASL = +(_routeASL select _routeIndex);
    _missile setVariable ["FP5_var_routeASL", _routeASL, true];
    _missile setVariable ["FP5_var_routeDisplayASL", _routeDisplayASL, true];
    _missile setVariable ["FP5_var_routeIndex", _routeIndex, true];
    _missile setVariable ["FP5_var_routeRevision", (_missile getVariable ["FP5_var_routeRevision", 0]) + 1, true];
    _missile setVariable ["FP5_var_targetASL", _currentTargetASL, true];
    _missile setVariable ["FP5_var_targetATL", ASLToATL _currentTargetASL, true];

    if (local _missile) then {
        _missile setMissileTargetPos (ASLToATL _currentTargetASL);
    };

    private _oldMarkers = missionNamespace getVariable ["FP5_var_mapCorrectionMarkers", []];
    {
        deleteMarkerLocal _x;
    } forEach _oldMarkers;

    private _markerSeed = floor (diag_tickTime * 1000);
    private _markers = [];
    {
        private _markerName = format ["FP5_var_mapCorrectionMarker_%1_%2", _markerSeed, _forEachIndex];
        private _marker = createMarkerLocal [_markerName, [_x select 0, _x select 1]];
        _marker setMarkerTypeLocal (["mil_dot", "mil_objective"] select (_forEachIndex == ((count _routeDisplayASL) - 1)));
        _marker setMarkerColorLocal "ColorWEST";
        _marker setMarkerTextLocal format ["FP-5 WP %1", _forEachIndex + 1];
        _markers pushBack _marker;
    } forEach _routeDisplayASL;
    missionNamespace setVariable ["FP5_var_mapCorrectionMarkers", _markers];

    hintSilent format [
        "FP-5 route updated: %1 waypoint(s)",
        count _routeASL
    ];

    if ((missionNamespace getVariable ["FP5_var_mapCorrectionCloseAfterClick", false]) && {!_shift}) then {
        onMapSingleClick "";
        openMap [false, false];
    };

    true
};

FP5_var_mapCorrectionCleanup = [] spawn {
    waitUntil {
        sleep 0.1;
        !visibleMap
    };

    onMapSingleClick "";
    missionNamespace setVariable ["FP5_var_mapCorrectionMissile", objNull];
    missionNamespace setVariable ["FP5_var_mapCorrectionCloseAfterClick", false];
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteASL", []];
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteDisplayASL", []];
    missionNamespace setVariable ["FP5_var_mapCorrectionRouteStarted", false];

    private _markers = missionNamespace getVariable ["FP5_var_mapCorrectionMarkers", []];
    {
        deleteMarkerLocal _x;
    } forEach _markers;
    missionNamespace setVariable ["FP5_var_mapCorrectionMarkers", []];
    missionNamespace setVariable ["FP5_var_mapCorrectionMarker", ""];
};

missionNamespace setVariable ["FP5_var_mapCorrectionCleanup", FP5_var_mapCorrectionCleanup];
openMap [true, false];
hintSilent "Click to set FP-5 route. Shift-click appends waypoints.";

true
