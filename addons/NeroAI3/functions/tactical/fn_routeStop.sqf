/* Cancel only NeroAI route workers. Never touch the group's native waypoints. */
params ["_group"];
if (!isServer || {isNull _group} || {!local _group}) exitWith {-1};
private _epoch = (_group getVariable ["NeroWL_routeEpoch",0]) + 1;
_group setVariable ["NeroWL_routeEpoch",_epoch];
{
    if (!isNull _x && {private _owner = _x getVariable ["NeroWL_motionOwner",[]];_owner isEqualTo [] || {(_owner # 0) isEqualTo _group}}) then {
        [_x] call NeroAI_fnc_motionRestore;
        _x setVariable ["NeroWL_motionOwner",nil];
        _x setVariable ["NeroWL_motionState","CANCELLED",true];
        private _handle = _x getVariable ["NeroWL_routeScript",scriptNull];
        if (!isNull _handle && {!scriptDone _handle}) then {terminate _handle;};
        private _agent = _x getVariable ["NeroWL_pathAgent",objNull];
        if (!isNull _agent) then {deleteVehicle _agent;};
        private _key = _x getVariable ["NeroWL_pathKey",""];
        if (_key isNotEqualTo "") then {missionNamespace setVariable [_key,nil];};
        private _mover = _x;
        {_mover setVariable [_x,nil];} forEach ["NeroWL_routeScript","NeroWL_routeTarget","NeroWL_pathAgent","NeroWL_pathKey"];
    };
} forEach (_group getVariable ["NeroWL_routeMovers",[]]);
_group setVariable ["NeroWL_routeMovers",[]];
_group setVariable ["NeroWL_routeOrderType",nil];
_group setVariable ["NeroWL_routeState","CANCELLED",true];
private _danger = _group getVariable ["NeroWL_routeDangerBefore",[]];
if (_danger isNotEqualTo []) then {_group setVariable ["lambs_danger_disableGroupAI",_danger # 0];};
_group setVariable ["NeroWL_routeDangerBefore",nil];
_epoch
