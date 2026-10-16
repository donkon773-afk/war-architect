/* PURE: native Warlords topology, including disconnected owned pockets.
 * Nodes [id, owner, adjacentIds]. Reachability starts at the owned base. */
params ["_nodes","_base","_side"];
private _map = createHashMapFromArray (_nodes apply {[_x # 0,_x]});
private _owned = (_nodes select {(_x # 1) isEqualTo _side}) apply {_x # 0};
if (!(_base in _owned)) exitWith {[_owned,[],[]]};
private _linked = [_base];private _queue = [_base];private _head = 0;
while {_head < count _queue} do {
    private _id = _queue # _head;_head = _head+1;
    {if (_x in _owned && {!(_x in _linked)}) then {_linked pushBack _x;_queue pushBack _x;};} forEach ((_map get _id) # 2);
};
private _available = [];
{
    private _id = _x # 0;
    if (!(_id in _owned) && {(_linked findIf {_id in ((_map get _x) # 2)}) >= 0}) then {_available pushBack _id;};
} forEach _nodes;
[_owned,_available,_linked]
