/* Same inventory/menu distinction as stock Warlords; respects remapped Gear keys. */
params["_event","_args"];
private _key=_args#1;
if(!(_key in actionKeys "Gear"))exitWith{false};
if(_event=="UP")exitWith{missionNamespace setVariable["NeroWL_CQgearHeld",false];false};
if(!isNull(uiNamespace getVariable["NeroWL_CQmenu",displayNull]))exitWith{false};
if(dialog || {isNull player} || {!alive player} || {!(side group player in [west,east,resistance])})exitWith{false};
if(missionNamespace getVariable["NeroWL_CQgearHeld",false])exitWith{true};
missionNamespace setVariable["NeroWL_CQgearHeld",true];
[player]spawn{
 params["_unit"];private _until=diag_tickTime+0.5;
 waitUntil{uiSleep 0.01;!(missionNamespace getVariable["NeroWL_CQgearHeld",false]) || {diag_tickTime>=_until}};
 if(_unit!=player || {!alive _unit})exitWith{};
 if(missionNamespace getVariable["NeroWL_CQgearHeld",false])then{[]call NeroWL_Design_fnc_cqMenu;}else{
  if(!isNull findDisplay 602)then{closeDialog 0;}else{
   if(vehicle _unit!=_unit)then{vehicle _unit action["Gear",vehicle _unit];}else{
    private _target=cursorTarget;
    if(!isNull _target && {_target distance _unit<=5} && {!(_target isKindOf "House")} && {!alive _target || {!(_target isKindOf "Man")}})then{_unit action["Gear",_target];}else{_unit action["Gear",objNull];};
   };
  };
 };
};
true
