/* Native spawner has physically seated its manifest before this scheduled
 * flight begins. No setPos, respawn, forced repair or invulnerability. */
params ["_plane","_buyer","_manifest","_plan"];
private _parent = group _buyer;private _side = side _parent;private _pilot = driver _plane;
private _crewGroup = group _pilot;private _started = diag_tickTime;
private _drop = _plan # 5;private _sector = _plan # 7;
private _dropRadius = (((_sector getVariable ["Size",300])/2)-(_drop distance2D _sector)-15) min 250;
private _id = _plane getVariable ["NeroWL_supplyId",format ["FLIGHT-%1",netId _plane]];
private _expected = _plane getVariable ["NeroWL_supplyExpected",count _manifest];
if (_manifest isEqualTo []) exitWith {
    _parent setVariable ["NeroWL_purchaseBlocked",true,true];_parent setVariable ["NeroWL_supplyFlight",objNull,true];
    missionNamespace setVariable [format ["NeroWL_dropFlight_%1",_side],objNull];
    if (local _plane && {((crew _plane) findIf {_x != _pilot || {isPlayer _x}}) < 0}) then {_plane deleteVehicleCrew _pilot;deleteVehicle _plane;deleteGroup _crewGroup;};
};
_parent setVariable ["NeroWL_supplyManifest",+_manifest,true];
_parent setVariable ["NeroWL_supplyResult",[_id,"IN_TRANSIT",count _manifest,_expected,diag_tickTime],true];
if (!isNull _crewGroup && {alive _pilot} && {local _plane}) then {
    private _wp = _crewGroup addWaypoint [_drop,0];_wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 100;_crewGroup setCurrentWaypoint _wp;
};
private _state = "APPROACH";private _jumped = [];
private _nextIntel = -1;
private _safeSector = {
    (_sector getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side
        && {isNil "BIS_WL_sectors" || {_sector in (([_side] call NeroAI_fnc_wlSnapshot) param [2,[]])}}
        && {canMove _plane} && {fuel _plane > 0.05} && {damage _plane < 0.65}
};
while {_state == "APPROACH"} do {
    if (diag_tickTime >= _nextIntel && {local _pilot} && {alive _pilot}) then {
        _nextIntel = diag_tickTime+5;
        private _rows = [];
        {
            private _target = _x param [4,objNull];
            if (!isNull _target && {alive _target} && {(_side getFriend side _target) < 0.6}) then {
                private _p = _pilot getHideFrom _target;
                if (_p isNotEqualTo [0,0,0]) then {_rows pushBack [typeOf _target,[_p # 0,_p # 1],round ((_pilot knowsAbout _target)*10),diag_tickTime,"SUPPLY",netId _target];};
            };
        } forEach (_pilot nearTargets 3500);
        _rows resize (count _rows min 12);
        private _shared = NeroAI_sharedIntel getOrDefault [str _side,[]];
        NeroAI_sharedIntel set [str _side,[_shared+_rows] call NeroAI_fnc_rulesUniqueIntel];
    };
    private _threat = [_side,_drop,getPosATL _plane] call NeroAI_fnc_airdropThreat;
    _state = [alive _plane && {alive _pilot},local _plane && {local _pilot},((crew _plane) findIf {isPlayer _x}) >= 0,
        call _safeSector,_threat # 0,_threat # 1,
        getPosATL _plane # 2,_plane distance2D _drop,diag_tickTime-_started,_dropRadius] call NeroAI_fnc_airdropFlightState;
    if (_state in ["APPROACH","DROP"] && {_plane distance2D _drop < 2500}) then {
        private _height = getTerrainHeightASL _drop+280;
        _plane flyInHeightASL [_height,_height,_height];_plane flyInHeight 280;
    };
    if (_state == "APPROACH") then {sleep (if (_plane distance2D _drop < 1000) then {0.1} else {1});};
};
if (_state == "DROP") then {
    {
        private _unit = _x;
        private _threat = [_side,_drop,getPosATL _plane] call NeroAI_fnc_airdropThreat;
        private _gate = [alive _plane && {alive _pilot},local _plane,((crew _plane) findIf {isPlayer _x}) >= 0,
            call _safeSector,_threat # 0,_threat # 1,
            getPosATL _plane # 2,_plane distance2D _drop,diag_tickTime-_started,_dropRadius] call NeroAI_fnc_airdropFlightState;
        if (_gate != "DROP") exitWith {_state = _gate;};
        if (alive _unit && {local _unit} && {!isPlayer _unit} && {objectParent _unit isEqualTo _plane}) then {
            _unit setVariable ["NeroWL_savedDropBackpack",(getUnitLoadout _unit) param [5,[]]];
            removeBackpack _unit;_unit addBackpack "B_Parachute";
            unassignVehicle _unit;[_unit] orderGetIn false;_unit action ["Eject",_plane];
            _jumped pushBack _unit;sleep 0.1;
        };
    } forEach _manifest;
};
/* An aborted flight with passengers keeps them aboard and attempts a real
 * airport landing. It is never despawned with its paid passengers. */
private _aboard = _manifest select {alive _x && {objectParent _x isEqualTo _plane}};
if (alive _plane && {alive _pilot} && {!isNull _crewGroup} && {local _plane} && {_state != "RELEASE"} && {((crew _plane) findIf {isPlayer _x}) < 0}) then {
    private _out = _crewGroup addWaypoint [_plan # 6,0];_out setWaypointType "MOVE";_crewGroup setCurrentWaypoint _out;
    if (_aboard isNotEqualTo []) then {
        private _airports = [configFile >> "CfgWorlds" >> worldName]+("true" configClasses (configFile >> "CfgWorlds" >> worldName >> "SecondaryAirports"));
        private _airport = -1;private _distance = 3500;
        {private _p = getArray (_x >> "ilsPosition");if (count _p >= 2 && {(_p distance2D (_plan # 8)) < _distance}) then {_airport = _forEachIndex;_distance = _p distance2D (_plan # 8);};} forEach _airports;
        if (_airport >= 0) then {_plane landAt _airport;};
        private _landUntil = diag_tickTime+120;
        waitUntil {sleep 1;!alive _plane || {!local _plane} || {((crew _plane) findIf {isPlayer _x}) >= 0} || {(getPosATL _plane # 2) < 3 && {abs speed _plane < 5}} || {diag_tickTime >= _landUntil}};
        if (alive _plane && {local _plane} && {((crew _plane) findIf {isPlayer _x}) < 0} && {(getPosATL _plane # 2) < 3} && {abs speed _plane < 5}) then {
            {if (alive _x && {local _x} && {!isPlayer _x}) then {unassignVehicle _x;doGetOut _x;};} forEach _aboard;
        };
    };
};
private _landingUntil = diag_tickTime+120;
waitUntil {sleep 1;
    (_manifest findIf {alive _x && {(!isNull objectParent _x) || {(getPosATL _x # 2) > 3}}}) < 0
        || {diag_tickTime >= _landingUntil} || {_state == "RELEASE"}
};
private _landed = _manifest select {alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x} && {(getPosATL _x # 2) < 3}};
{
    if (!isNil {_x getVariable "NeroWL_savedDropBackpack"}) then {private _loadout = getUnitLoadout _x;_loadout set [5,_x getVariable "NeroWL_savedDropBackpack"];_x setUnitLoadout _loadout;_x setVariable ["NeroWL_savedDropBackpack",nil];};
} forEach _landed;
private _unresolved = _manifest select {alive _x && {!(_x in _landed)}};
private _nearDrop = _landed select {_x distance2D _drop <= ((_sector getVariable ["Size",300])/2)+200};
private _result = if (count _nearDrop == _expected && {_state == "DROP"}) then {"LANDED"} else {
    if (_state == "RELEASE") then {"RELEASED"} else {
        if (_unresolved isNotEqualTo []) then {"UNCONFIRMED"} else {if (_landed isEqualTo []) then {"LOSS"} else {if (_state == "DROP") then {"PARTIAL_LANDED"} else {"RETURNED_OR_SURVIVED"}}}
    }
};
if (!alive _plane) then {missionNamespace setVariable [format ["NeroWL_supplyLoss_%1",_side],[diag_tickTime,_drop]];};
if (_unresolved isNotEqualTo []) then {_parent setVariable ["NeroWL_purchaseBlocked",true,true];_parent setVariable ["NeroWL_strandedSupply",_unresolved,true];};
_parent setVariable ["NeroWL_supplyResult",[_id,_result,count _landed,_expected,diag_tickTime],true];
if ((missionNamespace getVariable [format ["NeroWL_dropFlight_%1",_side],objNull]) isEqualTo _plane) then {missionNamespace setVariable [format ["NeroWL_dropFlight_%1",_side],objNull];};
_parent setVariable ["NeroWL_supplyFlight",objNull,true];
if (_landed isNotEqualTo []) then {[_parent,_landed,_id,_expected] spawn NeroAI_fnc_airdropRendezvous;} else {
    _parent setVariable ["NeroWL_supplyManifest",[],true];
    if (((_parent getVariable ["NeroWL_pendingPurchase",[]]) param [0,""]) == _id) then {_parent setVariable ["NeroWL_pendingPurchase",nil,true];};
    if (_result == "LOSS") then {_parent setVariable ["NeroAI_lastPurchase",diag_tickTime,true];};
};
/* Cleanup is limited to our empty service aircraft and pilot, well away from
 * the drop. Occupied, captured, player-used or crashed aircraft remain real. */
[_plane,_pilot,_crewGroup,_manifest,_drop] spawn {
    params ["_plane","_pilot","_crewGroup","_manifest","_drop"];
    private _until = diag_tickTime+120;
    waitUntil {sleep 2;!alive _plane || {_plane distance2D _drop > 2500} || {diag_tickTime >= _until}};
    if (alive _plane && {local _plane} && {_plane distance2D _drop > 2500} && {((crew _plane) findIf {isPlayer _x || {!(_x isEqualTo _pilot)}}) < 0}
        && {(_manifest findIf {objectParent _x isEqualTo _plane}) < 0} && {group _pilot isEqualTo _crewGroup}) then {
        _plane deleteVehicleCrew _pilot;deleteVehicle _plane;deleteGroup _crewGroup;
    };
};
["INFO",format ["SUPPLY FLIGHT %1 %2 landed=%3/%4 state=%5",_id,_result,count _landed,count _manifest,_state]] call NeroAI_fnc_log;
