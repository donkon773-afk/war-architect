/* Only reported contacts. Shared cache avoids targetsQuery for every asset. */
NeroOP_campIntel=[[],[]];
while {!NeroOP_campFinished} do {
 for "_side" from 0 to 1 do {
  private _seen=[];private _rows=[];private _sources=(NeroOP_campGroups select {(_x getVariable ["NeroOP_side",-1])==_side}) apply {leader _x};
  {_sources append crew (_x#4);} forEach (NeroOP_campEquipment select {(_x#1)==_side && {alive (_x#4)}});
  {if (alive _x) then {
   {private _target=_x#1;if ((_x#0)>=.5 && {(_x#5)<=45} && {!isNull _target} && {alive _target} && {!(_target in _seen)} && {([west,east]#_side) getFriend (_x#2)<.6}) then {
    _seen pushBack _target;private _air=_target isKindOf "Air";private _role=_target getVariable ["NeroOP_assetCategory",""];
    private _priority=if (_role in ["SAM","AAA","RADAR"]) then {0} else {if (_target isKindOf "LandVehicle") then {1} else {2}};
    _rows pushBack [_target,+(_x#4),_air,_priority,_x#5];
   };} forEach (_x targetsQuery [objNull,[east,west]#_side,"",[],45]);
  };} forEach (_sources arrayIntersect _sources);
  NeroOP_campIntel set [_side,_rows select [0,128]];
  {private _v=_x#4;if ((_x#1)==_side && {alive _v} && {_v getVariable ["NeroOP_assetCategory",""] in ["AAA","SAM","RADAR"]}) then {_v setVariable ["NeroOP_reconAirApproach",_rows findIf {(_x#2) && {_v distance2D (_x#1)<16000}}>=0,true];};} forEach NeroOP_campEquipment;
 };
 sleep 10;
};
