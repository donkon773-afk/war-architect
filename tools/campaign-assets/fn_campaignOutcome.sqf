params ["_owners","_roots"];
private _west=(_owners#(_roots#1))==0;private _east=(_owners#(_roots#0))==1;
if (_west && {_east}) exitWith {2};if (_west) exitWith {0};if (_east) exitWith {1};-1
