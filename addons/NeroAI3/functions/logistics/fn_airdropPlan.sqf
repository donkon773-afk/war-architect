/* No spawning/payment here. Optional trusted mission adapter context:
 * [homeBase, connectedOwnedSectors, focusSector]. Native WL supplies it by default.
 * Result [ok,reason,class,pilotClass,spawnATL,dropATL,egressATL,sector,base,ASL]. */
params ["_group","_cart","_anchor",["_context",[]]];
if (!isServer || {!([_group,false] call NeroAI_fnc_validateGroup)} || {_cart isEqualTo []} || {count _cart > 32}) exitWith {[false,"Недоступная серверная пехотная группа."]};
private _side = side _group;
private _active = missionNamespace getVariable [format ["NeroWL_dropFlight_%1",_side],objNull];
if (!isNull _active && {alive _active}) exitWith {[false,"Транспортный самолёт стороны уже выполняет доставку."]};
private _fleet = vehicles select {alive _x && {_x getVariable ["NeroWL_deliveryAircraft",false]} && {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) isEqualTo _side}};
if (count _fleet >= 2) exitWith {[false,"Два транспортника стороны ещё находятся в мире; новые рейсы ожидают их освобождения."]};
private _loss = missionNamespace getVariable [format ["NeroWL_supplyLoss_%1",_side],[-1e6,[]]];
if (diag_tickTime-(_loss # 0) < 180) exitWith {[false,"После потери транспортника новые рейсы временно приостановлены для оценки обстановки."]};
if ((["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity) < count _cart+1 || {(["VEHICLE"] call NeroAI_fnc_designPurchaseCapacity) < 1}) exitWith {[false,"В лимитах миссии нет места для десанта, пилота и транспортника."]};
private _base = _context param [0,missionNamespace getVariable [format ["BIS_WL_base_%1",_side],objNull]];
private _own = if (count _context >= 2) then {_context # 1} else {([_side] call NeroAI_fnc_wlSnapshot) param [2,[]]};
if (isNull _base || {(_base getVariable ["BIS_WL_sectorSide",_side]) != _side}) exitWith {[false,"Основная база недоступна."]};
private _request = getPosATL _anchor;
private _focus = _context param [2,missionNamespace getVariable [format ["BIS_WL_currentSector_%1",_side],objNull]];
if (isNull _focus || {_focus distance2D _request > 2500}) then {
    _focus = objNull;private _best = 1e9;
    {private _d = _x distance2D _request;if (_d < _best) then {_focus = _x;_best = _d;};} forEach (missionNamespace getVariable ["BIS_WL_sectors",_own]);
};
if (isNull _focus) exitWith {[false,"Нет точки для выбора соседнего своего сектора."]};
private _candidates = +(_focus getVariable ["BIS_WL_connectedSectors",[]]);
if (_focus in _own) then {_candidates pushBackUnique _focus;};
_candidates = _candidates select {_x in _own && {_x != _base} && {(_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side}};
private _cfgs = missionNamespace getVariable ["NeroWL_transportClasses",[]];
if (_cfgs isEqualTo []) then {_cfgs = ("getNumber (_x >> 'scope') == 2 && {getNumber (_x >> 'transportSoldier') >= 4}" configClasses (configFile >> "CfgVehicles")) select {(configName _x) isKindOf "Plane"};missionNamespace setVariable ["NeroWL_transportClasses",_cfgs];};
private _faction = getText (configOf leader _group >> "faction");
private _class = "";private _classScore = -1e9;private _pilotClass = "";
{
    if (getNumber (_x >> "side") isEqualTo ([east,west,resistance,civilian] find _side) && {getNumber (_x >> "transportSoldier") >= count _cart}) then {
        private _pilot = getText (_x >> "crew");
        if (isClass (configFile >> "CfgVehicles" >> _pilot) && {getNumber (configFile >> "CfgVehicles" >> _pilot >> "side") isEqualTo ([east,west,resistance,civilian] find _side)}) then {
            private _score = (if (getText (_x >> "faction") isEqualTo _faction) then {1000} else {0}) + (getNumber (_x >> "transportSoldier") min 64);
            if (_score > _classScore) then {_classScore = _score;_class = configName _x;_pilotClass = _pilot;};
        };
    };
} forEach _cfgs;
if (_class isEqualTo "") exitWith {[false,"Не найден установленный транспортный самолёт своей стороны с местами для десанта."]};
private _from = getPosATL _base;
private _drop = [];private _sector = objNull;private _score = -1e9;
{
    private _s = _x;
    private _r = ((_s getVariable ["Size",300])/8) min 25;
    private _p = (getPosATL _s) getPos [_r,_focus getDir _s];_p set [2,0];
    private _threat = [_side,_p,_from] call NeroAI_fnc_airdropThreat;
    private _front = if (_focus in _own) then {1e9} else {_p distance2D _focus};
    private _value = [true,true,!surfaceIsWater _p && {((surfaceNormal _p) # 2) > 0.96},_front,_threat # 0,_threat # 1,_threat # 2,_from distance2D _p,_request distance2D _p] call NeroAI_fnc_airdropRiskScore;
    if (diag_tickTime-(_loss # 0) < 600 && {count (_loss # 1) >= 2} && {_p distance2D (_loss # 1) < 1500}) then {_value = -1e9;};
    private _approach = _p getPos [2000,_p getDir _from];private _ridge = getTerrainHeightASL _p;
    for "_i" from 0 to 6 do {private _sample = _approach getPos [2000*_i/6,_approach getDir _p];_ridge = _ridge max (getTerrainHeightASL _sample);};
    if (_ridge-getTerrainHeightASL _p > 350) then {_value = -1e9;};
    if ((_s getVariable ["Size",300])/2-_r-15 < 80) then {_value = -1e9;};
    if (_value > _score) then {_score = _value;_drop = _p;_sector = _s;};
} forEach _candidates;
if (_drop isEqualTo []) exitWith {[false,"Нет соседнего связного своего сектора на допустимой дистанции от известных угроз и ПВО."]};
private _bearing = _from getDir _drop;
private _spawn = _from getPos [1800,_bearing+180];
_spawn set [0,((_spawn # 0) max 150) min (worldSize-150)];_spawn set [1,((_spawn # 1) max 150) min (worldSize-150)];
private _maxTerrain = getTerrainHeightASL _spawn;
private _routeBearing = _spawn getDir _drop;
for "_i" from 1 to 8 do {private _p = _spawn getPos [(_spawn distance2D _drop)*_i/8,_routeBearing];_maxTerrain = _maxTerrain max (getTerrainHeightASL _p);};
private _asl = _maxTerrain+350;
_spawn set [2,(_asl-getTerrainHeightASL _spawn) max 300];
private _egress = _from getPos [3000,_bearing+180];_egress set [0,((_egress # 0) max 150) min (worldSize-150)];_egress set [1,((_egress # 1) max 150) min (worldSize-150)];_egress set [2,350];
[true,"",_class,_pilotClass,_spawn,_drop,_egress,_sector,_base,_asl]
