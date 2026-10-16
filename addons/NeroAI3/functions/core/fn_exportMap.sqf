/* Explicit one-time cartographic survey; never runs on normal tactical ticks. */
if(!isServer || {isNil "OO_INIDBI"} || {missionNamespace getVariable["NeroWL_mapBusy",false]})exitWith{};
NeroWL_mapBusy=true;
private _db=["new","NeroWL_map_"+worldName]call OO_INIDBI;private _size=worldSize;private _step=ceil(_size/256);private _seen=createHashMap;private _roadSeen=createHashMap;private _buildingsTotal=0;private _roadsTotal=0;private _chunk=0;private _truncated=false;
["write",["META","ready",false]]call _db;["write",["META","size",_size]]call _db;["write",["META","step",_step]]call _db;
for "_y" from 0 to 255 do{
 private _row=[];for "_x" from 0 to 255 do{_row pushBack round getTerrainHeightASL[(_x+0.5)*_step,(_y+0.5)*_step];};["write",["HEIGHT",str _y,_row]]call _db;sleep 0.005;
};
for "_y" from 0 to (ceil(_size/1024)-1)do{
 for "_x" from 0 to (ceil(_size/1024)-1)do{
  private _center=[_x*1024+512,_y*1024+512,0];private _houses=[];private _roads=[];
  {
   private _p=getPosATL _x;private _key=str _x;
   if(!(_seen getOrDefault[_key,false]) && {_buildingsTotal<50000})then{_seen set[_key,true];private _bb=boundingBoxReal _x;private _a=_bb#0;private _b=_bb#1;_houses pushBack[round(_p#0),round(_p#1),round(abs((_b#0)-(_a#0)))max 1,round(abs((_b#1)-(_a#1)))max 1,round getDir _x];_buildingsTotal=_buildingsTotal+1;};
  }forEach(nearestTerrainObjects[_center,["HOUSE"],730,false,true]);
  {
   private _road=_x;private _p=getPosATL _road;{private _pair=[str _road,str _x];_pair sort true;private _key=_pair joinString ":";if(!(_roadSeen getOrDefault[_key,false]) && {_roadsTotal<50000})then{_roadSeen set[_key,true];private _q=getPosATL _x;_roads pushBack[round(_p#0),round(_p#1),round(_q#0),round(_q#1)];_roadsTotal=_roadsTotal+1;};}forEach roadsConnectedTo _road;
  }forEach(_center nearRoads 730);
  if(_buildingsTotal>=50000 || {_roadsTotal>=50000})then{_truncated=true;};
  ["write",["HOUSES",str _chunk,_houses]]call _db;["write",["ROADS",str _chunk,_roads]]call _db;_chunk=_chunk+1;["write",["META","chunks",_chunk]]call _db;sleep 0.02;
 };
};
["write",["META","truncated",_truncated]]call _db;["write",["META","ready",true]]call _db;NeroWL_mapBusy=false;
diag_log format["[NeroWL Map] survey complete world=%1 houses=%2 roads=%3 truncated=%4",worldName,_buildingsTotal,_roadsTotal,_truncated];
