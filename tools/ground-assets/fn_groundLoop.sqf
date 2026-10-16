private _cfg=missionConfigFile >> "CfgNeroOperation",_zone=getArray(missionConfigFile >> "CfgNeroOperation" >> "zone");
private _radius=getNumber(_cfg >> "zoneRadius"),_target=getNumber(_cfg >> "captureSeconds"),_last=serverTime,_lastLog=serverTime;
while {!NeroOP_groundFinished} do {
 sleep 2;private _now=serverTime,_elapsed=(_now-_last) max 0;_last=_now;
 private _living=[0,0],_inside=[0,0];
 {private _g=_x,_index=_g getVariable ["NeroOP_side",-1];
  if (_index in [0,1]) then {
   {if (alive _x) then {_living set [_index,(_living#_index)+1];if (_x distance2D _zone<=_radius && {vehicle _x==_x} && {!captive _x} && {lifeState _x!="INCAPACITATED"} && {!(_x getVariable ["ACE_isUnconscious",false])}) then {_inside set [_index,(_inside#_index)+1];};};} forEach units _g;
   private _commander=_g getVariable ["NeroOP_slotCommander",objNull];
   if (_g getVariable ["NeroOP_claimed",false] && {units _g findIf {alive _x && {isPlayer _x}}<0} && {!alive _commander || {group _commander!=_g}} && {_now-(_g getVariable ["NeroOP_claimedAt",_now])>20}) then {_g setVariable ["NeroOP_claimed",false];_g setVariable ["NeroOP_slotCommander",objNull,true];};
  };
 } forEach NeroOP_groundGroups;
 private _capture=[NeroOP_groundCapture,_inside#NeroOP_groundAttacker,_inside#(1-NeroOP_groundAttacker),_elapsed,_target] call NeroOP_fnc_groundProgress;NeroOP_groundCapture=_capture#0;
 private _remaining=(getNumber(_cfg >> "duration")-(_now-NeroOP_groundStartedAt)) max 0;
 private _reserves=[0,1] apply {(NeroOP_groundBudget#_x)-(NeroOP_groundIssued#_x)};
 private _winner=[NeroOP_groundCapture,_target,_remaining,_living,_reserves,NeroOP_groundAttacker] call NeroOP_fnc_groundOutcome;
 NeroOP_groundState=[NeroOP_groundCapture,_capture#1,_remaining,_living,_reserves];publicVariable "NeroOP_groundState";
 if (_winner>=0) then {[_winner,if (NeroOP_groundCapture>=_target) then {"capture"} else {if (_remaining<=0) then {"timeout"} else {"attackers exhausted"}}] call NeroOP_fnc_groundFinish;} else {
  if (_now-NeroOP_groundLastWave>=getNumber(_cfg >> "reinforcementDelay")) then {NeroOP_groundLastWave=_now;{isNil {[_x] call NeroOP_fnc_groundSpawn;};} forEach [0,1];};
  {if (isPlayer _x && {alive _x} && {side group _x in [west,east]} && {!(group _x getVariable ["NeroOP_groundGroup",false])}) then {[_x] call NeroOP_fnc_groundRequest;};} forEach allPlayers;
 };
 if (_now-_lastLog>=30) then {_lastLog=_now;diag_log format ["[NeroOP GROUND] STATE capture=%1/%2 inside=%3 living=%4 reserve=%5 fps=%6",NeroOP_groundCapture,_target,_inside,_living,_reserves,diag_fps];};
};
