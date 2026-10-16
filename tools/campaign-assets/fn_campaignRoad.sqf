/* Multi-start A*. Join only touching road ends on maps with incomplete native links. */
params ["_from","_to","_side"];
private _locked=false;private _deadline=diag_tickTime+90;
waitUntil {isNil {if (!(missionNamespace getVariable ["NeroOP_roadBusy",false]) || {diag_tickTime-(missionNamespace getVariable ["NeroOP_roadBusyAt",0])>25}) then {NeroOP_roadBusy=true;NeroOP_roadBusyAt=diag_tickTime;_locked=true;};};if (!_locked) then {sleep .05;};_locked || {diag_tickTime>_deadline} || {NeroOP_campFinished}};
if (!_locked || {NeroOP_campFinished}) exitWith {if (_locked) then {NeroOP_roadBusy=false;};[]};
private _result=call {
private _indices=[];for "_i" from 0 to count NeroOP_campPositions-1 do {_indices pushBack _i;};
private _usable={params ["_road"];private _info=getRoadInfo _road;private _p=getPosATL _road;
 !(_info param [2,false]) && {!surfaceIsWater _p || {_info param [8,false]}} && {_indices findIf {private _i=_x;(NeroOP_campOwners#_i)>=0 && {(NeroOP_campOwners#_i)!=_side} && {(NeroOP_campPositions#_i) distance2D _p<(NeroOP_campRadii#_i)+60}}<0}
};
private _starts=(_from nearRoads 450) select {[_x] call _usable};private _goals=(_to nearRoads 450) select {[_x] call _usable};
if (count _starts==0 || {count _goals==0}) exitWith {[]};
private _rank=[];{_rank pushBack [_x distance2D _from,_forEachIndex];} forEach _starts;_rank sort true;_starts=(_rank select [0,8]) apply {_starts#(_x#1)};
_rank=[];{_rank pushBack [_x distance2D _to,_forEachIndex];} forEach _goals;_rank sort true;_goals=(_rank select [0,8]) apply {_goals#(_x#1)};
private _roads=+_starts;private _parent=_starts apply {-1};private _cost=_starts apply {_x distance2D _from};private _open=[];{_open pushBack _forEachIndex;} forEach _starts;
private _lookup=createHashMap;{_lookup set [str _x,_forEachIndex];} forEach _roads;private _closed=createHashMap;private _scores=createHashMap;private _usableCache=createHashMap;private _found=-1;private _steps=0;private _clock=diag_tickTime;
private _heuristic={params ["_road"];private _d=1e12;{_d=_d min (_road distance2D _x);} forEach _goals;_d};
private _heap=[];{[_heap,[(_cost#_x)+([_roads#_x] call _heuristic),_x,_cost#_x]] call NeroOP_fnc_campaignHeap;} forEach _open;
while {count _heap>0 && {_found<0} && {_steps<16000} && {diag_tickTime-_clock<12}} do {
 private _head=[_heap,[]] call NeroOP_fnc_campaignHeap;private _current=_head#1;
 if (!(_closed getOrDefault [str _current,false]) && {(_head#2)==(_cost#_current)}) then {_closed set [str _current,true];_steps=_steps+1;private _road=_roads#_current;
 if (_road in _goals) then {_found=_current;} else {
  private _neighbors=NeroOP_campRoadEdges getOrDefault [str _road,[]];if (count _neighbors==0) then {_neighbors=roadsConnectedTo _road;private _info=getRoadInfo _road;
  /* Missing junction edges are repaired only when road endpoint geometry touches. */
  {private _end=_x;{private _other=_x;private _i=getRoadInfo _other;if (_other!=_road && {count _i>7} && {[[_info#6,_info#7],[_i#6,_i#7]] call NeroOP_fnc_campaignRoadJoin}) then {_neighbors pushBackUnique _other;};} forEach (_end nearRoads 35);} forEach (if (count _info>7) then {[_info#6,_info#7]} else {[]});NeroOP_campRoadEdges set [str _road,+_neighbors];};
  {private _roadKey=str _x;private _can=_usableCache getOrDefault [_roadKey,-1];if (_can==-1) then {_can=if ([_x] call _usable) then {1} else {0};_usableCache set [_roadKey,_can];};if (_can==1) then {private _next=_lookup getOrDefault [str _x,-1];private _v=(_cost#_current)+(_road distance2D _x);
   if (_next<0) then {_next=count _roads;_lookup set [str _x,_next];_roads pushBack _x;_cost pushBack _v;_parent pushBack _current;private _h=[_x] call _heuristic;_scores set [str _next,_h];[_heap,[_v+_h,_next,_v]] call NeroOP_fnc_campaignHeap;} else {if (!(_closed getOrDefault [str _next,false]) && {_v<(_cost#_next)}) then {_cost set [_next,_v];_parent set [_next,_current];[_heap,[_v+(_scores getOrDefault [str _next,[_x] call _heuristic]),_next,_v]] call NeroOP_fnc_campaignHeap;};};
  };} forEach _neighbors;
 };
 };
 if ((_steps mod 40)==0) then {sleep .001;};
};
if (_found<0) exitWith {diag_log format ["[NeroOP ROAD] FAIL side=%1 steps=%2 from=%3 to=%4",_side,_steps,_from,_to];[]};
private _route=[];while {_found>=0} do {_route pushBack (getPosATL (_roads#_found));_found=_parent#_found;};reverse _route;
private _points=[_route#0];{if ((_points#(count _points-1)) distance2D _x>=60) then {_points pushBack _x;};} forEach _route;
_points pushBack (_route#(count _route-1));_points pushBack _to;_points

};NeroOP_roadBusy=false;_result
