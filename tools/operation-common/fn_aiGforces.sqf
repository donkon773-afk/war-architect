/* Each owner samples its local AI pilots; player and Zeus control use ACE itself. */
if (missionNamespace getVariable ["NeroOP_gforcesStarted",false]) exitWith {};
NeroOP_gforcesStarted=true;
if (isNumber(missionConfigFile >> "CfgNeroOperation" >> "Gameplay" >> "aiGforces") && {getNumber(missionConfigFile >> "CfgNeroOperation" >> "Gameplay" >> "aiGforces")==0}) exitWith {};
[] spawn {
 while {true} do {
  sleep .2;
  if (missionNamespace getVariable ["ace_gforces_enabledFor",1]>0) then {
   {private _plane=_x;
    if (local _plane && {alive _plane} && {_plane isKindOf "Air"} && {getNumber(configOf _plane >> "isUav")==0}) then {
     private _now=diag_tickTime;private _previous=_plane getVariable ["NeroOP_gSample",[]];private _velocity=velocity _plane;
     if (count _previous==2) then {private _dt=_now-(_previous#0);
      if (_dt>.05 && {_dt<2}) then {private _g=[_velocity,_previous#1,_dt,vectorUp _plane,missionNamespace getVariable ["ace_gforces_coef",1]] call NeroOP_fnc_aiGForce;
       private _history=(_plane getVariable ["NeroOP_gHistory",[]]) select {(_x#0)>_now-6};_history pushBack [_now,_g,_dt];_plane setVariable ["NeroOP_gHistory",_history];private _sum=0;private _weight=0;{_sum=_sum+(_x#1)*(_x#2);_weight=_weight+(_x#2);} forEach _history;
       if (_weight>=5.8) then {private _average=_sum/_weight;
        {private _unit=_x;private _human=isPlayer _unit || {isRemoteControlling _unit} || {!isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])};
         if (local _unit && {alive _unit} && {!_human} && {!(_unit getVariable ["ACE_isUnconscious",false])} && {!isNil "ace_medical_fnc_setUnconscious"}) then {
          private _unitCoef=_unit getVariable ["ACE_GForceCoef",getNumber(configOf _unit >> "ACE_GForceCoef")];private _suit=if (uniform _unit=="") then {1} else {getNumber(configFile >> "CfgWeapons" >> uniform _unit >> "ACE_GForceCoef")};private _threshold=[_unitCoef,_suit] call NeroOP_fnc_aiGThreshold;
          if (_average>_threshold) then {[_unit,true,10+floor(random 5),true] call ace_medical_fnc_setUnconscious;diag_log format ["[NeroOP GFORCES] AI blackout unit=%1 G=%2 threshold=%3",typeOf _unit,_average,_threshold];};
         };
        } forEach crew _plane;
       };
      } else {_plane setVariable ["NeroOP_gHistory",[]];};
     };
     _plane setVariable ["NeroOP_gSample",[_now,_velocity]];
    };
   } forEach vehicles;
  };
 };
};
