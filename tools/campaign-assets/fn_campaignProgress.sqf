/* Result: owner, per-side progress, phase, side to charge (-1 means no capture). */
params ["_owner","_progress","_inside","_eligible","_elapsed","_target",["_frontier",[true,true]]];
private _p=+_progress;{if (!_x) then {_p set [_forEachIndex,0];};} forEach _frontier;private _delta=(_elapsed max 0) min 10;private _newOwner=_owner;private _charge=-1;private _phase="empty";
if ((_inside#0)>0 && {(_inside#1)>0}) then {_phase="contested";} else {
 private _side=if ((_inside#0)>0) then {0} else {if ((_inside#1)>0) then {1} else {-1}};
 if (_side>=0 && {_side!=_owner} && {_eligible#_side} && {_frontier#_side}) then {
  _phase="capturing";_p set [_side,((_p#_side)+_delta) min _target];_p set [1-_side,((_p#(1-_side))-_delta) max 0];
  if ((_p#_side)>=_target) then {_newOwner=_side;_charge=_side;_p=[0,0];_phase="captured";};
 } else {_p=_p apply {(_x-_delta) max 0};_phase=if (_side<0) then {"empty"} else {if (_side==_owner) then {"defended"} else {"unsupplied"}};};
};
[_newOwner,_p,_phase,_charge]
