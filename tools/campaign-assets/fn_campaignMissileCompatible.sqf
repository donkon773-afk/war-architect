/* Config flags may be permissive inheritance; weaponLockSystem defines required guidance. */
params ["_airTarget","_airLock","_manual","_laser","_locks","_arm","_emitting"];
private _independent=(_locks mod 4)>0 || {(floor(_locks/8) mod 2)>0};
!_manual && {!_laser || {_independent}} && {if (_airTarget) then {_airLock>=2 && {!_arm}} else {_airLock<2 || {_arm}}} && {!_arm || {_emitting}}
