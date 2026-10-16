/* Pure role priorities. Ground mobility precedes additional aircraft. */
params ["_ground","_air","_active","_airLimit","_hasGround","_hasAir","_bomber","_escort","_lift"];
private _roles=[];
if (!_hasGround) then {_roles append ["APC","CAR","TANK"];};
if (!_hasAir && {_air<_airLimit}) then {
 if (_bomber && {!_escort}) then {_roles pushBack "FIGHTER";};
 if (_ground>=((_active*.5) max 2) || {_hasGround}) then {
  if (_lift) then {_roles pushBack "TRANSPORT_HELI";};
  if (!_escort) then {_roles pushBack "FIGHTER";};
  if (_escort && {!_bomber}) then {_roles pushBack "BOMBER";};
  _roles append ["ATTACK_HELI","CAS"];
  _roles pushBack "UAV";
 };
};
if (!_hasGround && {_ground>=2}) then {_roles append ["AAA","SAM","RADAR","ARTILLERY_SP","ARTILLERY_STATIC","MLRS","STATIC"];};
_roles
