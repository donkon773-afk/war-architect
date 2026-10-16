/* AI-owned progress for the installed ACE repair contract. The normal public
 * repair entry opens the player's progress dialog, so it cannot run on server AI.
 * ACE itself checks training/items/location and applies its damage/spare rules.
 * Internal completion callbacks are version-sensitive; fail if unavailable. */
params ["_engineer","_vehicle","_index","_action","_group","_token","_lease"];
private _required = ["ace_repair_fnc_canRepair","ace_repair_fnc_getRepairItems","ace_repair_fnc_useItems","ace_repair_fnc_getClaimObjects","ace_common_fnc_claim","ace_repair_fnc_repair_success","ace_repair_fnc_repair_failure"];
if ((_required findIf {isNil _x}) >= 0) exitWith {[false,"ACE_ADAPTER_UNAVAILABLE"]};
if !([_engineer,_vehicle,_index,_action] call ace_repair_fnc_canRepair) exitWith {[false,"ACE_REQUIREMENTS_NOT_MET"]};
private _cfg = configFile >> "ACE_Repair" >> "Actions" >> _action;
private _items = [_cfg] call ace_repair_fnc_getRepairItems;
private _objects = getArray (_cfg >> "claimObjects");
private _claimed = if (_objects isEqualTo []) then {[]} else {[_engineer,5,_objects,true] call ace_repair_fnc_getClaimObjects};
if (_objects isNotEqualTo [] && {_claimed isEqualTo []}) exitWith {[false,"NEED_SPARE_PARTS"]};
{[_engineer,_x,false] call ace_common_fnc_claim;} forEach _claimed;
private _consume = if (isNumber (_cfg >> "itemConsumed")) then {getNumber (_cfg >> "itemConsumed")} else {missionNamespace getVariable [getText (_cfg >> "itemConsumed"),0]};
private _users = [];private _haveItems = true;
if (_consume > 0) then {private _used = [_engineer,_items] call ace_repair_fnc_useItems;_haveItems = _used # 0;_users = _used # 1;};
private _args = [_engineer,_vehicle,_index,_action,_items,_users,_claimed];
if (!_haveItems) exitWith {[_args] call ace_repair_fnc_repair_failure;[false,"NEED_TOOLS"]};
private _seconds = if (isNumber (_cfg >> "repairingTime")) then {getNumber (_cfg >> "repairingTime")} else {missionNamespace getVariable [getText (_cfg >> "repairingTime"),30]};
private _override = configOf _vehicle >> "ace_repair_repairTimes" >> _action;
if (isNumber _override) then {_seconds = getNumber _override;};
if !(_seconds isEqualType 0) exitWith {[_args] call ace_repair_fnc_repair_failure;[false,"ACE_UNSUPPORTED_REPAIR_TIME"]};
private _deadline = diag_tickTime+(_seconds max 0);
if (_deadline > (_lease # 2)) exitWith {[_args] call ace_repair_fnc_repair_failure;[false,"ACE_TIME_EXCEEDS_WINDOW"]};
private _safe = true;
_engineer playMoveNow "Acts_carFixingWheel";
waitUntil {
    sleep 0.5;
    private _threat = [_group,_vehicle] call NeroAI_fnc_repairThreat;
    _safe = alive _engineer && {lifeState _engineer in ["HEALTHY","INJURED"]} && {!(_engineer getVariable ["ACE_isUnconscious",false])}
        && {alive _vehicle} && {local _vehicle} && {!isPlayer _engineer} && {_engineer distance2D _vehicle < 7}
        && {abs speed _vehicle < 1} && {(_group getVariable ["NeroAI_opToken",0]) == _token}
        && {(_vehicle getVariable ["NeroWL_repairLease",[]]) isEqualTo _lease}
        && {[_group getVariable ["NeroAI_opToken",0],_token,_lease # 2,diag_tickTime,true,true,(_lease # 3) getVariable ["NeroAI_opToken",0],_lease # 4] call NeroAI_fnc_repairLeaseValid}
        && {(_threat # 0) >= 200} && {(_threat # 1) >= 20}
        && {(_threat # 0) >= 600 || {[_group,_vehicle] call NeroAI_fnc_repairCover}}
        && {(_claimed findIf {!alive _x || {(_x getVariable ["ace_common_owner",objNull]) != _engineer}}) < 0};
    !_safe || {diag_tickTime >= _deadline}
};
if (!_safe) exitWith {[_args] call ace_repair_fnc_repair_failure;[false,"INTERRUPTED"]};
[_args] call ace_repair_fnc_repair_success;
[true,"ACE_STEP_COMPLETED"]
