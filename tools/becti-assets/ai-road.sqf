/* Bounded multi-start road A*. No route means hold/retry, not a cross-country fallback. */
params ["_from","_to","_side"];
private _cache=missionNamespace getVariable ["WA_BECTI_roadEdges",createHashMap];
private _id=_side call CTI_CO_FNC_GetSideID;
private _blocked=CTI_Towns select {_x getVariable ["cti_town_sideID",_id]!=_id && {_x getVariable ["cti_town_sideID",2]!=2}};
private _usable={params ["_r"];private _i=getRoadInfo _r;count _i>7 && {!(_i param [2,false])} && {!surfaceIsWater getPosATL _r || {_i param [8,false]}} && {_blocked findIf {_r distance2D _x<350 && {_to distance2D _x>400}}<0}};
private _starts=(_from nearRoads 350) select {[_x] call _usable};private _goals=(_to nearRoads 350) select {[_x] call _usable};
if (count _starts==0 || {count _goals==0}) exitWith {[]};
private _rank=[];{_rank pushBack [_x distance2D _from,_forEachIndex];} forEach _starts;_rank sort true;_starts=(_rank select [0,6]) apply {_starts#(_x#1)};
_rank=[];{_rank pushBack [_x distance2D _to,_forEachIndex];} forEach _goals;_rank sort true;_goals=(_rank select [0,6]) apply {_goals#(_x#1)};
private _heuristic={params ["_r"];private _n=1e12;{_n=_n min (_r distance2D _x);} forEach _goals;_n};
private _roads=+_starts;private _parents=_starts apply {-1};private _cost=_starts apply {_x distance2D _from};
private _lookup=createHashMap;private _closed=createHashMap;private _heap=[];
{_lookup set [str _x,_forEachIndex];[_heap,[(_cost#_forEachIndex)+([_x] call _heuristic),_forEachIndex,_cost#_forEachIndex]] call NeroOP_fnc_campaignHeap;} forEach _starts;
private _found=-1;private _steps=0;private _until=diag_tickTime+4;
while {count _heap>0 && {_found<0} && {_steps<6000} && {diag_tickTime<_until}} do {
 private _head=[_heap,[]] call NeroOP_fnc_campaignHeap;private _current=_head#1;
 if (!(_closed getOrDefault [str _current,false]) && {(_head#2)==(_cost#_current)}) then {
  _closed set [str _current,true];_steps=_steps+1;private _road=_roads#_current;
  if (_road in _goals) then {_found=_current;} else {
   private _neighbors=_cache getOrDefault [str _road,[]];
   if (count _neighbors==0) then {
    _neighbors=roadsConnectedTo _road;private _info=getRoadInfo _road;
    if (count _info>7) then {{private _end=_x;{private _other=_x;private _i=getRoadInfo _other;if (_other!=_road && {count _i>7} && {[[_info#6,_info#7],[_i#6,_i#7]] call NeroOP_fnc_campaignRoadJoin}) then {_neighbors pushBackUnique _other;};} forEach (_end nearRoads 35);} forEach [_info#6,_info#7];};
    _cache set [str _road,+_neighbors];
   };
   {
    if ([_x] call _usable) then {
     private _key=str _x;private _next=_lookup getOrDefault [_key,-1];private _value=(_cost#_current)+(_road distance2D _x);
     if (_next<0) then {_next=count _roads;_lookup set [_key,_next];_roads pushBack _x;_parents pushBack _current;_cost pushBack _value;[_heap,[_value+([_x] call _heuristic),_next,_value]] call NeroOP_fnc_campaignHeap;} else {
      if (!(_closed getOrDefault [str _next,false]) && {_value<(_cost#_next)}) then {_cost set [_next,_value];_parents set [_next,_current];[_heap,[_value+([_x] call _heuristic),_next,_value]] call NeroOP_fnc_campaignHeap;};
     };
    };
   } forEach _neighbors;
  };
 };
 if (_steps mod 40==0) then {sleep .001;};
};
missionNamespace setVariable ["WA_BECTI_roadEdges",_cache];
if (_found<0) exitWith {diag_log format ["[WA BECTI ROAD] NO_ROUTE steps=%1 from=%2 to=%3",_steps,_from,_to];[]};
private _route=[];while {_found>=0} do {_route pushBack getPosATL (_roads#_found);_found=_parents#_found;};reverse _route;
private _points=[];{if (count _points==0 || {(_points#(count _points-1)) distance2D _x>=60}) then {_points pushBack _x;};} forEach _route;
_points pushBack _to;_points
