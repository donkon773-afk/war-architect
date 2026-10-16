/* Config-only estimate before paying; actual fullCrew seats are verified later.
 * Crew is included in vehicle price, subject to the global NPC limit. */
params ["_class","_group"];
private _cfg = configFile >> "CfgVehicles" >> _class;
private _crewClass = getText (_cfg >> "crew");
private _sideNumber = [east,west,resistance] find (side _group);
if (!isClass (configFile >> "CfgVehicles" >> _crewClass) || {getNumber (configFile >> "CfgVehicles" >> _crewClass >> "side") != _sideNumber}) then {
    _crewClass = typeOf leader _group;
};
private _count = if (getNumber (_cfg >> "hasDriver") > 0) then {1} else {0};
private _walk = {
    params ["_turrets",["_depth",0]];
    if (_depth > 4) exitWith {};
    {
        if (getNumber (_x >> "isPersonTurret") == 0) then {_count = _count+1;};
        [_x >> "Turrets",_depth+1] call _walk;
    } forEach ("true" configClasses _turrets);
};
[_cfg >> "Turrets"] call _walk;
[_crewClass,_count]
