/* PURE stable non-central CQB cells. Not a claim that a cell is cleared. */
params [["_centre",[0,0,0],[[]]],["_radius",150,[0]],["_slot",0,[0]]];
private _cells = [[-0.55,-0.45],[0.55,-0.45],[-0.55,0.45],[0.55,0.45],[0,-0.65],[0,0.65],[0,0]];
private _cell = _cells # (((round _slot) max 0) mod (count _cells));
private _r = (_radius max 40) min 400;
[(_centre # 0)+(_cell # 0)*_r,(_centre # 1)+(_cell # 1)*_r,0]
