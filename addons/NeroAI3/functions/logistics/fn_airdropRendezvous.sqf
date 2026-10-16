/* Newly delivered recruits use their own road-first march to the original
 * group; no mission squad is deleted or rebuilt. Temporary group owns only
 * these recruits. Original group can continue fighting while they approach. */
params ["_parent","_troops","_id",["_expected",0]];
if (_expected <= 0) then {_expected = count _troops;};
private _side = side _parent;
private _staging = createGroup [_side,true];
if (isNull _staging) exitWith {
    {_x setVariable ["NeroWL_deliveryPending",false,true];} forEach _troops;
    _parent setVariable ["NeroWL_supplyManifest",[],true];
    if (((_parent getVariable ["NeroWL_pendingPurchase",[]]) param [0,""]) == _id) then {_parent setVariable ["NeroWL_pendingPurchase",nil,true];};
    _parent setVariable ["NeroWL_supplyResult",[_id,"NO_STAGING_GROUP",count _troops,_expected,diag_tickTime],true];
    false
};
_staging setVariable ["NeroAI_isBaseAssetCrew",true,true];
_staging setVariable ["NeroAI_active",true,true];
_troops joinSilent _staging;
private _until = diag_tickTime+900;private _next = -1;private _routes = 0;private _joined = [];
while {diag_tickTime < _until && {!isNull _parent} && {alive leader _parent}
    && {((units _staging) findIf {isPlayer _x}) < 0} && {{alive _x} count units _staging > 0}} do {
    private _living = (units _staging) select {alive _x};
    private _near = _living select {_x distance2D leader _parent < 120};
    _near joinSilent _parent;
    {_joined pushBackUnique _x;} forEach (_near select {group _x isEqualTo _parent});
    {_x setVariable ["NeroWL_deliveryPending",false,true];} forEach _near;
    _living = (units _staging) select {alive _x};
    if (_living isEqualTo []) exitWith {};
    if (diag_tickTime >= _next && {_routes < 12}) then {
        _routes = _routes+1;_next = diag_tickTime+60;
        [leader _staging,_staging,getPosATL leader _parent,_living] call NeroAI_fnc_vehicleRoute;
    };
    sleep 2;
};
[_staging] call NeroAI_fnc_routeStop;
private _remaining = (units _staging) select {alive _x};
/* Unreached recruits stay physical: release the temporary role so the normal
 * field manager can enrol them. No teleport and no replacement spawning. */
_staging setVariable ["NeroAI_active",false,true];_staging setVariable ["NeroAI_isBaseAssetCrew",false,true];
{_x setVariable ["NeroWL_deliveryPending",false,true];} forEach _remaining;
private _arrived = {_x in _joined && {alive _x} && {group _x isEqualTo _parent}} count _troops;
private _success = _remaining isEqualTo [];
if (_success) then {deleteGroup _staging;};
_parent setVariable ["NeroWL_supplyManifest",[],true];
_parent setVariable ["NeroWL_supplyResult",[_id,if (_success) then {if (_arrived == _expected) then {"JOINED"} else {"JOINED_PARTIAL"}} else {"STRAGGLERS"},_arrived,_expected,diag_tickTime],true];
if (((_parent getVariable ["NeroWL_pendingPurchase",[]]) param [0,""]) == _id) then {_parent setVariable ["NeroWL_pendingPurchase",nil,true];};
_parent setVariable ["NeroAI_forcePlan",true,true];
_success
