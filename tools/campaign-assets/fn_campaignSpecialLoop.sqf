/* Cooldowns apply to the side, reload timers to the physical launcher/aircraft. */
while {!NeroOP_campFinished} do {
 {private _r=_x;private _v=_r#4;private _side=_r#1;private _special=if (typeOf _v find "FP5">=0) then {0} else {if (toLower typeOf _v find "tu95">=0) then {1} else {-1}};
  if (_special>=0 && {alive _v}) then {
   if !(_v getVariable ["NeroOP_specialInit",false]) then {_v setVariable ["NeroOP_specialInit",true];_v setVariable ["NeroOP_specialKind",_special];
    _v addEventHandler ["Killed",{params ["_v"];if (isServer) then {private _kind=_v getVariable ["NeroOP_specialKind",-1];if (_kind>=0) then {NeroOP_campSpecialUntil set [_kind,serverTime+([1200,900]#_kind)];};};}];
   };
   if (_special==1 && {serverTime-(_v getVariable ["NeroOP_flightLogAt",-100])>30}) then {_v setVariable ["NeroOP_flightLogAt",serverTime];private _f=[getPosASL _v,velocity _v,fuel _v,damage _v,alive driver _v,driver _v getVariable ["ACE_isUnconscious",false],currentWaypoint group driver _v];_v setVariable ["NeroOP_flightLast",_f];diag_log format ["[NeroOP BOMBER] FLIGHT %1",_f];};
   if (_special==0 && {[_v] call NeroOP_fnc_campaignAmmoEmpty}) then {
    if (_v getVariable ["NeroOP_fpReloadAt",0]==0) then {_v setVariable ["NeroOP_fpReloadAt",serverTime+600,true];};
    if (serverTime>=(_v getVariable ["NeroOP_fpReloadAt",0])) then {NeroOP_campSeq=NeroOP_campSeq+1;_v setVariable ["NeroOP_serviceGrant",NeroOP_campSeq,true];[_v,NeroOP_campSeq,true] remoteExecCall ["NeroOP_fnc_campaignServiceLocal",0];_v setVariable ["NeroOP_fpReloadAt",0,true];};
   };
   if (_special==1 && {[_v] call NeroOP_fnc_campaignCruiseEmpty} && {isTouchingGround _v} && {abs speed _v<5}) then {private _main=NeroOP_campMainAirfields#_side;if (count _main==2 && {_v distance2D (_main#1)<(NeroOP_campAirfieldRadii param [_main#0,750])}) then {private _at=_v getVariable ["NeroOP_bomberReloadAt",0];if (_at==0) then {_v setVariable ["NeroOP_bomberReloadAt",serverTime+480,true];} else {if (serverTime>=_at) then {private _ok=false;isNil {_ok=[_v,_side,true] call NeroOP_fnc_campaignService;};if (_ok && {!([_v] call NeroOP_fnc_campaignPlayerControl)}) then {_v engineOn true;_v setVariable ["NeroOP_airOrderAt",-100];};};};};};
  };
 } forEach +NeroOP_campEquipment;
 NeroOP_campSpecialState=[0,1] apply {((NeroOP_campSpecialUntil#_x)-serverTime) max 0};publicVariable "NeroOP_campSpecialState";
 sleep 1;
};
