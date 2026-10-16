/*
 * Server-side, deterministic mobility safety net.  It does not teleport AI or
 * erase waypoints: it only observes a NeroAI movement order, reissues that
 * same order after a sustained stall. Vehicle proximity is telemetry only:
 * scenario speed limits are not overwritten. State is exposed in buildSnapshot.
 */
if (!isServer) exitWith {};
private _now = diag_tickTime;

{
    private _group = _y;
    if ([_group] call NeroAI_fnc_validateGroup) then {
        private _leader = leader _group;
        private _position = getPosATL _leader;
        private _order = _group getVariable ["NeroAI_lastPlayerOrder", []];
        private _orderType = if (_order isEqualType [] && {count _order >= 4}) then {_order # 0} else {""};
        private _target = if (_order isEqualType [] && {count _order >= 4}) then {_order # 1} else {[]};
        private _orderedAt = if (_order isEqualType [] && {count _order >= 4}) then {_order # 3} else {0};
        private _routerOwns = ((_group getVariable ["NeroWL_routeMovers",[]]) findIf {
            !isNull _x && {!scriptDone (_x getVariable ["NeroWL_routeScript",scriptNull])}
        }) >= 0;
        private _routerTerminal = (_group getVariable ["NeroWL_routeState",""]) in ["BLOCKED","BLOCKED_TERRAIN","DAMAGED"] && {(_group getVariable ["NeroWL_routeBlockedPlayerToken",-1]) == (_group getVariable ["NeroAI_opToken",0])};
        private _isMoveOrder = _orderType in ["ADVANCE", "ASSAULT", "RETREAT"] && {!_routerOwns} && {!_routerTerminal};
        private _hasTarget = _target isEqualType [] && {count _target >= 2};
        private _old = _group getVariable ["NeroAI_mobility", ["IDLE", _position, _now, -60, 0, []]];
        private _window = _group getVariable ["NeroAI_mobilityWindow", [_position, _now, _orderedAt]];
        private _oldPosition = _window # 0;
        private _oldAt = _window # 1;
        private _lastRecovery = _old param [3, -60];
        private _stallCount = _old param [4, 0];
        private _state = "IDLE";
        private _stalled = false;
        if ((_window # 2) != _orderedAt) then {
            _oldPosition = _position;
            _oldAt = _now;
            _stallCount = 0;
            _lastRecovery = -60;
        };

        if (_isMoveOrder && {_hasTarget} && {_now < (_group getVariable ["NeroAI_manualOrderUntil", 0])} && {!(_group getVariable ["NeroAI_playerHold", false])}) then {
            private _remaining = _leader distance2D _target;
            private _travelled = _position distance2D _oldPosition;
            private _elapsed = _now - _oldAt;
            _state = "MOVING";
            if (_remaining > 35 && {_elapsed >= 25} && {_travelled < 6}) then {
                _stalled = true;
                _state = "STALLED";
                if ((_now - _lastRecovery) >= 35 && {_stallCount < 3}) then {
                    private _retry = [_group, _orderType, _target, "", "MOBILITY_RETRY"] call NeroAI_fnc_executeMacro;
                    _lastRecovery = _now;
                    _stallCount = _stallCount + 1;
                    _state = if (_retry # 0) then {"RECOVERING"} else {"IDLE"};
                    _oldPosition = _position;
                    _oldAt = _now;
                    ["WARN", format ["%1 mobility watchdog reissued %2 after %3 stalled sample(s).", _group getVariable ["NeroAI_callsign", groupId _group], _orderType, _stallCount]] call NeroAI_fnc_log;
                };
            };
            if (_travelled >= 6 || {_remaining <= 35}) then {
                _oldPosition = _position;
                _oldAt = _now;
            };
        } else {
            _oldPosition = _position;
            _oldAt = _now;
        };
        _group setVariable ["NeroAI_mobilityWindow", [_oldPosition, _oldAt, _orderedAt]];

        private _leaderVehicle = vehicle _leader;
        private _collisionRisk = false;
        if (_leaderVehicle != _leader && {alive _leaderVehicle} && {speed _leaderVehicle > 5}) then {
            {
                private _other = _y;
                if (_other != _group && {[_other] call NeroAI_fnc_validateGroup}) then {
                    private _otherVehicle = vehicle (leader _other);
                    if (_otherVehicle != leader _other && {_otherVehicle != _leaderVehicle} && {speed _otherVehicle > 5} && {_leaderVehicle distance2D _otherVehicle < 22}) exitWith {
                        _collisionRisk = true;
                    };
                };
            } forEach NeroAI_activeGroups;
            if (_collisionRisk) then {
                _state = if (_stalled) then {_state} else {"COLLISION_RISK"};
            };
        };

        private _separated = {(alive _x) && {vehicle _x isEqualTo _x} && {_x distance2D _leader > 110}} count units _group;
        _group setVariable ["NeroAI_mobility", [_state, _position, _now, _lastRecovery, _stallCount, [_separated, _collisionRisk]], true];
    };
} forEach NeroAI_activeGroups;
