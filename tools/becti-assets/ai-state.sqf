/* Readiness is physical, not the presence of a purchase/waypoint. */
params ["_group"];
private _role=_group getVariable ["cti_role","Infantry"];
private _live=units _group select {alive _x && {!(_x getVariable ["ACE_isUnconscious",false])}};
private _vehicles=(_live apply {vehicle _x}) arrayIntersect (_live apply {vehicle _x});
_vehicles=_vehicles select {!(_x isKindOf "Man") && {alive _x} && {driver _x in _live || {effectiveCommander _x in _live}}};
private _owned=_group getVariable ["WA_BECTI_vehicle",objNull];if (!isNull _owned && {alive _owned} && {!(_owned in _vehicles)}) then {_vehicles pushBack _owned;};
private _v=_vehicles param [0,objNull];
private _infantry=_role in ["Infantry","InfantryAT","InfantryAA"];
private _desired=getNumber(missionConfigFile >> "CfgWarArchitectDoctrine" >> str side _group >> "groupSize");
private _minimum=(_desired max 1) min 5;
private _pending=(side _group call CTI_CO_FNC_GetSideStructures) findIf {(_x getVariable ["cti_queue_processing",[]]) findIf {count _x>4 && {(_x#4) isEqualTo _group}}>=0}>=0;
if (_infantry) exitWith {[count _live>=_minimum && {!_pending},_role,objNull,count _live,if (_pending) then {"RECRUITING"} else {if (count _live>=_minimum) then {"READY"} else {"INFANTRY"}},count _live]};
if (isNull _v) exitWith {[false,_role,objNull,count _live,"VEHICLE",count _live]};
private _seats=fullCrew [_v,"",true] select {toLower(_x#1)!="cargo" && {!(_x param [4,false])}};
private _crewOK=_seats findIf {isNull (_x#0) || {!alive (_x#0)} || {!((_x#0) in _live)} || {(_x#0) getVariable ["ACE_isUnconscious",false]}}<0;
private _reason="READY";
if (!_crewOK) then {_reason="CREW";};
if ((!canMove _v && {getNumber(configFile >> "CfgVehicles" >> typeOf _v >> "maxSpeed")>0}) || {damage _v>.65}) then {_reason="DAMAGED";};
if (fuel _v<.2) then {_reason="FUEL";};
if (_v isKindOf "Air" && {!someAmmo _v}) then {_reason="AMMO";};
private _cargoSlots=fullCrew [_v,"cargo",true];
if (_reason=="READY" && {_role in ["Mechanized","Motorized"]} && {count _cargoSlots>=3}) then {
 private _cargo=fullCrew [_v,"cargo",false] select {(_x#0) in _live};
 if (count _cargo<3 && {!((_group getVariable ["WA_BECTI_dismountedFor",objNull]) isEqualTo (_group getVariable ["cti_order_pos",objNull]))}) then {_reason="BOARDING";};
};
if (_reason=="READY" && {_pending}) then {_reason="RECRUITING";};
private _power=(count _live)+(if (_role=="Armored") then {10} else {if (_role=="Mechanized") then {6} else {3}});
[_reason=="READY",_role,_v,count _live,_reason,_power]
