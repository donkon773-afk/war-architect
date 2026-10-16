params [["_plane",objNull,[objNull]],["_unit",objNull,[objNull]],["_repair",false,[true]]];
if (!hasInterface || {isNull _plane} || {!alive _plane} || {_unit!=player} || {!local _unit} || {!local _plane} || {driver _plane!=_unit}) exitWith {false};
if !(_plane isKindOf "JS_JC_FA18E" || {_plane isKindOf "JS_JC_FA18F"}) exitWith {false};
if (!_repair && {(_plane getVariable ["NeroOP_avionicsPilot",objNull])==_unit}) exitWith {true};
if (isNil "js_jc_fa18_core_fnc_aircraftEntered" || {isNil "js_jc_fa18_core_fnc_systemStop"}) exitWith {
 _unit setVariable ["NeroOP_notice","Не найдены функции систем F/A-18. Проверьте загрузку мода самолёта."];
 diag_log "[NeroOP AIR] AVIONICS ERROR missing FA18 core functions";
 false
};
// moveInDriver bypasses the aircraft's GetIn handler. Start the installed
// aircraft's own systems once, on the pilot's computer after the air handoff.
private _active=_plane getVariable ["js_jc_fa18_systems_active",[]];
private _bound=missionNamespace getVariable ["js_jc_fa18_vehicle",objNull];
if !(_bound==_plane && {"cockpit" in _active} && {"mfd" in _active}) then {
 {[_plane,_x] call js_jc_fa18_core_fnc_systemStop;} forEach +_active;
 [_plane,"driver",_unit,[]] call js_jc_fa18_core_fnc_aircraftEntered;
};
// This operation starts in flight. Power the instruments on this aircraft;
// preserve the user's global CBA startup preference and subsequent switches.
{_plane setVariable [_x,true];} forEach ["Generator","Battery","HUD"];
{_plane animate [_x,1,true];} forEach ["Switch_genR","Switch_genL","Switch_battery","Switch_hud","Batt1Knot","Batt2Knot","Canopy_anim","Switch_radar","Switch_console","Switch_console2"];
{_plane animate [_x,0,true];} forEach ["fuel_hide","Console_panels","Console_front"];
_plane enableVehicleSensor ["ActiveRadarSensorComponent",true];
_plane setVehicleRadar 1;
[_plane,_unit] call NeroOP_fnc_airHelmet;
_plane setVariable ["NeroOP_avionicsPilot",_unit];
diag_log format ["[NeroOP AIR] AVIONICS READY class=%1 systems=%2",typeOf _plane,_plane getVariable ["js_jc_fa18_systems_active",[]]];
true
