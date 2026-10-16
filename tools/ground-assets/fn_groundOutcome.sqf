params ["_progress","_target","_remaining","_living","_reserves","_attacker"];
private _defender=1-_attacker;
if (_progress>=_target) exitWith {_attacker};
if (_remaining<=0) exitWith {_defender};
if ((_living#_attacker)==0 && {(_reserves#_attacker)==0}) exitWith {_defender};
-1
