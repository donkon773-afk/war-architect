/* PURE: known threats only; acceptance is a risk estimate, not immunity. */
params ["_owned","_linked","_land","_frontDistance","_enemyDistance","_aaDistance","_corridorAA","_travel","_requestDistance"];
if (!_owned || {!_linked} || {!_land} || {_frontDistance < 800} || {_enemyDistance < 700} || {_aaDistance < 3000} || {_corridorAA < 2500}) exitWith {-1e9};
10000-_travel*0.15-_requestDistance*0.5+((_aaDistance min 6000)/100)
