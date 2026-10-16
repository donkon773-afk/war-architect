/* One engineer, one vehicle lease, bounded work and actual seat restoration. */
params ["_group","_vehicle","_engineer","_token","_lease"];
private _seatVehicle = objectParent _engineer;
private _seat = assignedVehicleRole _engineer;
private _current = {
    !isNull _group && {[_group] call NeroAI_fnc_validateGroup} && {alive _engineer} && {local _engineer} && {!isPlayer _engineer}
    && {alive _vehicle} && {local _vehicle} && {(_group getVariable ["NeroAI_opToken",0]) == _token}
    && {(_vehicle getVariable ["NeroWL_repairLease",[]]) isEqualTo _lease}
    && {[_group getVariable ["NeroAI_opToken",0],_token,_lease # 2,diag_tickTime,true,lifeState _engineer in ["HEALTHY","INJURED"] && {!(_engineer getVariable ["ACE_isUnconscious",false])},(_lease # 3) getVariable ["NeroAI_opToken",0],_lease # 4] call NeroAI_fnc_repairLeaseValid}
};
private _status = "INTERRUPTED";private _progress = false;
if (call _current) then {
    if (!isNull _seatVehicle) then {unassignVehicle _engineer;[_engineer] orderGetIn false;doGetOut _engineer;};
    private _outUntil = diag_tickTime+15;
    waitUntil {sleep 0.5;!(call _current) || {isNull objectParent _engineer} || {diag_tickTime >= _outUntil}};
    if (call _current && {isNull objectParent _engineer}) then {
        private _workPos = _vehicle getRelPos [4,270];
        _engineer doMove _workPos;
        private _reachUntil = diag_tickTime+40;
        waitUntil {sleep 1;!(call _current) || {_engineer distance2D _vehicle < 6} || {diag_tickTime >= _reachUntil}};
        if (call _current && {_engineer distance2D _vehicle < 6}) then {
            doStop _engineer;
            /* Transfer a real toolkit if inventory space permits. No duplication. */
            if (!("ToolKit" in items _engineer) && {"ToolKit" in itemCargo _vehicle} && {_engineer canAdd "ToolKit"}) then {
                _vehicle addItemCargoGlobal ["ToolKit",-1];_engineer addItem "ToolKit";
            };
            private _end = (diag_tickTime+150) min (_lease # 2);
            private _steps = 0;private _continue = true;
            while {_continue && {call _current} && {_steps < 4} && {diag_tickTime < _end}} do {
                private _threat = [_group,_vehicle] call NeroAI_fnc_repairThreat;
                if !([call _current,_threat # 0,_threat # 1,[_group,_vehicle] call NeroAI_fnc_repairCover,speed _vehicle] call NeroAI_fnc_repairWorkSafe) exitWith {_status = "UNSAFE_UNDER_FIRE";};
                private _hits = getAllHitPointsDamage _vehicle;
                private _priorities = [_hits param [0,[]],_hits param [2,[]]] call NeroAI_fnc_damagePriority;
                if (_priorities isEqualTo []) exitWith {_status = if (canMove _vehicle) then {"MOBILITY_CONFIRMED"} else {"NO_REPAIRABLE_COMPONENT"};};
                _steps = _steps+1;
                private _index = (_priorities # 0) # 1;
                private _before = _vehicle getHitIndex _index;
                if (isClass (configFile >> "CfgPatches" >> "ace_repair")) then {
                    private _name = toLower ((_priorities # 0) # 2);
                    private _action = if ("track" in _name) then {"RepairTrack"} else {if ("wheel" in _name) then {"ReplaceWheel"} else {"MiscRepair"}};
                    private _step = [_engineer,_vehicle,_index,_action,_group,_token,_lease] call NeroAI_fnc_aceRepairStep;
                    _status = _step # 1;
                    if !(_step # 0) then {_continue = false;};
                    sleep 1;
                } else {
                    if !("ToolKit" in items _engineer) exitWith {_status = "NEED_TOOLS";_continue = false;};
                    _engineer action ["RepairVehicle",_vehicle];
                    private _until = (diag_tickTime+45) min _end;
                    private _safe = true;
                    waitUntil {
                        sleep 1;
                        private _t = [_group,_vehicle] call NeroAI_fnc_repairThreat;
                        _safe = [call _current,_t # 0,_t # 1,[_group,_vehicle] call NeroAI_fnc_repairCover,speed _vehicle] call NeroAI_fnc_repairWorkSafe;
                        !_safe || {_vehicle getHitIndex _index < _before-0.02} || {diag_tickTime >= _until}
                    };
                    if (!_safe && {call _current}) then {_engineer action ["CancelAction",_engineer];_continue = false;_status = "UNSAFE_UNDER_FIRE";};
                };
                if (call _current) then {
                    if (_vehicle getHitIndex _index < _before-0.02) then {_progress = true;_status = "COMPONENT_PROGRESS_CONFIRMED";} else {_continue = false;};
                    if (canMove _vehicle && {_progress}) then {_continue = false;_status = "MOBILITY_CONFIRMED";};
                };
            };
        } else {_status = "ENGINEER_COULD_NOT_REACH";};
    } else {_status = "ENGINEER_COULD_NOT_EXIT";};
};
/* Restore the original seat by a real get-in order only while this operation
 * still owns the engineer. A newer player order never gets overwritten. */
if (call _current) then {_engineer action ["CancelAction",_engineer];};
if (call _current && {!isNull _seatVehicle} && {alive _seatVehicle} && {count _seat > 0}) then {
    _engineer action ["CancelAction",_engineer];
    switch (toLower (_seat # 0)) do {
        case "driver": {_engineer assignAsDriver _seatVehicle;};
        case "commander": {_engineer assignAsCommander _seatVehicle;};
        case "gunner": {_engineer assignAsGunner _seatVehicle;};
        case "turret": {_engineer assignAsTurret [_seatVehicle,_seat param [1,[]]];};
        case "cargo": {_engineer assignAsCargo _seatVehicle;};
    };
    [_engineer] allowGetIn true;[_engineer] orderGetIn true;
    private _boardUntil = diag_tickTime+30;
    waitUntil {sleep 1;!(call _current) || {vehicle _engineer isEqualTo _seatVehicle} || {diag_tickTime >= _boardUntil}};
    if (call _current && {vehicle _engineer != _seatVehicle}) then {_status = _status+"_CREW_NOT_REBOARDED";};
};
if ((_vehicle getVariable ["NeroWL_repairLease",[]]) isEqualTo _lease) then {
    [_vehicle,_lease] call NeroAI_fnc_repairRelease;
    _group setVariable ["NeroWL_vehicleService",false,true];
    if (_progress && {canMove _vehicle}) then {_vehicle setVariable ["NeroWL_needsRepair",false,true];};
    _group setVariable ["NeroAI_repairStatus",_status,true];
    _group setVariable ["NeroWL_repairNext",diag_tickTime+120];
    private _support = _group getVariable ["NeroAI_supporting",[]];
    if ((_support param [3,""]) isEqualTo "REPAIR") then {_group setVariable ["NeroAI_supporting",nil,true];};
    _vehicle setVariable ["NeroWL_repairResult",[_status,_progress,canMove _vehicle,diag_tickTime],true];
    if ((_group getVariable ["NeroAI_opToken",0]) == _token) then {_group setVariable ["NeroAI_forcePlan",true,true];};
};
["INFO",format ["REPAIR %1 %2 status=%3 progress=%4 mobile=%5",groupId _group,typeOf _vehicle,_status,_progress,canMove _vehicle]] call NeroAI_fnc_log;
