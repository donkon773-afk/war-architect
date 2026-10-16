/* PURE. A timeout never relaxes readiness. Vehicle crews use vehicle readiness,
 * not an infantry headcount. Small foot groups require an explicit profile. */
params [["_effective",0,[0]],["_initial",0,[0]],["_vehicleReady",false,[false]],
    ["_minimum",6,[0]],["_minimumRatio",0.6,[0]],["_suppression",0,[0]]];
_minimum = (round _minimum) max 1 min 20;
_minimumRatio = _minimumRatio max 0.1 min 1;
private _ratio = if (_initial > 0) then {(_effective / _initial) min 1} else {0};
if (_vehicleReady) exitWith {[true,"готовый экипаж боевой машины",_ratio]};
if (_effective < _minimum) exitWith {[false,"мало боеспособных бойцов",_ratio]};
if (_ratio < _minimumRatio) exitWith {[false,"отделение требует восстановления",_ratio]};
if (_suppression >= 0.75) exitWith {[false,"отделение подавлено",_ratio]};
[true,"отделение готово",_ratio]
