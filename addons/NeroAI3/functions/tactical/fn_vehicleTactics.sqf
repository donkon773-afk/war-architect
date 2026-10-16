/* Capability-driven vehicle control for untouched vanilla groups. It selects
 * existing friendly empty assets only; NeroAI never creates or steals them. */
params ["_group", "_mode", ["_position", []], ["_onlyVehicle", objNull],["_source","INTERNAL"],["_orderType","MOVE"]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};

_mode = toUpper _mode;
private _members = (units _group) select {alive _x};
private _leader = leader _group;
private _friendlySide = side _leader;
private _existingVehicleState = _group getVariable ["NeroAI_vehicleState", "ON_FOOT"];
if (_mode isEqualTo "BOARD" && {_existingVehicleState in ["BOARDING", "PARTIAL_BOARDING"]}) exitWith {
    [false, "Посадка уже выполняется; ожидается подтверждение фактического размещения бойцов."]
};

if (_mode in ["DISEMBARK", "DISEMBARK_INFANTRY"]) exitWith {
    private _toDismount = _members;
    { unassignVehicle _x; doGetOut _x; } forEach _toDismount;
    _group setVariable ["NeroAI_vehicleState", "DISMOUNTED", true];
    ["INFO", format ["%1 dismounted by NeroAI order.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [true, format ["Высадка назначена для %1 бойц.", count _toDismount]]
};

if (_mode isEqualTo "MOVE") exitWith {
    if !(_position isEqualType [] && {count _position >= 2}) exitWith {[false, "Для движения техники нужны координаты."]};
    private _mountedVehicles = [];
    {
        private _vehicle = vehicle _x;
        if (_vehicle != _x && {alive _vehicle}) then {_mountedVehicles pushBackUnique _vehicle;};
    } forEach _members;
    private _issued = 0;
    private _spacing = if ((_mountedVehicles findIf {_x isKindOf "Tank"}) >= 0) then {40} else {20};
    private _travelBearing = _leader getDir _position;
    {
        private _driver = driver _x;
        if (!isNull _driver && {alive _driver} && {group _driver isEqualTo _group} && {!isPlayer _driver} && {local _x}) then {
            private _slot = ceil (_forEachIndex / 2);
            private _sign = if ((_forEachIndex mod 2) isEqualTo 0) then {-1} else {1};
            private _lateral = if (_forEachIndex isEqualTo 0) then {0} else {_slot * _spacing * _sign};
            private _vehicleTarget = [
                (_position # 0) + sin (_travelBearing + 90) * _lateral,
                (_position # 1) + cos (_travelBearing + 90) * _lateral,
                0
            ];
            if (_source isEqualTo "AUTONOMY" && {_orderType isEqualTo "ADVANCE"} && {missionNamespace getVariable ["NeroAI_rulesMode",false]}
                && {(_group getVariable ["NeroWL_rulesCombatRole",""]) in ["FIRE_SUPPORT","ANTI_TANK"]}
                && {((_group getVariable ["NeroWL_rulesMission",[]]) param [0,""]) isEqualTo "ATTACK"}) then {
                private _objective = [_group] call NeroAI_fnc_wlGroupObjective;
                if (!isNull _objective) then {_vehicleTarget = [_x,_group,getPosATL _objective,_group getVariable ["NeroWL_rulesCombatRole","FIRE_SUPPORT"],(getPosATL _objective) getDir (getPosATL _x)] call NeroAI_fnc_vehicleCombatPosition;};
            };
            if ([_x,_group,_vehicleTarget] call NeroAI_fnc_vehicleRoute) then {_issued = _issued+1;};
        };
    } forEach _mountedVehicles;
    /* Squads on foot march by road too: one guide follows the road route and
     * the other pedestrians follow him (fn_vehicleRoute; cross-country only in
     * contact or for the last few hundred metres). */
    private _pedestrians = _members select {vehicle _x isEqualTo _x};
    if (_pedestrians isNotEqualTo []) then {
        private _guide = if (_leader in _pedestrians) then {_leader} else {_pedestrians # 0};
        if !([_guide,_group,_position,_pedestrians] call NeroAI_fnc_vehicleRoute) then {{_x doMove _position;} forEach _pedestrians;};
        _issued = _issued+1;
    };
    if (_issued <= 0) exitWith {[false,"Нет доступного исполнителя движения: водитель другой группы, доставка или блокированный путь."]};
    _group setVariable ["NeroAI_vehicleState", "MOVING", true];
    [true, format ["Движение назначено %1 машине(ам).", count _mountedVehicles]]
};

/* 7.10: AIR_TRANSPORT squads travel in their own helicopter. Live they rode
 * other groups' ground vehicles, so every TRANSPORT task was refused
 * ("Отряд должен быть пешим") and both Mi-8s stood idle all session. */
if (_mode isEqualTo "BOARD" && {(_group getVariable ["NeroWL_role",""]) == "AIR_TRANSPORT"} && {missionNamespace getVariable ["NeroAI_airEnabled",true]}) exitWith {
    [false, "Транспортная группа перемещается своим вертолётом, а не наземной техникой."]
};

private _isFriendlyVehicle = {
    params ["_vehicle"];
    private _vehicleSide = [_vehicle] call NeroAI_fnc_getVehicleSide;
    (_vehicleSide isEqualTo _friendlySide) || {(_friendlySide getFriend _vehicleSide) >= 0.6}
};

private _isUsableVehicle = {
    params ["_vehicle"];
    (_vehicle isKindOf "LandVehicle" || {_vehicle isKindOf "Air"} || {_vehicle isKindOf "Ship"}) &&
    {!(_vehicle isKindOf "StaticWeapon")} &&
    {(count (fullCrew [_vehicle, "", true])) > 0}
};

private _leaderVehicle = vehicle _leader;
private _transports = [];
if (_leaderVehicle != _leader && {alive _leaderVehicle} && {canMove _leaderVehicle} && {[_leaderVehicle] call _isFriendlyVehicle} && {[_leaderVehicle] call _isUsableVehicle}) then {
    _transports pushBack _leaderVehicle;
};

private _hasOrderedPosition = _position isEqualType [] && {count _position >= 2};
private _searchCenter = if (_hasOrderedPosition) then {_position} else {getPosATL _leader};
private _searchRadius = if (_hasOrderedPosition) then {140} else {250};
private _candidates = vehicles select {
    alive _x && {canMove _x} &&
    {((count crew _x) isEqualTo 0) ||
      {(_x isEqualTo _onlyVehicle) &&
       {(_x in (_group getVariable ["BIS_WL_groupVehs", []])) ||
        {(_x getVariable ["BIS_WL_itemOwner", objNull]) in _members}}}} &&
    {_x distance2D _searchCenter <= _searchRadius} && {_x distance2D _leader <= 600} && {[_x] call _isFriendlyVehicle} && {[_x] call _isUsableVehicle}
};
/* 4.5.1: an own-vehicle boarding (fn_autoRequisition) targets exactly that
 * vehicle — at a base with five fresh airdrops a squad must not scatter one
 * man per tank across everybody's purchases. */
if (!isNull _onlyVehicle) then { _candidates = _candidates select {_x isEqualTo _onlyVehicle}; };
private _ranked = [];
{
    private _seatCount = count (fullCrew [_x, "", true]);
    private _needed = count _members;
    private _priority = (if (_seatCount >= _needed) then {0} else {500}) + (if (canFire _x) then {-100} else {0});
    if (_leaderVehicle != _leader && {typeOf _x isEqualTo typeOf _leaderVehicle}) then {_priority = -1;};
    _ranked pushBack [(_priority * 1000) + (_x distance2D _searchCenter), _x];
} forEach _candidates;
_ranked sort true;
{
    private _vehicle = _x # 1;
    if !(_vehicle in _transports) then {_transports pushBack _vehicle;};
    if ((count _transports) >= 6) exitWith {};
} forEach _ranked;

if (_transports isEqualTo []) exitWith {
    _group setVariable ["NeroAI_vehicleState", "NO_FREE_VEHICLE_NEARBY", true];
    ["INFO", format ["%1 found no free compatible vehicle near the ordered search point.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
    [false, "Свободной дружественной техники нужного класса рядом с указанной точкой нет."]
};

private _unboarded = [_leader] + (_members select {_x != _leader && {vehicle _x isEqualTo _x}});
if (vehicle _leader != _leader) then {_unboarded deleteAt 0;};
if (_unboarded isEqualTo []) exitWith {
    _group setVariable ["NeroAI_vehicleState", "MOUNTED", true];
    [true, "Все бойцы уже находятся в технике."]
};
private _assigned = [];
private _assignmentPairs = [];
{
    private _vehicle = _x;
    private _freeSeats = (fullCrew [_vehicle, "", true]) select {
        isNull (_x param [0, objNull]) && {isNull (_x param [5, objNull])}
    };
    _group addVehicle _vehicle;
    /* 4.5.1 seat order: a vehicle without a driver is a parked pillbox — live
     * 22:26-22:40 a lone leader kept taking the ZSU-23's commander seat and the
     * group never moved. Driver first for everyone but a leader who has other
     * men to drive him; the leader commands, the rest gun and ride. */
    private _toSeat = _unboarded select {!(_x in _assigned)};
    private _leaderHasCrew = (count _toSeat) > 1;
    {
        private _member = _x;
        private _rankedSeats = [];
        {
            private _seatRole = toLower (_x param [1, ""]);
            private _seatPriority = if (_member isEqualTo _leader) then {
                if (_leaderHasCrew) then {["commander", "gunner", "driver", "turret", "cargo"] find _seatRole}
                else {["driver", "commander", "gunner", "turret", "cargo"] find _seatRole}
            } else {
                ["driver", "gunner", "turret", "cargo", "commander"] find _seatRole
            };
            if (_seatPriority < 0) then {_seatPriority = 9;};
            _rankedSeats pushBack [_seatPriority + (_forEachIndex / 100), _forEachIndex];
        } forEach _freeSeats;
        _rankedSeats sort true;
        private _seatAssigned = false;
        if !(_rankedSeats isEqualTo []) then {
            private _seatIndex = (_rankedSeats # 0) # 1;
            private _seat = _freeSeats # _seatIndex;
            private _seatRole = toLower (_seat param [1, ""]);
            switch (_seatRole) do {
                case "commander": {_member assignAsCommander _vehicle; _seatAssigned = true;};
                case "driver": {_member assignAsDriver _vehicle; _seatAssigned = true;};
                case "gunner": {_member assignAsGunner _vehicle; _seatAssigned = true;};
                case "turret": {_member assignAsTurret [_vehicle, _seat param [3, []]]; _seatAssigned = true;};
                case "cargo": {_member assignAsCargoIndex [_vehicle, _seat param [2, -1]]; _seatAssigned = true;};
            };
            if (_seatAssigned) then {_freeSeats deleteAt _seatIndex;};
        };
        if (_seatAssigned) then {
            _assigned pushBack _member;
            _assignmentPairs pushBack [_member, _vehicle];
        };
    } forEach (_unboarded select {!(_x in _assigned)});
} forEach _transports;

private _remaining = _unboarded select {!(_x in _assigned)};
if (_assigned isEqualTo []) exitWith {
    _group setVariable ["NeroAI_vehicleState", "BOARDING_FAILED", true];
    [false, "Не удалось зарезервировать ни одного свободного места."]
};

_assigned allowGetIn true;
_assigned orderGetIn true;
private _isPartial = !(_remaining isEqualTo []);
private _opToken = _group getVariable ["NeroAI_opToken", 0];

/* Assignment is only an intention in Arma. Confirm the actual vehicle of
 * every unit before declaring success, retry the native get-in order for
 * the distance-based window (45 s + dist/1.5 m/s, capped at 240 s), and
 * expose the measured result to the live console. */
private _maxDist = 0;
{
    private _u = _x # 0;
    private _v = _x # 1;
    if (!isNull _u && {!isNull _v}) then {
        _maxDist = _maxDist max (_u distance2D _v);
    };
} forEach _assignmentPairs;
private _waitSec = ((45 + (_maxDist / 1.5)) min 240) max 45;

[_group, +_assignmentPairs, _opToken, _isPartial, _waitSec] spawn {
    params ["_boardingGroup", "_pairs", "_token", "_isPartial", "_waitSec"];
    private _deadline = diag_tickTime + _waitSec;
    private _lastRetry = -10;
    private _finished = false;
    while {diag_tickTime < _deadline && {!_finished} && {!isNull _boardingGroup}} do {
        if ((_boardingGroup getVariable ["NeroAI_opToken", 0]) != _token) exitWith { _finished = false; };
        private _validPairs = _pairs select {
            private _unit = _x # 0;
            private _vehicle = _x # 1;
            !isNull _unit && {alive _unit} && {!isNull _vehicle} && {alive _vehicle} && {canMove _vehicle}
        };
        private _mountedPairs = _validPairs select {vehicle (_x # 0) isEqualTo (_x # 1)};
        _finished = !(_validPairs isEqualTo []) && {(count _mountedPairs) isEqualTo (count _validPairs)};
        if (!_finished && {(diag_tickTime - _lastRetry) >= 10}) then {
            private _retry = (_validPairs select {vehicle (_x # 0) != (_x # 1)}) apply {_x # 0};
            if !(_retry isEqualTo []) then {
                _retry allowGetIn true;
                _retry orderGetIn true;
            };
            _lastRetry = diag_tickTime;
        };
        if (!_finished) then {uiSleep 2;};
    };

    if (!isNull _boardingGroup && {(_boardingGroup getVariable ["NeroAI_opToken", 0]) isEqualTo _token}) then {
        private _validPairs = _pairs select {
            private _unit = _x # 0;
            private _vehicle = _x # 1;
            !isNull _unit && {alive _unit} && {!isNull _vehicle} && {alive _vehicle}
        };
        private _mounted = {_x isEqualType [] && {count _x >= 2} && {vehicle (_x # 0) isEqualTo (_x # 1)}} count _validPairs;
        private _expected = count _validPairs;
        private _callsign = _boardingGroup getVariable ["NeroAI_callsign", groupId _boardingGroup];
        private _state = if (_expected > 0 && {_mounted isEqualTo _expected} && {!_isPartial}) then {"MOUNTED"} else {if (_mounted > 0) then {"PARTIAL_MOUNTED"} else {"BOARDING_FAILED"}};
        _boardingGroup setVariable ["NeroAI_vehicleState", _state, true];
        _boardingGroup setVariable ["NeroWL_logisticsUntil",0];
        if (_state=="MOUNTED") then {_boardingGroup setVariable ["NeroAI_autoBoardTries",[objNull,0],true];};
        // A partial result is still a failed attempt for those left outside.
        // Release their stale seat assignments so the next native order can run.
        {if (alive (_x # 0) && {vehicle (_x # 0) != (_x # 1)}) then {unassignVehicle (_x # 0);};} forEach _validPairs;
        [if (_state isEqualTo "MOUNTED") then {"INFO"} else {"WARN"}, format ["%1 boarding verified: %2/%3 members actually mounted; state=%4.", _callsign, _mounted, _expected, _state]] call NeroAI_fnc_log;
        if !(_state isEqualTo "MOUNTED") then {
            [leader _boardingGroup, format ["%1: посадка не завершена, в технике %2 из %3 бойцов.", _callsign, _mounted, _expected], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
        };
    };
};

_group setVariable ["NeroWL_logisticsUntil",diag_tickTime+_waitSec+5];
_group setVariable ["NeroAI_vehicleState", if (!_isPartial) then {"BOARDING"} else {"PARTIAL_BOARDING"}, true];
["INFO", format ["%1 started boarding: seats assigned to %2/%3 members across %4 compatible vehicle(s); awaiting physical-entry verification.", _group getVariable ["NeroAI_callsign", groupId _group], count _assigned, count _unboarded, count _transports]] call NeroAI_fnc_log;
[!_isPartial, if (!_isPartial) then {format ["Посадка начата для %1 бойцов; ожидается подтверждение фактической посадки.", count _assigned]} else {format ["Посадка начата частично: места назначены %1 из %2 бойцов.", count _assigned, count _unboarded]}]
