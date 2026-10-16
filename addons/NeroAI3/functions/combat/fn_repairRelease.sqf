/* Also called by the slow watchdog after an expired worker lease. */
params ["_vehicle","_lease"];
if ((_vehicle getVariable ["NeroWL_repairLease",[]]) isNotEqualTo _lease) exitWith {false};
private _held = _vehicle getVariable ["NeroWL_repairHeld",[[],-1,false]];
{
    _x params ["_group","_oldUntil","_claimedUntil"];
    if (!isNull _group && {(_group getVariable ["NeroWL_logisticsUntil",0]) == _claimedUntil}) then {_group setVariable ["NeroWL_logisticsUntil",_oldUntil];};
    if (!isNull _group && {(_group getVariable ["NeroWL_vehicleServiceLease",[]]) isEqualTo _lease}) then {
        _group setVariable ["NeroWL_vehicleService",false,true];
        _group setVariable ["NeroWL_vehicleServiceLease",nil];
        _group setVariable ["NeroWL_repairVehicle",nil];
    };
} forEach (_held # 0);
if (local _vehicle && {getForcedSpeed _vehicle == 0}) then {_vehicle forceSpeed (_held # 1);};
if (count _lease > 4 && {(_held param [2,false])} && {local _vehicle} && {alive _vehicle}
    && {((_lease # 3) getVariable ["NeroAI_opToken",0]) == (_lease # 4)}) then {_vehicle engineOn true;};
_vehicle setVariable ["NeroWL_repairLease",nil];_vehicle setVariable ["NeroWL_repairHeld",nil];
true
