/* PURE: short paths scaled to the hull. [name, point list]. No teleport.
 * Reverse first permits the engine to back away instead of turning in place. */
params ["_origin","_heading",["_width",3],["_length",6]];
private _back = ((_length * 0.8) max 5) min 10;
private _side = ((_width + 3) max 6) min 10;
private _forward = ((_length * 1.5) max 10) min 16;
private _offset = {
    params ["_right","_ahead"];
    [(_origin # 0)+sin _heading*_ahead+cos _heading*_right,(_origin # 1)+cos _heading*_ahead-sin _heading*_right,0]
};
[
    ["BACK",[[0,-_back] call _offset]],
    ["BACK_LEFT",[[0,-_back] call _offset,[-_side,-_back-3] call _offset]],
    ["BACK_RIGHT",[[0,-_back] call _offset,[_side,-_back-3] call _offset]],
    ["BYPASS_LEFT",[[0,-_back] call _offset,[-_side,-_back-3] call _offset,[-_side,_forward] call _offset]],
    ["BYPASS_RIGHT",[[0,-_back] call _offset,[_side,-_back-3] call _offset,[_side,_forward] call _offset]]
]
