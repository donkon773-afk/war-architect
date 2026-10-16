/* Min-heap for scheduled A*: row [estimatedCost,nodeIndex,knownCost]. */
params ["_heap","_row"];
if (count _row>0) exitWith {
 _heap pushBack _row;private _i=count _heap-1;
 while {_i>0} do {private _p=floor((_i-1)/2);if ((_heap#_p)#0<=(_heap#_i)#0) exitWith {};private _v=_heap#_p;_heap set [_p,_heap#_i];_heap set [_i,_v];_i=_p;};[]
};
if (count _heap==0) exitWith {[]};private _top=_heap#0;private _last=_heap deleteAt (count _heap-1);
if (count _heap>0) then {
 _heap set [0,_last];private _i=0;private _done=false;
 while {!_done} do {private _a=2*_i+1;private _b=_a+1;if (_a>=count _heap) then {_done=true;} else {private _small=_a;if (_b<count _heap && {(_heap#_b)#0<(_heap#_a)#0}) then {_small=_b;};if ((_heap#_i)#0<=(_heap#_small)#0) then {_done=true;} else {private _v=_heap#_i;_heap set [_i,_heap#_small];_heap set [_small,_v];_i=_small;};};};
};_top
