if (!hasInterface || {missionNamespace getVariable ["NeroOP_zeusClientStarted",false]}) exitWith {};
NeroOP_zeusClientStarted=true;private _last=objNull;private _lastLogic=objNull;
while {true} do {
 if (!isNull player && {player!=_last}) then {
  _last=player;
  player addAction ["Открыть Zeus",{if (!isNull getAssignedCuratorLogic player) then {["Terminate"] call BIS_fnc_EGSpectator;openCuratorInterface;} else {hint "Zeus ещё подготавливается. Повторите через несколько секунд.";};},nil,1.2,false,true,"","alive _this"];
 };
 private _logic=getAssignedCuratorLogic player;
 if (!isNull _logic && {_logic!=_lastLogic}) then {
  _lastLogic=_logic;{[_logic,_x,["%ALL"]] call BIS_fnc_setCuratorAttributes;} forEach ["object","player","group","waypoint","marker"];
  { _logic addEventHandler [_x,{(_this#1) spawn BIS_fnc_showCuratorAttributes;}]; } forEach ["CuratorObjectDoubleClicked","CuratorGroupDoubleClicked","CuratorWaypointDoubleClicked","CuratorMarkerDoubleClicked"];
 };
 sleep 1;
};
