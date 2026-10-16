/* Owned paths from HQ and the adjacent capturable frontier. */
params ["_owners","_links","_root","_side"];
private _connected=[];private _frontier=[];private _queue=[];
if (_root>=0 && {_root<count _owners} && {(_owners#_root)==_side}) then {_queue pushBack _root;};
while {count _queue>0} do {
 private _node=_queue deleteAt 0;
 if !(_node in _connected) then {_connected pushBack _node;
  {private _next=if ((_x#0)==_node) then {_x#1} else {if ((_x#1)==_node) then {_x#0} else {-1}};
   if (_next>=0 && {(_owners#_next)==_side} && {!(_next in _connected)}) then {_queue pushBackUnique _next;};
  } forEach _links;
 };
};
{_x params ["_a","_b"];if (_a in _connected && {(_owners#_b)!=_side}) then {_frontier pushBackUnique _b;};if (_b in _connected && {(_owners#_a)!=_side}) then {_frontier pushBackUnique _a;};} forEach _links;
[_connected,_frontier]
