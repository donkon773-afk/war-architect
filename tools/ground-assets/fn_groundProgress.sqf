params ["_progress","_attackers","_defenders","_elapsed","_target"];
private _state="empty";
if (_attackers>0 && {_defenders==0}) then {_progress=(_progress+_elapsed) min _target;_state="capturing";} else {
 if (_attackers>0 && {_defenders>0}) then {_state="contested";} else {_progress=(_progress-_elapsed) max 0;if (_defenders>0) then {_state="defended";};};
};
[_progress,_state]
