params [["_plane",objNull,[objNull]],["_unit",objNull,[objNull]],["_toggle",false,[true]]];
if (!hasInterface || {isNull _plane} || {!alive _plane} || {_unit!=player} || {!alive _unit} || {!local _unit} || {!local _plane} || {driver _plane!=_unit}) exitWith {false};
if !(_plane isKindOf "JS_JC_FA18E" || {_plane isKindOf "JS_JC_FA18F"}) exitWith {false};
// Match the installed aircraft's native HMD button: the animation alone is
// insufficient; its helmet display draws only while numeric MFD user48 is 1.
private _enabled=if (_toggle) then {!(_plane getVariable ["FA18_JHMCS",false])} else {true};
private _value=if (_enabled) then {1} else {0};
_plane animate ["Switch_hmd",_value,true];
_plane setUserMFDValue [48,_value];
_plane setVariable ["FA18_JHMCS",_enabled];
_unit setVariable ["NeroOP_notice",if (_enabled) then {"F/A-18: прицел шлема включён."} else {"F/A-18: прицел шлема выключен."}];
diag_log format ["[NeroOP AIR] HELMET class=%1 enabled=%2",typeOf _plane,_enabled];
true
