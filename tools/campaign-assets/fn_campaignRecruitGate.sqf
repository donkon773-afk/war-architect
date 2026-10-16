/* Pure admission/price rule. Includes detached crews; no client price or class string. */
params ["_classes","_index","_cost","_size","_ground","_loans","_stock","_used","_budget","_commander"];
private _int={params ["_v","_min","_max"];_v isEqualType 0 && {_v>=_min} && {_v<=_max} && {floor _v==_v}};
if (!(_classes isEqualType []) || {!([_index,0,count _classes-1] call _int)} || {!([_cost,10,500] call _int)} || {!([_size,2,12] call _int)} || {!([_ground,0,12] call _int)} || {!([_loans,0,4] call _int)} || {!([_used,0,6240] call _int)} || {!([_budget,0,6240] call _int)} || {!(_stock isEqualType 0)} || {!(_commander isEqualType true)}) exitWith {[false,0]};
private _price=(ceil (_cost/_size)) max 5;
[_commander && {_ground+_loans<12} && {_stock>=_price} && {_used<_budget},_price]
