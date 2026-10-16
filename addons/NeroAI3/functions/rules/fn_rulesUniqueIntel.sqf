/* PURE: moving observations of one netId are one defender, newest wins.
 * Without an identity use a conservative type/20 m cell fallback. */
params [["_rows",[],[[]]]];
private _keys = [];
private _out = [];
{
    private _id = _x param [5,""];
    private _position = _x param [1,[0,0]];
    private _key = if (_id isEqualType "" && {_id != ""}) then {"id:" + _id} else {
        format ["%1:%2:%3",_x param [0,""],round ((_position # 0)/20),round ((_position # 1)/20)]
    };
    private _index = _keys find _key;
    if (_index < 0) then {_keys pushBack _key;_out pushBack _x;} else {
        if ((_x param [3,0]) >= ((_out # _index) param [3,0])) then {_out set [_index,_x];};
    };
} forEach _rows;
_out
