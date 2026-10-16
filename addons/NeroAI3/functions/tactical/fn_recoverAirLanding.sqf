/* Failed landing must not leave a healthy paid plane at its default [0,0] WP.
 * Only the dedicated air crew's route is changed; fuel/ammo/CP remain physical. */
params ["_air"];
if (!isServer || {isNull _air} || {!local _air} || {!alive _air} || {!(_air isKindOf "Plane")} || {!(_air getVariable ["NeroWL_paidAir",false])}) exitWith {false};
if (isTouchingGround _air || {fuel _air <= 0.25} || {damage _air >= 0.4} || {isNull driver _air} || {!alive driver _air} || {isPlayer driver _air} || {(crew _air findIf {isPlayer _x}) >= 0}) exitWith {false};
private _home=_air getVariable ["NeroAI_homeBase",[]];
if (count _home < 2 || {!((_home # 0) isEqualType 0)} || {!((_home # 1) isEqualType 0)} || {(_home # 0) < 500} || {(_home # 1) < 500} || {(_home # 0) > worldSize-500} || {(_home # 1) > worldSize-500}) exitWith {false};
private _g=group driver _air;
if (!local _g || {!(_g getVariable ["NeroAI_isBaseAssetCrew",false])}) exitWith {false};
while {count waypoints _g > 0} do {deleteWaypoint ((waypoints _g) # 0);};
_air land "NONE";
_air engineOn true;
_air flyInHeight 400;
_g setBehaviour "AWARE";
_g setCombatMode "BLUE";
private _wp=_g addWaypoint [[_home # 0,_home # 1,0],0];
_wp setWaypointType "LOITER";
_wp setWaypointLoiterRadius 800;
_g setCurrentWaypoint _wp;
_air setVariable ["NeroAI_airState","READY",true];
["WARN",format ["AIR landing recovery %1: home=%2; state=READY, physical airborne hold",typeOf _air,_home]] call NeroAI_fnc_log;
true
