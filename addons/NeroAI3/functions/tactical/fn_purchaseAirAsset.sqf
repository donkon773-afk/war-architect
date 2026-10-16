/* Paid AI aircraft, independent of the player-bound WLAircraftArrival UI.
 * Only catalog classes; bounded living aircraft per side, selected in lobby. */
params ["_group","_kind"];
if !(missionNamespace getVariable ["NeroAI_airEnabled",true]) exitWith {[false,"Авиация выключена в параметрах миссии."]};
if (!isServer || {!local _group}) exitWith {[false,"BUY AIR: группа не локальна серверу."]};
private _warlords = missionNamespace getVariable ["BIS_WL_allWarlords",[]];
private _wl = ((units _group) select {alive _x && {_x in _warlords}}) param [0,objNull];
if (isNull _wl || {isPlayer _wl}) exitWith {[false,"BUY AIR: нужен AI-командир Warlords с CP."]};
private _side = side _group;
private _result = [false,"BUY AIR: покупка недоступна."];
isNil {
    if ((["VEHICLE"] call NeroAI_fnc_designPurchaseCapacity)<=0) exitWith {_result=[false,"BUY AIR: достигнут общий лимит техники миссии."];};
    if (_wl getVariable ["BIS_WL_AI_airdropping",false]) exitWith {_result = [false,"BUY AIR: дождитесь текущей доставки."];};
    if (diag_tickTime - (_group getVariable ["NeroAI_lastPurchase",-1e6]) < 90) exitWith {_result = [false,"BUY AIR: действует пауза покупки."];};
    private _limit = missionNamespace getVariable ["NeroWL_airLimit",1];
    if !(_limit isEqualType 0) then {_limit = 1;};
    _limit = (floor _limit max 0) min 5;
    private _aircraft = vehicles select {alive _x && {_x isKindOf "Air"} && {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) isEqualTo _side || {side _x isEqualTo _side}}};
    if (count _aircraft >= _limit) exitWith {_result = [false,format ["BUY AIR: достигнут лимит %1 бортов стороны — используйте имеющиеся.",_limit]];};
    private _catalog = _wl getVariable ["BIS_WL_purchasable",[]];
    if (count _catalog < 5) exitWith {_result = [false,"BUY AIR: каталог не готов."];};
    private _funds = _wl getVariable ["BIS_WL_funds",0];
    private _fee = missionNamespace getVariable ["BIS_WL_dropCost",25];
    private _reserve = missionNamespace getVariable ["NeroAI_purchaseReserveCP",300];
    private _choices = [];
    private _role = _group getVariable ["NeroWL_role","AIR_CAS"];
    {
        private _class = _x # 0;
        private _cfg = configFile >> "CfgVehicles" >> _class;
        private _uav = getNumber (_cfg >> "isUav") == 1;
        private _weapons = +(getArray (_cfg >> "weapons"));
        {
            _weapons append getArray (_x >> "weapons");
            {_weapons append getArray (_x >> "weapons");} forEach ("true" configClasses (_x >> "Turrets"));
        } forEach ("true" configClasses (_cfg >> "Turrets"));
        private _armed = (_weapons findIf {
            private _name = toLower _x;
            _name != "" && {(["horn","laser","counter","smoke","flare"] findIf {_name find _x >= 0}) < 0}
        }) >= 0;
        private _pylons = "true" configClasses (_cfg >> "Components" >> "TransportPylonsComponent" >> "Pylons");
        _armed = _armed || {(_pylons findIf {getText (_x >> "attachment") != ""}) >= 0};
        private _catalogRole=getText (missionConfigFile >> "CfgWLRequisitionPresets" >> "NeroWL_RHSStart" >> (str _side) >> "Aircraft" >> _class >> "NeroWL_role");
        private _roleMatch = if (_kind == "HELICOPTER" && {_role == "AIR_TRANSPORT"}) then {getNumber (_cfg >> "transportSoldier") >= count ((units _group) select {alive _x})} else {if (_kind == "PLANE" && {_role == "AIR_SUPERIORITY"} && {_catalogRole != ""}) then {_catalogRole == "JET_FIGHTER"} else {if (_role == "AIR_CAS" && {_catalogRole != ""}) then {_armed && {_catalogRole in ["AIR_CAS","JET_CAS"]}} else {_armed}}};
        private _match = switch (_kind) do {
            case "UAV": {_uav};
            case "HELICOPTER": {_class isKindOf "Helicopter" && {!_uav}};
            default {_class isKindOf "Plane" && {!_uav}};
        };
        private _owned = (missionNamespace getVariable ["BIS_WL_sectors",[]]) select {
            (_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side
        };
        private _requirements = _x param [2,[]];
        private _service = _owned select {
            private _services = _x getVariable ["BIS_WL_sectorSpecial",[]];
            (_requirements findIf {!(_x in _services)}) < 0
        };
        if (_match && {_roleMatch || {_kind == "UAV"}} && {isClass _cfg} && {getNumber (_cfg >> "scope") == 2} &&
            {getNumber (_cfg >> "side") == ([east,west,resistance] find _side)} &&
            {(_x # 1) > 0} && {(_x # 1) + _fee + _reserve <= _funds} && {!(_service isEqualTo [])}) then {
            _choices pushBack [_x # 1,_class,_service # 0];
        };
    } forEach (_catalog # 4);
    _choices sort true;
    if (_choices isEqualTo []) exitWith {_result = [false,"BUY AIR: нет доступного по CP борта или своего аэродрома/вертолётной площадки."];};
    (_choices # 0) params ["_price","_class","_homeSector"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    private _home = getPosATL _homeSector;
    private _servicePosition = +_home;
    private _plane = _class isKindOf "Plane";
    private _airport = -1;
    private _dir = 0;
    private _spawn = +_home;
    if (_plane) then {
        private _distance = 2500;
        {
            private _pos = getArray (_x >> "ilsPosition");
            if (count _pos >= 2) then {
                _pos = _pos apply {if (_x isEqualType "") then {parseNumber _x} else {_x}};
                private _d = _pos distance2D _servicePosition;
                if (_d < _distance) then {
                    _distance = _d; _airport = _forEachIndex;
                    _home = [_pos # 0,_pos # 1,0];
                    private _axis = getArray (_x >> "ilsDirection");
                    if (count _axis == 3) then {
                        _spawn = [(_pos # 0) + (_axis # 0)*1800,(_pos # 1) + (_axis # 2)*1800,250];
                        _dir = _spawn getDir _home;
                    };
                };
            };
        } forEach ([configFile >> "CfgWorlds" >> worldName] + ("true" configClasses (configFile >> "CfgWorlds" >> worldName >> "SecondaryAirports")));
    } else {
        /* 7.10: a busy airfield base (parked purchases, hangars) left no 15 m
         * flat-empty spot within 180 m and every re-purchase failed. Widen the
         * search in rings up to ~500 m with a slightly gentler pad check. */
        private _found = [];
        for "_ring" from 0 to 4 do {
            private _c = _home findEmptyPosition [20 + _ring * 100, 180 + _ring * 80, _class];
            if !(_c isEqualTo []) then {
                private _flat = _c isFlatEmpty [10,-1,0.18,12,0,false,objNull];
                if !(_flat isEqualTo []) exitWith {_found = ASLToATL _flat;};
            };
            if !(_found isEqualTo []) exitWith {};
        };
        _spawn = _found;
        if !(_spawn isEqualTo []) then {_home = +_spawn;};
    };
    if ((_plane && {_airport < 0}) || {_spawn isEqualTo []}) exitWith {_result = [false,"BUY AIR: нет безопасной площадки или реальной полосы возле своего сектора."];};
    // Lock, recheck, debit and create are one unscheduled critical section.
    _funds = _wl getVariable ["BIS_WL_funds",0];
    if (_funds < _price + _fee + _reserve) exitWith {};
    private _crewCapacity = ["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity;
    if (_crewCapacity <= 0) exitWith {_result=[false,"BUY AIR: достигнут общий лимит NPC — нет места для экипажа."];};
    if !([_group,"VEHICLE"] call NeroAI_fnc_claimSidePurchaseSlot) exitWith {_result=[false,"BUY AIR: действует общая пауза закупок стороны."];};
    _wl setVariable ["BIS_WL_AI_airdropping",true];
    _wl setVariable ["BIS_WL_funds",_funds - _price - _fee,true];
    private _air = createVehicle [_class,_spawn,[],0,if (_plane) then {"FLY"} else {"NONE"}];
    if (isNull _air) exitWith {
        _wl setVariable ["BIS_WL_funds",(_wl getVariable ["BIS_WL_funds",0]) + _price + _fee,true];
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [false,"BUY AIR: объект не создан; CP возвращены."];
    };
    createVehicleCrew _air;
    private _crew = crew _air;
    if (_crew isEqualTo [] || {isNull driver _air} || {count _crew > (4 min _crewCapacity)}) exitWith {
        {_air deleteVehicleCrew _x;} forEach _crew;
        deleteVehicle _air;
        _wl setVariable ["BIS_WL_funds",(_wl getVariable ["BIS_WL_funds",0]) + _price + _fee,true];
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [false,"BUY AIR: экипаж не создан или превышает лимит; CP возвращены."];
    };
    private _airGroup = group driver _air;
    _airGroup setVariable ["NeroAI_isBaseAssetCrew",true,true];
    _airGroup deleteGroupWhenEmpty true;
    _air setVariable ["NeroWL_paidAir",true,true];
    _air setVariable ["NeroAI_ownerSide",_side,true];
    _air setVariable ["BIS_WL_itemOwner",_wl,true];
    _air setVariable ["NeroAI_homeBase",_home,true];
    _air setVariable ["NeroWL_homeSector",_homeSector,true];
    _air setVariable ["NeroWL_airport",_airport];
    /* 7.10: a catalog transport helicopter (Mi-8 etc.) carries troops whoever
     * bought it; live it flew empty RECON sorties for an INFANTRY buyer. */
    private _boughtRole=getText (missionConfigFile >> "CfgWLRequisitionPresets" >> "NeroWL_RHSStart" >> (str _side) >> "Aircraft" >> _class >> "NeroWL_role");
    private _carrier=(_class isKindOf "Helicopter") && {_boughtRole == "AIR_TRANSPORT" || {_boughtRole == "" && {_role != "AIR_CAS"} && {getNumber (_cfg >> "transportSoldier") >= 8}}};
    _air setVariable ["NeroAI_assetRole",if (_kind == "UAV") then {"UAV_ARMED"} else {if (_role == "AIR_TRANSPORT" || {_carrier}) then {"TRANSPORT"} else {if (_role == "AIR_SUPERIORITY") then {"INTERCEPT"} else {"CAS"}}},true];
    _air setVariable ["NeroAI_airState",if (_plane) then {"LANDING"} else {"PARKED"},true];
    private _pointer = _wl getVariable ["BIS_WL_pointer",_wl];
    if (isNull _pointer) then {_pointer = _wl; _wl setVariable ["BIS_WL_pointer",_wl,true];};
    _pointer setVariable ["BIS_WL_purchased",(_pointer getVariable ["BIS_WL_purchased",[]]) + [_air],true];
    _group setVariable ["NeroAI_lastPurchase",diag_tickTime,true];
    _wl setVariable ["BIS_WL_AI_airdropping",false];
    if (_plane) then {
        _air setDir _dir; _air setVelocityModelSpace [0,130,0];
        while {count waypoints _airGroup > 0} do {deleteWaypoint ((waypoints _airGroup) # 0);};
        private _approach=_airGroup addWaypoint [_home,0];
        _approach setWaypointType "MOVE";
        _airGroup setCurrentWaypoint _approach;
        _air landAt _airport;
        [_air] spawn {
            params ["_air"];
            private _deadline = diag_tickTime + 300;
            waitUntil {sleep 5; !alive _air || {isTouchingGround _air && {abs speed _air < 5}} || {diag_tickTime > _deadline}};
            if (alive _air) then {
                _air setVariable ["NeroAI_airState",if (isTouchingGround _air && {abs speed _air<5}) then {"PARKED"} else {"UNAVAILABLE"},true];
                if (_air getVariable ["NeroAI_airState",""] == "UNAVAILABLE") then {[_air] call NeroAI_fnc_recoverAirLanding;};
            };
        };
    };
    ["INFO",format ["BUY AIR %1: %2 cost=%3 fee=%4 CP left=%5",_kind,_class,_price,_fee,_wl getVariable ["BIS_WL_funds",0]]] call NeroAI_fnc_log;
    _result = [true,format ["Куплен %1 за %2 CP с доставкой. Запросите RECON/CAS после готовности.",getText (_cfg >> "displayName"),_price + _fee]];
};
/* Per-minute counters for fn_sideTelemetry. */
if (_result # 0) then {private _k=format ["NeroWL_buys_%1",side _group];missionNamespace setVariable [_k,(missionNamespace getVariable [_k,0])+1];} else {private _k=format ["NeroWL_buyRefusals_%1",side _group];missionNamespace setVariable [_k,(missionNamespace getVariable [_k,0])+1];};
_result
