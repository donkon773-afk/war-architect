/* Lifetime paid recruit credits remain even after the parent squad is destroyed. */
params ["_credits","_issued","_budgets","_sizes"];
if (!(_credits isEqualType []) || {count _credits>(_budgets#0)+(_budgets#1)}) exitWith {[false,[0,0]]};
private _valid=true;private _keys=[];private _counts=[0,0];private _totals=[0,0];
{if !(_x isEqualType [] && {count _x==3}) then {_valid=false;} else {
 _x params ["_side","_key","_count"];
 if (!(_side isEqualType 0) || {!(_side in [0,1])} || {!(_key isEqualType 0)} || {_key<1 || {_key>1000000} || {floor _key!=_key}} || {_key in _keys} || {!(_count isEqualType 0)} || {_count<1 || {floor _count!=_count}}) then {_valid=false;} else {
  _keys pushBack _key;_counts set [_side,(_counts#_side)+1];_totals set [_side,(_totals#_side)+_count];
 };
};} forEach _credits;
if ([0,1] findIf {(_counts#_x)>(_issued#_x) || {(_totals#_x)>(_budgets#_x)*(_sizes#_x)}}>=0) then {_valid=false;};
[_valid,_totals]
