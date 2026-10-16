params ["_owners","_links","_start","_end","_side"];
if (_start<0 || {_end<0} || {_start>=count _owners} || {_end>=count _owners} || {(_owners#_start)!=_side} || {(_owners#_end)!=_side}) exitWith {[]};
private _queue=[_start];private _seen=[_start];private _parent=[];_parent resize count _owners;
while {count _queue>0 && {!(_end in _seen)}} do {private _node=_queue deleteAt 0;
 {_x params ["_a","_b"];private _next=if (_a==_node) then {_b} else {if (_b==_node) then {_a} else {-1}};
  if (_next>=0 && {(_owners#_next)==_side} && {!(_next in _seen)}) then {_seen pushBack _next;_parent set [_next,_node];_queue pushBack _next;};
 } forEach _links;
};
if !(_end in _seen) exitWith {[]};private _path=[_end];private _node=_end;
while {_node!=_start} do {_node=_parent#_node;_path pushBack _node;};reverse _path;_path
