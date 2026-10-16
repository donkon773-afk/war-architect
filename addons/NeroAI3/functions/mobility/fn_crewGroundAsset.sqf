/* Idempotent delivery hook for a paid AI ground vehicle. Dedicated crew group
 * keeps the infantry roster and its native subordinate limit intact. */
params ["_vehicle","_parent","_payer"];
if (!isServer || {isNull _vehicle} || {!local _vehicle} || {!alive _vehicle} || {!(_vehicle isKindOf "LandVehicle")} || {getNumber (configOf _vehicle >> "isUav") == 1}) exitWith {[false,"Недоступная наземная машина."]};
if (_vehicle getVariable ["NeroWL_crewProvisioned",false]) exitWith {[true,"Экипаж уже сформирован."]};
private _rows = fullCrew [_vehicle,"",true];
private _descriptors = _rows apply {[_x param [1,""],_x param [4,false],!isNull (_x param [0,objNull]) || {!isNull (_x param [5,objNull])}]};
private _indices = [_descriptors] call NeroAI_fnc_crewSeatRoles;
private _profile = [typeOf _vehicle,_parent] call NeroAI_fnc_groundCrewProfile;
if (count _indices > 8 || {count _indices > (["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity)} || {_profile # 1 <= 0}) exitWith {[false,"Нет места для необходимого экипажа в лимите NPC."]};
if (_indices isEqualTo []) exitWith {[false,"Места экипажа уже заняты или зарезервированы."]};
private _crewGroup = createGroup [side _parent,true];
if (isNull _crewGroup) exitWith {[false,"Не создана группа экипажа."]};
private _created = [];private _complete = true;
{
    private _seat = _rows # _x;
    private _unit = _crewGroup createUnit [_profile # 0,getPosATL _vehicle,[],0,"NONE"];
    if (isNull _unit) exitWith {_complete = false;};
    _created pushBack _unit;
    switch (toLower (_seat # 1)) do {
        case "driver": {_unit assignAsDriver _vehicle;_unit moveInDriver _vehicle;};
        case "gunner": {_unit assignAsGunner _vehicle;_unit moveInGunner _vehicle;};
        case "commander": {_unit assignAsCommander _vehicle;_unit moveInCommander _vehicle;};
        case "turret": {_unit assignAsTurret [_vehicle,_seat # 3];_unit moveInTurret [_vehicle,_seat # 3];};
    };
    if (vehicle _unit != _vehicle) exitWith {_complete = false;};
} forEach _indices;
private _actual = fullCrew [_vehicle,"",true];
if ((_actual findIf {(toLower (_x # 1)) isEqualTo "driver"}) >= 0 && {isNull driver _vehicle}) then {_complete = false;};
if (!_complete || {count _created != count _indices}) exitWith {
    {if (vehicle _x == _vehicle) then {_vehicle deleteVehicleCrew _x;} else {deleteVehicle _x;};} forEach _created;
    deleteGroup _crewGroup;
    [false,"Экипаж не занял все необходимые места; повторный спавн остановлен."]
};
private _mechanic = driver _vehicle;
if (!isNull _mechanic) then {
    _mechanic setUnitTrait ["Engineer",true];_mechanic setVariable ["ACE_IsEngineer",1,true];
    if (!("ToolKit" in items _mechanic) && {_mechanic canAdd "ToolKit"}) then {_mechanic addItem "ToolKit";};
    if (!("ToolKit" in items _mechanic) && {!("ToolKit" in itemCargo _vehicle)}) then {_vehicle addItemCargoGlobal ["ToolKit",1];};
};
private _enrolled = [objNull,_crewGroup,true] call NeroAI_fnc_registerGroup;
if !(_enrolled # 0) exitWith {
    {_vehicle deleteVehicleCrew _x;} forEach _created;deleteGroup _crewGroup;
    [false,"Экипаж не зарегистрирован в командовании NeroAI."]
};
_crewGroup setVariable ["NeroAI_isEnemy",_parent getVariable ["NeroAI_isEnemy",false],true];
_crewGroup setVariable ["NeroWL_parentGroup",_parent,true];
_crewGroup setVariable ["BIS_WL_groupVehs",[_vehicle],true];
_crewGroup setVariable ["NeroWL_role",if (_vehicle isKindOf "Tank" && {getNumber (configOf _vehicle >> "transportSoldier") < 4}) then {"ARMOR"} else {"MECHANIZED"},true];
_crewGroup setVariable ["NeroWL_rulesMission",_parent getVariable ["NeroWL_rulesMission",[]]];
_crewGroup setVariable ["NeroWL_logisticsUntil",diag_tickTime+125];
_crewGroup setVariable ["NeroAI_forcePlan",true,true];
[_vehicle,_crewGroup] spawn {
    params ["_vehicle","_crewGroup"];
    private _deadline = diag_tickTime+120;
    waitUntil {sleep 1;isNull _vehicle || {!alive _vehicle} || {isNull attachedTo _vehicle && {(getPosATL _vehicle # 2) < 3}} || {diag_tickTime >= _deadline}};
    if (isNull _crewGroup) exitWith {};
    _crewGroup setVariable ["NeroWL_logisticsUntil",0];
    if (!isNull _vehicle && {alive _vehicle} && {isNull attachedTo _vehicle} && {(getPosATL _vehicle # 2) < 3}) then {
        _vehicle setVariable ["NeroWL_crewDeliveryState","LANDED",true];
        _crewGroup setVariable ["NeroAI_forcePlan",true,true];
    } else {
        _vehicle setVariable ["NeroWL_crewDeliveryState","DELIVERY_FAILED",true];
        _crewGroup setVariable ["NeroAI_playerHold",true,true];
        ["WARN",format ["CREW %1 delivery not landed; autonomous movement suspended",groupId _crewGroup]] call NeroAI_fnc_log;
    };
};
private _children = _parent getVariable ["NeroWL_ownedCrewGroups",[]];_children pushBackUnique _crewGroup;
_parent setVariable ["NeroWL_ownedCrewGroups",_children,true];
_vehicle setVariable ["NeroWL_crewGroup",_crewGroup,true];
_vehicle setVariable ["NeroWL_crewProvisioned",true,true];
_vehicle setVariable ["NeroAI_ownerSide",side _parent,true];
["INFO",format ["CREW %1 vehicle=%2 occupied=%3 verified=true parent=%4",groupId _crewGroup,typeOf _vehicle,count _created,groupId _parent]] call NeroAI_fnc_log;
[true,format ["Экипаж: %1 мест занято.",count _created]]
