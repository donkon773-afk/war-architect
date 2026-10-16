/* Separate postInit controller: owner-local simulation; pilot-local actions/HUD. */
if (missionNamespace getVariable ["NeroFlight_started",false]) exitWith {};
NeroFlight_started=true;
[] spawn {
 private _vehicles=[];private _scan=-10;private _last=diag_tickTime;
 while {true} do {
  private _now=diag_tickTime;private _dt=(_now-_last) max .01 min .25;_last=_now;
  if (_now-_scan>2) then {_scan=_now;_vehicles=vehicles select {_x isKindOf "Plane" && {alive _x} && {getText(configFile >> "CfgNeroFlight" >> typeOf _x >> "model")!=""}};};
  {
   private _v=_x;private _cfg=configFile >> "CfgNeroFlight" >> typeOf _v;
   private _cruise=getNumber(_cfg >> "cruise");private _max=getNumber(_cfg >> "maximum");private _dry=getNumber(_cfg >> "dryMaximum");private _ab=getNumber(_cfg >> "afterburner")==1;
   if (local _v && {alive _v}) then {
    private _pilot=driver _v;private _owner=_v getVariable ["NeroFlight_owner",-1];
    if (_owner!=clientOwner) then {_v setVariable ["NeroFlight_owner",clientOwner];_v setVariable ["NeroFlight_previousSpeed",vectorMagnitude velocity _v];_v setVariable ["NeroFlight_previousFuel",fuel _v];};
    private _boost=_v getVariable ["NeroFlight_boost",false];private _super=_v getVariable ["NeroFlight_supercruise",false];
    // Keep original ab_switch actions usable; don't spawn a second native AB script.
    private _phase=_v animationPhase "ab_switch";
    private _oldPhase=_v getVariable ["NeroFlight_nativePhase",0];
    if (abs(_phase-_oldPhase)>.1 && {isPlayer _pilot}) then {_boost=_phase>.1;_v setVariable ["NeroFlight_boost",_boost,true];};_v setVariable ["NeroFlight_nativePhase",_phase];
    if (_boost && {_v getVariable ["NeroFlight_supercruise",false]}) then {_super=false;_v setVariable ["NeroFlight_supercruise",false,true];};
    private _uav=UAVControl _v;private _remote=count _uav>0 && {!isNull (_uav#0)};
    private _playerCrew=(crew _v) findIf {isPlayer _x || {!isNull remoteControlled _x} || {(_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull]) in allPlayers}}>=0;
    if (alive _pilot && {!isPlayer _pilot} && {!_remote} && {!_playerCrew}) then {
     private _target=assignedTarget _pilot;private _combat=alive _target && {_v distance _target<15000} && {fuel _v>.3} && {!isTouchingGround _v};
     if (_combat!=_boost) then {_boost=_combat;_v setVariable ["NeroFlight_boost",_boost,true];};
    };
    if (!isEngineOn _v || {fuel _v<=0}) then {if (_boost) then {_boost=false;_v setVariable ["NeroFlight_boost",false,true];};};
    private _limit=if (_boost) then {_max} else {if (_super && {_dry>_cruise}) then {_dry} else {_cruise}};
    // Real maximum is an altitude-dependent envelope for supersonic types.
    if (_ab && {_boost}) then {private _height=(getPosASL _v)#2;private _sea=(_max min 1400);_limit=_sea+(_max-_sea)*((_height/11000) max 0 min 1);};
    private _velocity=velocity _v;private _speed=vectorMagnitude _velocity;
    private _power=if (isPlayer _pilot && {hasInterface} && {_pilot==player}) then {airplaneThrottle _v} else {if (alive _pilot) then {1} else {0}};
    private _base=_v getVariable ["NeroFlight_baseBurn",.000025];private _priorFuel=_v getVariable ["NeroFlight_previousFuel",fuel _v];private _used=(_priorFuel-fuel _v) max 0;
    // Observe native burn only in cruise; never compound our own surcharge next tick.
    if (_speed*3.6<=_cruise && {_used>0} && {_used<.01}) then {_base=.98*_base+.02*(_used/_dt);_v setVariable ["NeroFlight_baseBurn",_base];};
    private _native=_phase>.1;
    private _result=[_speed,_v getVariable ["NeroFlight_previousSpeed",_speed],_dt,_cruise,_limit,_boost || {_super},_power,isEngineOn _v,!isTouchingGround _v && {alive _pilot},fuel _v,_base] call NeroFlight_fnc_step;
    _result params ["_extra","_brake","_burn","_factor"];
    // Add forward thrust only in forward flight; no speed-setting teleport or forced turn.
    if (_extra>0 && {_speed>50} && {(vectorNormalized _velocity) vectorDotProduct vectorDir _v>.8} && {abs((vectorDir _v)#2)<.5}) then {_velocity=_velocity vectorAdd ((vectorDir _v) vectorMultiply _extra);};
    if (_brake>0 && {_speed>0}) then {_velocity=_velocity vectorMultiply ((_speed-_brake)/_speed);};
    if (_extra>0 || {_brake>0}) then {_v setVelocity _velocity;};
    // Native AB already consumes extra fuel: do not charge a second surcharge.
    if (_burn>0 && {!_native}) then {_v setFuel ((fuel _v-_burn) max 0);};
    _v setVariable ["NeroFlight_previousFuel",fuel _v];_v setVariable ["NeroFlight_previousSpeed",vectorMagnitude _velocity];
   };
  } forEach _vehicles;
  sleep .05;
 };
};
if (hasInterface) then {[] spawn {
 disableSerialization;private _lastVehicle=objNull;private _actions=[];private _display=displayNull;private _label=controlNull;
 while {true} do {
  private _v=vehicle player;private _cfg=configFile >> "CfgNeroFlight" >> typeOf _v;
  private _valid=alive player && {driver _v==player} && {_v isKindOf "Plane"} && {getText(_cfg >> "model")!=""};
  if (!_valid) then {_v=objNull;};
  if (_v!=_lastVehicle) then {
   if (!isNull _lastVehicle) then {{_lastVehicle removeAction _x;} forEach _actions;};_actions=[];_lastVehicle=_v;
   if (!isNull _v) then {
    private _ab=getNumber(_cfg >> "afterburner")==1;
    _actions pushBack (_v addAction [if (_ab) then {"NeroAI: включить форсаж"} else {"NeroAI: максимальная мощность"},{params ["_v","_caller"];if (driver _v==_caller && {local _v} && {fuel _v>0}) then {_v setVariable ["NeroFlight_boost",true,true];};},nil,1.5,false,true,"","driver _target==_this && {!(_target getVariable ['NeroFlight_boost',false])}"]);
    _actions pushBack (_v addAction ["NeroAI: крейсерский режим",{params ["_v","_caller"];if (driver _v==_caller && {local _v}) then {_v setVariable ["NeroFlight_boost",false,true];_v setVariable ["NeroFlight_supercruise",false,true];_v animate ["ab_switch",0];};},nil,1.5,false,true,"","driver _target==_this && {(_target getVariable ['NeroFlight_boost',false]) || {_target getVariable ['NeroFlight_supercruise',false]}}"]);
    if (getNumber(_cfg >> "dryMaximum")>getNumber(_cfg >> "cruise")) then {_actions pushBack (_v addAction ["NeroAI: сверхзвуковой без форсажа",{params ["_v","_caller"];if (driver _v==_caller && {local _v}) then {_v setVariable ["NeroFlight_boost",false,true];_v setVariable ["NeroFlight_supercruise",true,true];_v animate ["ab_switch",0];};},nil,1.5,false,true,"","driver _target==_this && {!(_target getVariable ['NeroFlight_supercruise',false])}"]);};
   };
  };
  if (isNull _display) then {_display=findDisplay 46;if (!isNull _display) then {_label=_display ctrlCreate ["RscStructuredText",-1];_label ctrlSetPosition [safeZoneX+safeZoneW*.39,safeZoneY+safeZoneH*.035,safeZoneW*.22,safeZoneH*.035];_label ctrlCommit 0;};};
  if (!isNull _label) then {_label ctrlShow (!isNull _v);if (!isNull _v) then {private _boost=_v getVariable ["NeroFlight_boost",false];private _ab=getNumber(_cfg >> "afterburner")==1;private _mode=if (_boost) then {if (_ab) then {"ФОРСАЖ"} else {"МАКС. МОЩНОСТЬ"}} else {if (_v getVariable ["NeroFlight_supercruise",false]) then {"СВЕРХЗВУК БЕЗ ФОРСАЖА"} else {"КРЕЙСЕРСКИЙ"}};_label ctrlSetStructuredText parseText format ["<t align='center' size='0.85' color='%1'>%2 · %3 км/ч · крейс. %4</t>",if (_boost) then {"#ffae45"} else {"#a5dbef"},_mode,round(vectorMagnitude velocity _v*3.6),getNumber(_cfg >> "cruise")];};};
  sleep .2;
 };
};};
