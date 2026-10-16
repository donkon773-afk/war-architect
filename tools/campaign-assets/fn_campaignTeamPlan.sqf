/* Pure bounded allocation. Keep a field force when HQ is attacked. */
params ["_count","_baseThreat","_friendly","_enemy","_ready"];
private _defenders=if (_baseThreat && {_count>1}) then {(ceil(_count*.3)) max 1 min (_count-1)} else {if (_baseThreat) then {_count} else {0}};
[_defenders,_count-_defenders,_ready && {_friendly>=(_enemy*1.2) max 2}]
