// Pure win/lose rules. Crashes exhaust stock but do not grant a kill.
params ["_stats","_budgets","_target","_elapsed","_duration"];
private _west=(_stats#0)#2; private _east=(_stats#1)#2;
if (_west>=_target && {_east>=_target}) exitWith {["DRAW","score"]};
if (_west>=_target) exitWith {["WEST","score"]};
if (_east>=_target) exitWith {["EAST","score"]};
private _wEmpty=((_stats#0)#1)>=(_budgets#0);
private _eEmpty=((_stats#1)#1)>=(_budgets#1);
if (_wEmpty && {_eEmpty}) exitWith {["DRAW","stock"]};
if (_wEmpty) exitWith {["EAST","stock"]};
if (_eEmpty) exitWith {["WEST","stock"]};
if (_elapsed<_duration) exitWith {["","running"]};
if (_west!=_east) exitWith {[if (_west>_east) then {"WEST"} else {"EAST"},"time"]};
private _wLoss=(_stats#0)#1; private _eLoss=(_stats#1)#1;
if (_wLoss==_eLoss) exitWith {["DRAW","time"]};
[if (_wLoss<_eLoss) then {"WEST"} else {"EAST"},"time"]
