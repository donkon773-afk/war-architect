// Pure bounded accounting. A flight may be issued and lost exactly once.
params ["_state","_mode","_side","_id",["_credit",-1],["_budgets",[36,36]]];
private _stats=(_state#0) apply {+_x};
private _flights=(_state#1) apply {+_x};
private _ok=false;
if !(_side in [0,1] && {_id isEqualType ""} && {_id!=""} && {count _id<=80}) exitWith {[_state,false]};
private _index=_flights findIf {(_x#0)==_id};
if (_mode=="SPAWN" && {_index<0} && {((_stats#_side)#0)<(_budgets#_side)} && {count _flights<168}) then {
 private _row=_stats#_side; _row set [0,(_row#0)+1];
 _flights pushBack [_id,_side,false]; _ok=true;
};
if (_mode=="LOSS" && {_index>=0} && {((_flights#_index)#1)==_side} && {!((_flights#_index)#2)}) then {
 (_flights#_index) set [2,true]; private _row=_stats#_side; _row set [1,(_row#1)+1];
 if (_credit in [0,1] && {_credit!=_side}) then {private _winner=_stats#_credit; _winner set [2,(_winner#2)+1];};
 _ok=true;
};
[[_stats,_flights],_ok]
