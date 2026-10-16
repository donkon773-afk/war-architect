/* Only aircraft paid for by NeroWL. Physical fuel/ammunition, no refill.
 * The air group is separate from the ground commander's native Warlords FSM. */
params ["_group","_target",["_mission","CAS"]];
if (_mission == "TRANSPORT") exitWith {[_group,_target] call NeroAI_fnc_airTransport};
private _wantedRoles=switch (_mission) do {case "INTERCEPT": {["INTERCEPT"]};case "ESCORT": {["INTERCEPT","CAS"]};default {["CAS","UAV_ARMED","INTERCEPT"]};};
private _intercept=objNull;
if (_mission == "INTERCEPT") then {
 private _intel=(missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str side _group,[]];
 {private _o=objectFromNetId (_x param [5,""]);if (!isNull _o && {alive _o} && {_o isKindOf "Air"} && {_o distance2D _target < 1500} && {(side _group getFriend side _o) < 0.6}) exitWith {_intercept=_o;};} forEach _intel;
};
if (_mission == "INTERCEPT" && {isNull _intercept}) exitWith {[false,"Нет подтверждённой воздушной цели для перехвата."]};
private _side = side _group;
private _fleet = vehicles select {
    alive _x && {(_x getVariable ["NeroAI_assetRole",""]) in _wantedRoles} && {_x getVariable ["NeroWL_paidAir",false]} && {local _x} &&
    {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) isEqualTo _side} &&
    {(_x getVariable ["NeroAI_airState",""]) in ["PARKED","READY"]} && {fuel _x > 0.25} &&
    {damage _x < 0.4} && {!isNull driver _x} && {alive driver _x} &&
    {diag_tickTime - (_x getVariable ["NeroAI_lastSortie",-1e6]) > 180} &&
    {_mission in ["RECON","ESCORT"] || {canFire _x}}
};
if (_fleet isEqualTo []) exitWith {[false,"Нет готовой оплаченной авиации."]};
private _air = _fleet # 0;
private _homeSector = _air getVariable ["NeroWL_homeSector",objNull];
if (isNull _homeSector || {!((_homeSector getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side)}) exitWith {[false,"База авиации потеряна; вылет отменён."]};
private _airGroup = group driver _air;
_air setVariable ["NeroAI_airState","SORTIE",true];
_air setVariable ["NeroAI_lastSortie",diag_tickTime,true];
_group setVariable ["NeroAI_lastAirRequest",diag_tickTime,true];
[_air,_airGroup,+_target,_mission,_side,_group,_intercept] spawn {
    params ["_air","_airGroup","_target","_mission","_side","_requestGroup","_intercept"];
    private _home = _air getVariable ["NeroAI_homeBase",getPosATL _air];
    private _stage = _target getPos [900,_target getDir _home];
    private _deadline = diag_tickTime + ((180 max ((_air distance2D _target)/100+120)) min 600);
    while {count waypoints _airGroup > 0} do {deleteWaypoint ((waypoints _airGroup) # 0);};
    _air land "NONE";
    _air engineOn true;
    _air flyInHeight (if (_air isKindOf "Helicopter") then {120} else {400});
    _airGroup setBehaviour "AWARE";
    _airGroup setCombatMode (if (_mission == "RECON") then {"BLUE"} else {"RED"});
    private _wp = _airGroup addWaypoint [_stage,0]; _wp setWaypointType "MOVE";
    private _task = _airGroup addWaypoint [_target,0];
    _task setWaypointType (if (_mission in ["RECON","ESCORT"]) then {"LOITER"} else {"SAD"});
    _task setWaypointLoiterRadius 500;
    if (!isNull _intercept) then {driver _air reveal [_intercept,4];driver _air doTarget _intercept;};
    while {alive _air && {alive driver _air} && {diag_tickTime < _deadline} && {fuel _air > 0.25} && {damage _air < 0.4}} do {
        if (!isNull _requestGroup && {alive leader _requestGroup}) then {
            private _seen = [];
            {
                private _object = _x param [4,objNull];
                private _pos = _x param [0,[]];
                private _targetSide = _x param [2,sideUnknown];
                if (!isNull _object && {alive _object} && {count _pos >= 2} &&
                    {_targetSide in [east,west,resistance]} && {(_side getFriend _targetSide) < 0.6}) then {
                    _seen pushBack [_x param [1,typeOf _object],[round (_pos # 0),round (_pos # 1)],round ((driver _air knowsAbout _object)*10),netId _object];
                };
            } forEach (driver _air nearTargets 2500);
            _seen resize ((count _seen) min 12);
            if !(_seen isEqualTo []) then {
                _requestGroup setVariable ["NeroAI_intel",_seen,true];
                [_requestGroup,"авиационная разведка"] call NeroAI_fnc_shareIntel;
            };
        };
        private _aa = (missionNamespace getVariable ["NeroAI_sharedIntel",createHashMap]) getOrDefault [str _side,[]];
        private _threat = (_aa findIf {
            private _name = toLower (_x param [0,""]);
            private _pos = _x param [1,[]];
            (count _pos >= 2) && {_air distance2D _pos < 1800} &&
            {(["zsu","shilka","tunguska","nasams","skynex","_aa","zu23","sam"] findIf {_name find _x >= 0}) >= 0}
        }) >= 0;
        private _enemyBases = (missionNamespace getVariable ["BIS_WL_sectors",[]]) select {
            _x in [missionNamespace getVariable ["BIS_WL_base_WEST",objNull],missionNamespace getVariable ["BIS_WL_base_EAST",objNull]] &&
            {!((_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side)}
        };
        if (_threat || {(_enemyBases findIf {_air distance2D _x < 1400}) >= 0}) exitWith {};
        if (_mission == "INTERCEPT" && {isNull _intercept || {!alive _intercept}}) exitWith {};
        sleep 5;
    };
    if (alive _air && {alive driver _air}) then {
        // Delete only the temporary air group's own waypoints, never ground FSM WPs.
        while {count waypoints _airGroup > 0} do {deleteWaypoint ((waypoints _airGroup) # 0);};
        _air setVariable ["NeroAI_airState","RTB",true];
        _airGroup setCombatMode "BLUE"; _airGroup setBehaviour "CARELESS";
        if (_air isKindOf "Plane") then {private _airport=_air getVariable ["NeroWL_airport",-1];if (_airport>=0) then {_air landAt _airport;};} else {
            driver _air doMove _home;
            private _arrive = diag_tickTime + 240;
            waitUntil {sleep 5; !alive _air || {!alive driver _air} || {_air distance2D _home < 180} || {diag_tickTime > _arrive}};
            if (alive _air && {_air distance2D _home < 180}) then {_air land "LAND";};
        };
        private _landDeadline = diag_tickTime + 300;
        waitUntil {sleep 5; !alive _air || {!alive driver _air} || {isTouchingGround _air && {abs speed _air < 5}} || {diag_tickTime > _landDeadline}};
        if (alive _air) then {
            private _ready = isTouchingGround _air && {abs speed _air < 5} && {alive driver _air} && {fuel _air > 0.25} && {damage _air < 0.4};
            _air setVariable ["NeroAI_airState",if (_ready) then {"PARKED"} else {"UNAVAILABLE"},true];
            if (!_ready) then {[_air] call NeroAI_fnc_recoverAirLanding;};
            if (isTouchingGround _air) then {_air engineOn false;};
        };
    };
};
[true,"Оплаченная авиация вылетает; ограниченный вылет, затем возвращение на базу."]
