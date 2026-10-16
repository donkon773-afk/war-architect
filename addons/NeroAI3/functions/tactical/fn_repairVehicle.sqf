/* Bounded component/crew repair. Completion is confirmed, never assumed. */
params ["_group",["_target",objNull],["_source","PLAYER"]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false,"Группа недоступна."]};
private _now = diag_tickTime;
if (_source != "PLAYER" && {_group getVariable ["NeroAI_playerHold",false] || {_now < (_group getVariable ["NeroAI_manualOrderUntil",0])}}) exitWith {[false,"Действует приказ игрока."]};
private _side = side _group;
if (isNull _target) then {
    private _candidates = (nearestObjects [leader _group,["LandVehicle"],60]) select {
        alive _x && {local _x} && {damage _x > 0.05 || {!canMove _x}} && {([_x] call NeroAI_fnc_getVehicleSide) isEqualTo _side}
    };
    _target = _candidates param [0,objNull];
};
if (isNull _target || {!alive _target} || {!local _target} || {!(_target isKindOf "LandVehicle")} || {([_target] call NeroAI_fnc_getVehicleSide) != _side}) exitWith {[false,"Нет доступной повреждённой союзной машины."]};
if (((crew _target) findIf {isPlayer _x}) >= 0) exitWith {[false,"Ремонт машины с игроком в экипаже требует его управления."]};
private _oldLease = _target getVariable ["NeroWL_repairLease",[]];
if (count _oldLease >= 3 && {_now < (_oldLease # 2)}) exitWith {[false,"Ремонт этой машины уже выполняется."]};
private _engineer = ((units _group) select {[_x] call NeroAI_fnc_fieldEngineer}) param [0,objNull];
if (isNull _engineer) exitWith {_group setVariable ["NeroAI_repairStatus","NO_ENGINEER",true];[false,"Нужен сознательный подготовленный механик."]};
private _threat = [_group,_target] call NeroAI_fnc_repairThreat;
if ((_threat # 0) < 200 || {(_threat # 1) < 20}) exitWith {
    [_group,getPosATL _target,"COVER"] call NeroAI_fnc_requestSupport;
    [false,"Ремонт отложен: непосредственная угроза, запрошено прикрытие."]
};
private _driverGroup = if (isNull driver _target) then {_group} else {group driver _target};
if (_driverGroup != _group && {_driverGroup getVariable ["NeroAI_playerHold",false] || {_now < (_driverGroup getVariable ["NeroAI_manualOrderUntil",0])}}) exitWith {[false,"Экипаж машины выполняет другой приказ игрока."]};
private _token = _group getVariable ["NeroAI_opToken",0];
private _lease = [_group,_token,_now+240,_driverGroup,_driverGroup getVariable ["NeroAI_opToken",0]];
private _held = [];
{
    if (!isNull _x && {[_x] call NeroAI_fnc_validateGroup}) then {
        _held pushBack [_x,_x getVariable ["NeroWL_logisticsUntil",0],_lease # 2];
        [_x] call NeroAI_fnc_tacticStop;[_x] call NeroAI_fnc_routeStop;
        _x setVariable ["NeroWL_logisticsUntil",_lease # 2];
        _x setVariable ["NeroWL_vehicleService",true,true];
        _x setVariable ["NeroWL_vehicleServiceLease",_lease];
        _x setVariable ["NeroWL_repairVehicle",_target];
    };
} forEach ([_group,_driverGroup] arrayIntersect [_group,_driverGroup]);
private _oldSpeed = getForcedSpeed _target;
_target forceSpeed 0;
_target setVariable ["NeroWL_repairLease",_lease];
_target setVariable ["NeroWL_repairHeld",[_held,_oldSpeed,isEngineOn _target]];
_group setVariable ["NeroWL_vehicleService",true,true];
if (!isNull driver _target && {!isPlayer driver _target}) then {doStop driver _target;};
_target engineOn false;
_group setVariable ["NeroAI_repairStatus","ENGINEER_ASSIGNED",true];
[_group,getPosATL _target,"COVER"] call NeroAI_fnc_requestSupport;
[_group,_target,_engineer,_token,_lease] spawn NeroAI_fnc_repairWorker;
[true,"Механик направлен к машине, прикрытие запрошено. Результат будет подтверждён по компонентам и подвижности."]
