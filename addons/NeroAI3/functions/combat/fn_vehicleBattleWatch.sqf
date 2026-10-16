/* Slow server loop over owned ground assets; no global hostile enumeration. */
if (!isServer || {!(missionNamespace getVariable ["NeroAI_rulesMode",false])}) exitWith {};
if !(missionNamespace getVariable ["NeroAI_fieldRepairEnabled",true]) exitWith {};
private _seen = [];private _now = diag_tickTime;
{
    private _parent = _y;
    if ([_parent] call NeroAI_fnc_validateGroup) then {
        private _vehicles = +(_parent getVariable ["BIS_WL_groupVehs",[]]);
        {private _v = objectParent _x;if (!isNull _v) then {_vehicles pushBackUnique _v;};} forEach units _parent;
        {
            private _vehicle = _x;
            if (!isNull _vehicle && {alive _vehicle} && {local _vehicle} && {_vehicle isKindOf "LandVehicle"}
                && {!(_vehicle isKindOf "StaticWeapon")} && {!(_vehicle in _seen)} && {isNull attachedTo _vehicle}
                && {((crew _vehicle) findIf {isPlayer _x}) < 0}
                && {(getPosATL _vehicle # 2) < 3}) then {
                _seen pushBack _vehicle;
                if !(_vehicle getVariable ["NeroWL_hitWatcher",false]) then {
                    _vehicle addEventHandler ["Hit",{(_this # 0) setVariable ["NeroWL_lastVehicleHit",diag_tickTime];}];
                    _vehicle setVariable ["NeroWL_hitWatcher",true];
                };
                private _lease = _vehicle getVariable ["NeroWL_repairLease",[]];
                if (count _lease >= 3 && {_now >= (_lease # 2)}) then {[_vehicle,_lease] call NeroAI_fnc_repairRelease;_lease = [];};
                private _group = if (isNull driver _vehicle) then {_parent} else {group driver _vehicle};
                if ([_group] call NeroAI_fnc_validateGroup && {_lease isEqualTo []} && {_now >= (_group getVariable ["NeroWL_repairNext",0])}) then {
                    private _hits = getAllHitPointsDamage _vehicle;
                    private _priority = [_hits param [0,[]],_hits param [2,[]]] call NeroAI_fnc_damagePriority;
                    private _damaged = !canMove _vehicle || {damage _vehicle > 0.6} || {(_priority findIf {(_x # 0) >= 80}) >= 0};
                    _vehicle setVariable ["NeroWL_needsRepair",_damaged,true];
                    private _manual = _group getVariable ["NeroAI_playerHold",false] || {_now < (_group getVariable ["NeroAI_manualOrderUntil",0])}
                        || {_now < (_group getVariable ["NeroWL_logisticsUntil",0])} || {_now < (_group getVariable ["NeroAI_purchaseHoldUntil",0])};
                    private _engineer = ((units _group) select {[_x] call NeroAI_fnc_fieldEngineer}) param [0,objNull];
                    private _tools = !isNull _engineer && {"ToolKit" in items _engineer || {"ToolKit" in itemCargo _vehicle}};
                    if (!isNull _engineer && {!isNil "ace_repair_fnc_getRepairItems"} && {!isNil "ace_repair_fnc_hasItems"}) then {
                        private _items = [configFile >> "ACE_Repair" >> "Actions" >> "MiscRepair"] call ace_repair_fnc_getRepairItems;
                        _tools = _tools || {[_engineer,_items] call ace_repair_fnc_hasItems};
                    };
                    private _threat = [_group,_vehicle] call NeroAI_fnc_repairThreat;
                    private _cover = [_group,_vehicle] call NeroAI_fnc_repairCover;
                    private _decision = [_damaged,canMove _vehicle,_threat # 0,_threat # 1,!isNull _engineer,_tools,_cover,_manual,damage _vehicle >= 0.85] call NeroAI_fnc_repairDecision;
                    _vehicle setVariable ["NeroWL_repairDecision",[_now,_decision],true];
                    switch (_decision) do {
                        case "REPAIR": {[_group,_vehicle,"AUTONOMY"] call NeroAI_fnc_repairVehicle;};
                        case "REQUEST_ENGINEER": {[_group,getPosATL _vehicle,"REPAIR",_vehicle] call NeroAI_fnc_requestSupport;_group setVariable ["NeroWL_vehicleService",true,true];};
                        case "WAIT_COVER": {[_group,getPosATL _vehicle,"COVER"] call NeroAI_fnc_requestSupport;_group setVariable ["NeroWL_vehicleService",true,true];};
                        case "NEED_TOOLS": {_group setVariable ["NeroWL_vehicleService",true,true];_group setVariable ["NeroAI_repairStatus","NEED_TOOLS",true];[_group,getPosATL _vehicle,"REPAIR",_vehicle] call NeroAI_fnc_requestSupport;};
                        case "WITHDRAW": {
                            [_group,getPosATL _vehicle,"COVER"] call NeroAI_fnc_requestSupport;
                            private _own = (missionNamespace getVariable ["BIS_WL_sectors",[]]) select {(_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo side _group};
                            private _safe = objNull;private _distance = 1e9;
                            {private _d = _x distance2D _vehicle;if (_d < _distance && {_d > 80}) then {_safe = _x;_distance = _d;};} forEach _own;
                            if (!isNull _safe) then {_group setVariable ["NeroWL_vehicleService",false,true];private _retreat = [_group,"RETREAT",getPosATL _safe,"","AUTONOMY"] call NeroAI_fnc_executeMacro;if (_retreat # 0) then {_group setVariable ["NeroWL_logisticsUntil",_now+25];};_group setVariable ["NeroWL_repairNext",_now+20];};
                        };
                        case "EVACUATE": {[_group,_vehicle] call NeroAI_fnc_vehicleEvacuate;_group setVariable ["NeroWL_repairNext",_now+120];};
                        case "IGNORE": {_group setVariable ["NeroWL_vehicleService",false,true];};
                        default {};
                    };
                };
            };
        } forEach _vehicles;
    };
} forEach NeroAI_activeGroups;
