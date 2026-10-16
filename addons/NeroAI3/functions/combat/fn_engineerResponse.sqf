/* A request being accepted does not mean an engineer arrived or repaired. */
params ["_group","_requester","_vehicle"];
private _token = _group getVariable ["NeroAI_opToken",0];
private _deadline = diag_tickTime+170;
waitUntil {
    sleep 2;
    isNull _vehicle || {!alive _vehicle} || {!([_group] call NeroAI_fnc_validateGroup)}
    || {(_group getVariable ["NeroAI_opToken",0]) != _token} || {_group getVariable ["NeroAI_playerHold",false]}
    || {(leader _group) distance2D _vehicle < 60} || {diag_tickTime >= _deadline}
};
if (!isNull _vehicle && {alive _vehicle} && {[_group] call NeroAI_fnc_validateGroup}
    && {(_group getVariable ["NeroAI_opToken",0]) == _token} && {!(_group getVariable ["NeroAI_playerHold",false])}
    && {(leader _group) distance2D _vehicle < 60}) then {
    private _result = [_group,_vehicle,"SUPPORT"] call NeroAI_fnc_repairVehicle;
    ["INFO",format ["REPAIR responder %1 arrived: %2",groupId _group,_result # 1]] call NeroAI_fnc_log;
} else {
    _requester setVariable ["NeroAI_repairStatus","ENGINEER_DID_NOT_ARRIVE",true];
};
