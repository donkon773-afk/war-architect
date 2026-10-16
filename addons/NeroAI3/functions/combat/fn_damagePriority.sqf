/* PURE: component diagnosis, separate from aggregate hull damage. */
params [["_names",[]],["_damage",[]]];
private _out = [];
{
    private _name = toLower _x;private _value = _damage param [_forEachIndex,0];
    private _priority = if ("engine" in _name || {"motor" in _name} || {"transmission" in _name}) then {100} else {
        if ("track" in _name) then {90} else {if ("wheel" in _name) then {80} else {if ("fuel" in _name) then {50} else {10}}}
    };
    if (_value > 0.45) then {_out pushBack [_priority+_value,_forEachIndex,_x,_value];};
} forEach _names;
/* Explicit numeric order; mixed array sort is not a portable priority queue. */
private _sorted = [];
while {_out isNotEqualTo []} do {
    private _best = 0;
    {if ((_x # 0) > ((_out # _best) # 0)) then {_best = _forEachIndex;};} forEach _out;
    _sorted pushBack (_out deleteAt _best);
};
_sorted
