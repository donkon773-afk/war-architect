params ["_plane"];
if (!local _plane) exitWith {};
if (getNumber(missionConfigFile >> "CfgNeroOperation" >> "autoAirLoadout")==1) then {
 for "_i" from 1 to count getAllPylonsInfo _plane do {
  private _compatible=_plane getCompatiblePylonMagazines _i;
  private _aa=_compatible select {private _ammo=getText(configFile >> "CfgMagazines" >> _x >> "ammo"); getNumber(configFile >> "CfgAmmo" >> _ammo >> "airLock")==1};
  if !(_aa isEqualTo []) then {_plane setPylonLoadOut [_i,_aa#0,true];};
 };
};
_plane setVehicleAmmo 1;
_plane setVehicleRadar 1;
