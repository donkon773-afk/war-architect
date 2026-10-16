/* Serialize Warlords vehicle purchases across every commander on one side.
 * Call only after the native FSM / NeroAI purchase path has confirmed that an
 * affordable asset is ready to order. */
params ["_group",["_kind","VEHICLE"],["_ground",false]];
if (!isServer || {isNull _group}) exitWith {false};
if (([_kind] call NeroAI_fnc_designPurchaseCapacity)<=0) exitWith {false};
private _sideKey = str (side _group);
private _now = diag_tickTime;
private _cooldown = missionNamespace getVariable ["NeroAI_purchaseSideCooldownSeconds", 75];
if (_ground) then {_cooldown = _cooldown min (missionNamespace getVariable [if (_kind == "INFANTRY") then {"NeroWL_baseInfantryInterval"} else {"NeroWL_baseVehicleInterval"},if (_kind == "INFANTRY") then {8} else {25}]);};
private _claimed = false;
isNil {
    private _nextAllowed = missionNamespace getVariable ["NeroAI_purchaseSideNextAllowed", createHashMap];
    if !(_nextAllowed isEqualType createHashMap) then {_nextAllowed = createHashMap;};
    if (_now >= (_nextAllowed getOrDefault [_sideKey, 0])) then {
        _nextAllowed set [_sideKey, _now + _cooldown];
        missionNamespace setVariable ["NeroAI_purchaseSideNextAllowed", _nextAllowed];
        _group setVariable ["NeroAI_purchaseHoldUntil", _now + _cooldown, true];
        _claimed = true;
    };
};
_claimed
