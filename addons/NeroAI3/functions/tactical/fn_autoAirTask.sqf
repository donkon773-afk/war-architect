/* Reuse paid aircraft before buying another. Bounded to one review per 30s.
 * Native objective and observed shared intel only, never an enemy object scan. */
params ["_group"];
if (!local _group || {isPlayer leader _group}) exitWith {};
private _now=diag_tickTime;
if (_now - (_group getVariable ["NeroWL_airReview",-1e6]) < 30) exitWith {};
_group setVariable ["NeroWL_airReview",_now];
{if (alive _x && {_x getVariable ["NeroWL_paidAir",false]} && {(_x getVariable ["BIS_WL_itemOwner",objNull]) in units _group} && {(_x getVariable ["NeroAI_airState",""]) == "UNAVAILABLE"}) then {[_x] call NeroAI_fnc_recoverAirLanding;};} forEach vehicles;
{if (alive _x && {_x getVariable ["NeroWL_paidAir",false]} && {(_x getVariable ["BIS_WL_itemOwner",objNull]) in units _group} && {(_x getVariable ["NeroAI_airState",""]) == "UNAVAILABLE"} && {isTouchingGround _x} && {abs speed _x<5} && {alive driver _x} && {fuel _x>0.25} && {damage _x<0.4}) then {_x setVariable ["NeroAI_airState","PARKED",true];_x engineOn false;};} forEach vehicles;
private _fleet=vehicles select {alive _x && {_x getVariable ["NeroWL_paidAir",false]} && {(_x getVariable ["BIS_WL_itemOwner",objNull]) in units _group} && {(_x getVariable ["NeroAI_airState",""]) in ["PARKED","READY"]}};
if (_fleet isEqualTo []) exitWith {};
if (_group getVariable ["NeroWL_transportActive",false]) exitWith {};
private _objective=missionNamespace getVariable [format ["BIS_WL_currentSector_%1",side _group],objNull];
if (isNull _objective) exitWith {};
private _enemyBases=(missionNamespace getVariable ["BIS_WL_sectors",[]]) select {_x in [missionNamespace getVariable ["BIS_WL_base_EAST",objNull],missionNamespace getVariable ["BIS_WL_base_WEST",objNull]] && {!((_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo side _group)}};
private _bubble=missionNamespace getVariable ["NeroAI_airEnemyBaseNoFlyMeters",1400];
if ((_enemyBases findIf {_objective distance2D _x<_bubble})>=0) then {
    // Native victory targets can be protected enemy HQs. Recon/escort another
    // known map sector instead of retrying the same rejected sortie forever.
    private _choices=[];
    {
        private _s=_x;
        if (!(_s in [missionNamespace getVariable ["BIS_WL_base_EAST",objNull],missionNamespace getVariable ["BIS_WL_base_WEST",objNull]]) && {(_enemyBases findIf {_s distance2D _x<_bubble})<0}) then {
            _choices pushBack [if ((_s getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo side _group) then {1} else {0},_s distance2D leader _group,_s];
        };
    } forEach (missionNamespace getVariable ["BIS_WL_sectors",[]]);
    _choices sort true;
    _objective=if (_choices isEqualTo []) then {objNull} else {(_choices # 0) # 2};
};
if (isNull _objective) exitWith {};
private _pos=getPosATL _objective;
private _role=(_fleet # 0) getVariable ["NeroAI_assetRole","CAS"];
private _task="RECON";
private _intel=(missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str side _group,[]];
if (_role == "TRANSPORT") then {_task="TRANSPORT";};
if (_role == "INTERCEPT") then {
 _task="ESCORT";
 private _airContacts=_intel select {private _o=objectFromNetId (_x param [5,""]);!isNull _o && {alive _o} && {_o isKindOf "Air"} && {(side _group getFriend side _o) < 0.6}};
 if !(_airContacts isEqualTo []) then {_task="INTERCEPT";_pos=(_airContacts # 0) # 1;};
};
private _assigned=_group getVariable ["NeroWL_role","INFANTRY"];
if (_assigned == "AIR_TRANSPORT" && {_role != "TRANSPORT"}) then {_task="RECON";};
if (_role == "CAS" && {(_intel findIf {private _p=_x param [1,[]];count _p>=2 && {_p distance2D _pos<800}}) >= 0}) then {_task="CAS";};
/* 7.10: a transport squad riding somebody's ground vehicle cannot be lifted;
 * for a far objective it dismounts first and the next review flies it. */
if (_task == "TRANSPORT" && {(leader _group) distance2D _pos > 2500} && {((units _group) findIf {alive _x && {vehicle _x != _x} && {vehicle _x isKindOf "LandVehicle"}}) >= 0}) exitWith {
    [_group,"DISEMBARK"] call NeroAI_fnc_vehicleTactics;
    ["INFO",format ["AIR_TASK AUTO %1 TRANSPORT: dismounting from ground vehicles for the helicopter lift.",_group getVariable ["NeroAI_callsign",groupId _group]]] call NeroAI_fnc_log;
};
private _r=[_group,_pos,_task] call NeroAI_fnc_dispatchAir;
if (_r # 0) then {["INFO",format ["AIR_TASK AUTO %1 %2: %3",_group getVariable ["NeroAI_callsign",groupId _group],_task,_r # 1]] call NeroAI_fnc_log;};
