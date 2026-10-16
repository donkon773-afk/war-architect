/* Passenger squads with a separate linked crew leave for the final urban leg.
 * Existing mixed gun-crew/infantry groups need an explicit roster adapter;
 * a CQB task must not capture their remaining vehicle crew. */
params ["_group","_objective"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)} || {count _objective < 2}) exitWith {false};
if (_group getVariable ["NeroWL_dismountActive",false]) exitWith {true};
private _now = diag_tickTime;
if (_now < (_group getVariable ["NeroWL_dismountRetry",0])) exitWith {false};
private _members = (units _group) select {alive _x};
private _vehicles = [];
{private _v = objectParent _x;if (!isNull _v && {_v isKindOf "LandVehicle"}) then {_vehicles pushBackUnique _v;};} forEach _members;
private _crewOnly = false;private _cargo = [];
{
    {if ((_x # 0) in _members) then {
        if ((_x # 1) isEqualTo "cargo" || {_x param [4,false]}) then {_cargo pushBackUnique (_x # 0);} else {_crewOnly = true;};
    };} forEach (fullCrew [_x,"",false]);
} forEach _vehicles;
/* Also reject mixed groups: never make a LAMBS infantry task own gun crews. */
if (_crewOnly || {_cargo isEqualTo []}) exitWith {false};
private _cache = _group getVariable ["NeroWL_dismountUrban",[[],false,-1e6]];
if (count (_cache # 0) < 2 || {(_cache # 0) distance2D _objective > 60} || {_now-(_cache # 2) > 60}) then {
    _cache = [+_objective,count ((nearestObjects [_objective,["House","Building"],150]) select {count (_x buildingPos -1) > 1}) >= 6,_now];
    _group setVariable ["NeroWL_dismountUrban",_cache];
};
private _manual = _group getVariable ["NeroAI_playerHold",false] || {_now < (_group getVariable ["NeroAI_manualOrderUntil",0])};
private _go = false;private _drivers = [];
{
    private _v = _x;private _crewGroup = group driver _v;
    private _owned = !isNull _crewGroup && {[_crewGroup] call NeroAI_fnc_validateGroup}
        && {(_crewGroup getVariable ["NeroWL_parentGroup",grpNull]) isEqualTo _group}
        && {!(_crewGroup getVariable ["NeroAI_playerHold",false])} && {_now >= (_crewGroup getVariable ["NeroAI_manualOrderUntil",0])}
        && {!(_crewGroup getVariable ["NeroWL_vehicleService",false])};
    private _threat = [_group,_v] call NeroAI_fnc_repairThreat;
    private _decision = [count _cargo,false,_manual,_cache # 1,_v distance2D _objective,_threat # 0,_threat # 1,speed _v] call NeroAI_fnc_dismountDecision;
    if (_owned && {_decision in ["STOP","DISEMBARK"]}) then {_go = true;_drivers pushBackUnique _crewGroup;};
} forEach _vehicles;
if (!_go || {_manual}) exitWith {false};
/* Every occupied vehicle must have a cooperative crew before stopping. */
if ((_vehicles findIf {!((group driver _x) in _drivers)}) >= 0) exitWith {false};
private _token = _group getVariable ["NeroAI_opToken",0];
private _until = _now+30;private _held = [];
{
    _held pushBack [_x,_x getVariable ["NeroWL_logisticsUntil",0],_until,_x getVariable ["NeroAI_opToken",0]];
    [_x] call NeroAI_fnc_routeStop;
    _x setVariable ["NeroWL_logisticsUntil",_until];
} forEach ([_group]+_drivers);
_group setVariable ["NeroWL_dismountActive",true];
[_group,_cargo,_vehicles,_token,_held,_until,+_objective] spawn {
    params ["_group","_cargo","_vehicles","_token","_held","_until","_objective"];
    private _current = {
        [_group] call NeroAI_fnc_validateGroup && {(_group getVariable ["NeroAI_opToken",0]) == _token}
        && {(_held findIf {!([_x # 0] call NeroAI_fnc_validateGroup) || {((_x # 0) getVariable ["NeroAI_opToken",0]) != (_x # 3)}}) < 0}
        && {diag_tickTime < _until}
    };
    {if (local _x && {!isNull driver _x}) then {doStop driver _x;};} forEach _vehicles;
    private _stopUntil = diag_tickTime+10;
    waitUntil {sleep 0.5;!(call _current) || {(_vehicles findIf {abs speed _x >= 3}) < 0} || {diag_tickTime >= _stopUntil}};
    private _safe = call _current && {(_vehicles findIf {
        private _t = [_group,_x] call NeroAI_fnc_repairThreat;
        !alive _x || {abs speed _x >= 3} || {(_t # 0) < 100} || {(_t # 1) < 10}
    }) < 0};
    if (_safe) then {
        {if (alive _x && {local _x} && {!isPlayer _x}) then {unassignVehicle _x;[_x] orderGetIn false;doGetOut _x;};} forEach _cargo;
        waitUntil {sleep 0.5;!(call _current) || {(_cargo findIf {alive _x && {!isNull objectParent _x}}) < 0}};
    };
    private _left = {alive _x && {!isNull objectParent _x}} count _cargo;
    {
        _x params ["_g","_old","_claimed","_op"];
        if (!isNull _g && {(_g getVariable ["NeroWL_logisticsUntil",0]) == _claimed}) then {_g setVariable ["NeroWL_logisticsUntil",_old];};
        if (!isNull _g && {(_g getVariable ["NeroAI_opToken",0]) == _op}) then {_g setVariable ["NeroAI_forcePlan",true,true];};
    } forEach _held;
    _group setVariable ["NeroWL_dismountActive",false];
    _group setVariable ["NeroWL_dismountRetry",diag_tickTime+60];
    _group setVariable ["NeroWL_dismountResult",[diag_tickTime,_left == 0,_left],true];
    if (_left == 0 && {(_group getVariable ["NeroAI_opToken",0]) == _token}) then {_group setVariable ["NeroWL_assaultOnFoot",_objective];};
};
true
