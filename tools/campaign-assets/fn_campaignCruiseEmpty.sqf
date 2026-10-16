/* Tu-95 gun/flare ammunition must not disguise an empty cruise payload. */
params ["_v"];
private _rounds=0;{if (toLower _x find "kh55">=0) then {_rounds=_rounds+(_v ammoOnPylon (_forEachIndex+1));};} forEach getPylonMagazines _v;
if (_rounds<=0) then {{if (toLower (_x#0) find "kh55">=0) then {_rounds=_rounds+(_x#2);};} forEach magazinesAllTurrets [_v,true];};
_rounds<=0
