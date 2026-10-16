/* Runs on every owner, including HC/JIP. No remote script execution or hidden launch. */
if (missionNamespace getVariable ["NeroMS_started",false]) exitWith {};
NeroMS_started=true;
[] spawn {
 while {true} do {
  {if (local _x && {!(_x getVariable ["NeroMS_firedEH",false])}) then {
   _x setVariable ["NeroMS_firedEH",true];
   _x addEventHandler ["Fired",{_this call NeroMS_fnc_fired;}];
  };} forEach vehicles;
  sleep 1;
 };
};
