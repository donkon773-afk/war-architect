/* Native combat remains available; aircraft alone must not freeze an entire march. */
while {!NeroOP_campFinished} do {
 {private _g=_x;private _side=_g getVariable ["NeroOP_side",-1];
  if (local _g && {!(_g getVariable ["NeroOP_staging",false])} && {[false,_g getVariable ["NeroOP_liftBusy",false],_g getVariable ["NeroOP_rideBusy",false],_g getVariable ["NeroOP_dropBusy",false]] call NeroOP_fnc_campaignTransitGate} && {_side in [0,1]} && {alive leader _g}) then {
   private _human=[_g] call NeroOP_fnc_campaignPlayerControl;
   private _contacts=NeroOP_campIntel#_side;private _ground=_contacts findIf {!(_x#2) && {alive (_x#0)} && {leader _g distance2D (_x#1)<650}}>=0;
   private _air=_contacts select {(_x#2) && {alive (_x#0)} && {leader _g distance2D (_x#1)<4500}};
   {private _u=_x;if (local _u && {alive _u} && {!isPlayer _u}) then {
    if (_human) then {if (_u getVariable ["NeroOP_mobilityManaged",false]) then {_u enableAI "AUTOCOMBAT";_u setVariable ["lambs_danger_disableAI",_u getVariable ["NeroOP_oldLambs",false]];_u setVariable ["NeroOP_mobilityManaged",false];_u forceSpeed -1;};} else {
     if !(_u getVariable ["NeroOP_mobilityManaged",false]) then {_u setVariable ["NeroOP_oldLambs",_u getVariable ["lambs_danger_disableAI",false]];_u setVariable ["NeroOP_mobilityManaged",true];};
     _u setVariable ["lambs_danger_disableAI",true];
     if (_ground) then {_u enableAI "AUTOCOMBAT";_u forceSpeed -1;} else {_u disableAI "AUTOCOMBAT";if (vehicle _u==_u) then {_u setUnitPos "AUTO";_u forceWalk false;_u forceSpeed -1;};};
     if (!_ground && {count _air>0} && {vehicle _u==_u} && {serverTime-(_u getVariable ["NeroOP_aaAt",-30])>15}) then {
      private _launcher=secondaryWeapon _u;private _mags=getArray(configFile >> "CfgWeapons" >> _launcher >> "magazines");
      if (_launcher!="" && {_mags findIf {getNumber(configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> _x >> "ammo") >> "airLock")>0}>=0}) then {
       private _target=(_air#0)#0;_u setVariable ["NeroOP_aaAt",serverTime];_u selectWeapon _launcher;_u reveal [_target,2];_u doTarget _target;_u doFire _target;
      };
     };
    };
   };} forEach units _g;
   if (!_human) then {
    _g setSpeedMode "FULL";_g setBehaviourStrong (if (_ground) then {"COMBAT"} else {"AWARE"});
    private _target=_g getVariable ["NeroOP_campTarget",-1];
    if (!_ground && {!(_g getVariable ["NeroOP_attackHold",false])} && {_target>=0} && {!(_g getVariable ["NeroOP_liftBusy",false])} && {leader _g distance2D (NeroOP_campPositions#_target)>NeroOP_campRadii#_target} && {vehicle leader _g==leader _g}) then {
     private _p=getPosATL leader _g;private _anchor=_g getVariable ["NeroOP_moveAnchor",[_p,serverTime]];
     if (_p distance2D (_anchor#0)>20) then {_g setVariable ["NeroOP_moveAnchor",[_p,serverTime]];} else {
      if (serverTime-(_anchor#1)>35) then {private _dest=NeroOP_campPositions#_target;{if (local _x && {alive _x} && {vehicle _x==_x}) then {_x doMove _dest;};} forEach units _g;_g setVariable ["NeroOP_moveAnchor",[_p,serverTime]];diag_log format ["[NeroOP MOBILITY] MARCH RETRY group=%1 target=%2",_g getVariable ["NeroOP_groupKey",-1],_target];};
     };
     if (isNil {_g getVariable "NeroOP_moveAnchor"}) then {_g setVariable ["NeroOP_moveAnchor",[_p,serverTime]];};
    };
   };
  };
 } forEach +NeroOP_campGroups;
 sleep 5;
};
