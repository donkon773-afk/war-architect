if (!isServer || {missionNamespace getVariable ["NeroOP_zeusStarted",false]}) exitWith {};
NeroOP_zeusStarted=true;NeroOP_curators=[];
while {true} do {
 private _players=allPlayers select {isPlayer _x && {!(_x isKindOf "HeadlessClient_F")}};
 {
  private _unit=_x,_key=getPlayerUID _x;
  if (_key!="") then {
   private _found=NeroOP_curators findIf {(_x#0)==_key};private _logic=objNull;
   if (_found<0) then {
    private _group=createGroup [sideLogic,true];_logic=_group createUnit ["ModuleCurator_F",[0,0,0],[],0,"NONE"];
    if (!isNull _logic) then {_logic setVariable ["Addons",3,true];_logic addCuratorAddons activatedAddons;{_logic setCuratorCoef [_x,0];} forEach ["place","edit","delete","destroy","group","synchronize"];removeAllCuratorEditingAreas _logic;removeAllCuratorCameraAreas _logic;_logic addCuratorPoints 1;_logic addEventHandler ["CuratorObjectRegistered",{params ["_curator","_classes"];_classes apply {[true,0]};}];NeroOP_curators pushBack [_key,_logic];};
   } else {_logic=(NeroOP_curators#_found)#1;};
   if (!isNull _logic) then {
    if (getAssignedCuratorUnit _logic!=_unit) then {unassignCurator _logic;_unit assignCurator _logic;diag_log format ["[NeroOP ZEUS] ASSIGNED owner=%1",owner _unit];};
    private _objects=allUnits+vehicles+allDead+allMissionObjects "Thing"+allMissionObjects "Building";_objects=_objects arrayIntersect _objects;_logic addCuratorEditableObjects [_objects,true];
   };
  };
 } forEach _players;
 for "_i" from (count NeroOP_curators-1) to 0 step -1 do {
  private _row=NeroOP_curators#_i;
  if (_players findIf {getPlayerUID _x==(_row#0)}<0) then {private _logic=_row#1;private _group=group _logic;unassignCurator _logic;deleteVehicle _logic;deleteGroup _group;NeroOP_curators deleteAt _i;};
 };
 sleep 5;
};
