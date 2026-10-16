/* Connected node closest to a contested/frontier sector, not graph array order. */
params ["_side","_position"];
private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
private _rank=[];
{private _node=_x;private _distance=1e9;{_distance=_distance min ((NeroOP_campPositions#_node) distance2D (NeroOP_campPositions#_x));} forEach (_graph#1);
 if (((NeroOP_campProgress#_node)#(1-_side))>0) then {_distance=-1000;};
 _rank pushBack [_distance+(.08*(_position distance2D (NeroOP_campPositions#_node))),_node];
} forEach (_graph#0);_rank sort true;
if (count _rank==0) then {NeroOP_campRoots#_side} else {(_rank#0)#1}
