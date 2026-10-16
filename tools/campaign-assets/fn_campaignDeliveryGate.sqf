/* Pure admission, evaluated before aircraft or supplies are created/spent. */
params ["_base","_enabled","_count","_flights","_transport","_fighter","_safe"];
if (_count<1 || {_count>12}) exitWith {false};
_base || {!_enabled} || {_flights<2 && {_transport} && {_fighter} && {_safe}}
