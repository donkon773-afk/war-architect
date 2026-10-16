/* Countermeasures and lasers do not hide an exhausted combat loadout. */
params ["_vehicle"];
private _weapons=weapons _vehicle;
{_weapons append (_vehicle weaponsTurret _x);} forEach (allTurrets [_vehicle,true]);
private _armed=_weapons findIf {private _name=toLower _x;["horn","laserdesignator","smoke","flare","chaff","countermeasure","ecm"] findIf {_name find _x>=0}<0}>=0;
if (!_armed) exitWith {false};
private _combatMagazine={params ["_class"];private _ammo=getText(configFile >> "CfgMagazines" >> _class >> "ammo");getNumber(configFile >> "CfgAmmo" >> _ammo >> "hit")>1 || {getNumber(configFile >> "CfgAmmo" >> _ammo >> "indirectHit")>1}};
private _left=(magazinesAllTurrets [_vehicle,true]) findIf {(_x#2)>0 && {[_x#0] call _combatMagazine}}>=0;
{if (_x!="" && {_vehicle ammoOnPylon (_forEachIndex+1)>0} && {[_x] call _combatMagazine}) then {_left=true;};} forEach getPylonMagazines _vehicle;
!_left
