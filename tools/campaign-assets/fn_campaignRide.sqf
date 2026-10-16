/* One physical boarding transaction per vehicle and original infantry group. */
params ["_v","_parent","_crew","_target"];
if (!isServer || {!local _parent} || {!local _crew} || {!alive _v} || {!alive driver _v} || {[_parent] call NeroOP_fnc_campaignPlayerControl} || {[_v] call NeroOP_fnc_campaignPlayerControl}) exitWith {false};
private _state=_v getVariable ["NeroOP_rideState","IDLE"];
private _busy=_parent getVariable ["NeroOP_rideVehicle",objNull];
if (alive _busy && {!(_busy isEqualTo _v)}) exitWith {false};
if (_parent getVariable ["NeroOP_liftBusy",false]) exitWith {false};
private _release={_parent setVariable ["NeroOP_rideBusy",false];_parent setVariable ["NeroOP_rideVehicle",objNull];_v setVariable ["NeroOP_rideState","DONE"];_v forceSpeed -1;{if (local _x && {vehicle _x==_x}) then {unassignVehicle _x;[_x] orderGetIn false;};} forEach (_v getVariable ["NeroOP_rideParty",[]]);[_parent,true] call NeroOP_fnc_campaignOrder;};
if (_state=="BOARD") exitWith {
 private _party=(_v getVariable ["NeroOP_rideParty",[]]) select {alive _x};
 private _gate=[count _party,{vehicle _x==_v} count _party,count fullCrew [_v,"cargo",true],serverTime>(_v getVariable ["NeroOP_rideDeadline",0]),_target!=(_v getVariable ["NeroOP_rideTarget",-1]),alive driver _v && {canMove _v}] call NeroOP_fnc_campaignBoardingGate;
 if (_gate=="ABORT") then {call _release;diag_log format ["[NeroOP RIDE] ABORT class=%1 group=%2",typeOf _v,_parent getVariable ["NeroOP_groupKey",-1]];false} else {
  _v forceSpeed 0;
  {if (local _x && {vehicle _x!=_v}) then {[_x] orderGetIn true;};} forEach _party;
  if (_gate=="READY") then {_v forceSpeed -1;_v setVariable ["NeroOP_rideState","TRAVEL"];_v setVariable ["NeroOP_rideTravelUntil",serverTime+900];_v setVariable ["NeroOP_groundTarget",-1];diag_log format ["[NeroOP RIDE] BOARDED class=%1 soldiers=%2",typeOf _v,count _party];false} else {true}
 }
};
if (_state=="TRAVEL") exitWith {
 private _party=(_v getVariable ["NeroOP_rideParty",[]]) select {alive _x};
 if (_target!=(_v getVariable ["NeroOP_rideTarget",-1]) || {!canMove _v} || {serverTime>(_v getVariable ["NeroOP_rideTravelUntil",1e10])} || {_v distance2D (NeroOP_campPositions#_target)<(NeroOP_campRadii#_target)+220} || {_party findIf {vehicle _x==_v}<0}) then {
  _v forceSpeed 0;
  if (abs speed _v<8) then {{if (local _x && {vehicle _x==_v}) then {unassignVehicle _x;[_x] orderGetIn false;_x action ["GetOut",_v];};} forEach _party;_v setVariable ["NeroOP_rideState","UNLOAD"];_v forceSpeed 0;};
 };false
};
if (_state=="UNLOAD") exitWith {if ((_v getVariable ["NeroOP_rideParty",[]]) findIf {alive _x && {vehicle _x==_v}}<0) then {call _release;} else {_v forceSpeed 0;};true};
if (_state=="DONE" && {_target!=(_v getVariable ["NeroOP_rideTarget",-1])}) then {_state="IDLE";_v setVariable ["NeroOP_rideState",_state];};
if (_state!="IDLE" || {_target<0} || {_v distance2D (NeroOP_campPositions#_target)<1500}) exitWith {false};
private _party=units _parent select {alive _x && {local _x} && {!isPlayer _x} && {vehicle _x==_x} && {!(_x getVariable ["ACE_isUnconscious",false])}};
private _seats=fullCrew [_v,"cargo",true] select {isNull (_x#0)};
/* Do not leave part of a squad walking just because an APC is too small. */
if (count _party==0 || {count _seats<count _party} || {leader _parent distance2D _v>250}) exitWith {false};
_v setVariable ["NeroOP_rideParty",_party];_v setVariable ["NeroOP_rideTarget",_target];_v setVariable ["NeroOP_rideState","BOARD"];_v setVariable ["NeroOP_rideDeadline",serverTime+120];_parent setVariable ["NeroOP_rideBusy",true];_parent setVariable ["NeroOP_rideVehicle",_v];
{deleteWaypoint _x;} forEach +(waypoints _parent);{deleteWaypoint _x;} forEach +(waypoints _crew);_v forceSpeed 0;_v engineOn true;
{unassignVehicle _x;_x assignAsCargoIndex [_v,(_seats#_forEachIndex)#2];[_x] orderGetIn true;} forEach _party;
diag_log format ["[NeroOP RIDE] BOARD class=%1 soldiers=%2 target=%3",typeOf _v,count _party,_target];true
