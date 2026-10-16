/* Typed cooldown/reload state; a timer cannot invent a vehicle or evade a side-wide limit. */
params ["_state","_fleet"];
if !(_state isEqualType [] && {count _state==2}) exitWith {false};private _cd=_state#0;private _rows=_state#1;
if (!(_cd isEqualType []) || {count _cd!=2} || {!(_rows isEqualType [])} || {count _rows>2}) exitWith {false};
if ([0,1] findIf {!((_cd#_x) isEqualType 0) || {!((_cd#_x)>=0 && {(_cd#_x)<=1200})} || {(_cd#_x)<0} || {(_cd#_x)>([1200,900]#_x)}}>=0) exitWith {false};
private _seen=[];private _ok=true;
{if !(_x isEqualType [] && {count _x==4}) then {_ok=false;} else {_x params ["_side","_class","_key","_remaining"];if (!(_side in [0,1]) || {!(_class isEqualType "")} || {if (_side==0) then {toLower _class find "fp5"<0} else {toLower _class find "tu95"<0}} || {!(_class isEqualType "")} || {!(_key isEqualType 0)} || {!(_remaining isEqualType 0)} || {!(_remaining>=0 && {_remaining<=600})} || {_remaining<0} || {_remaining>([600,480]#_side)} || {_side in _seen} || {_fleet findIf {(_x#0)==_side && {(_x#1)==_class} && {(_x#2)==_key}}<0}) then {_ok=false;} else {_seen pushBack _side;};};} forEach _rows;
_ok
