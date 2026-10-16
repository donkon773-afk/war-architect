/* Protect an enemy air budget; friendly/native-only missions remain native. */
params ["_group"];
if (_group getVariable ["NeroAI_active",false]) exitWith {false};
if (((missionNamespace getVariable ["NeroWL_purchaseQueue",[]]) findIf {side (_x # 1) isEqualTo side _group}) >= 0) exitWith {false};
if (getNumber (missionConfigFile >> "NeroWL_personalScenario") != 1 || {!(missionNamespace getVariable ["NeroAI_enemyAIEnabled",true]) && {!(missionNamespace getVariable ["NeroAI_friendlyAutoEnrollEnabled",false])}}) exitWith {true};
private _players=allPlayers select {!(_x isKindOf "HeadlessClient_F")};
if (_players isEqualTo [] && {time<=30}) exitWith {false};
private _members=(units _group) select {alive _x};
if (_members isEqualTo []) exitWith {false};
private _wl=(_members select {_x in (missionNamespace getVariable ["BIS_WL_allWarlords",[]])}) param [0,objNull];
if (isNull _wl || {_wl getVariable ["BIS_WL_AI_airdropping",false]} || {_group getVariable ["NeroWL_purchaseBlocked",false]}) exitWith {false};
// Native Warlords can remove an unboarded vehicle from groupVehs after 180s.
// Its physical owner remains authoritative: reuse it instead of buying again.
private _owned=nearestObjects [leader _group,["LandVehicle"],1500] select {
    alive _x && {(_x getVariable ["BIS_WL_itemOwner",objNull]) in _members}
};
if !(_owned isEqualTo []) exitWith {false};
[_group] call NeroAI_fnc_assignDefaultRole;
private _groundAllowed = !((_group getVariable ["NeroWL_role",""]) in ["AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"]) || {!(missionNamespace getVariable ["NeroAI_airEnabled",true])};
_groundAllowed && {[_group] call NeroAI_fnc_claimSidePurchaseSlot}
