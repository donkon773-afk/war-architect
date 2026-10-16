if (!hasInterface || {missionNamespace getVariable ["NeroOP_clientStarted",false]}) exitWith {};
NeroOP_clientStarted=true;
waitUntil {sleep .2;!isNull player && {missionNamespace getVariable ["NeroOP_ready",false]}};
private _cfg=missionConfigFile >> "CfgNeroOperation";
player createDiaryRecord ["Diary",["Воздушная операция","Займите кабину и уничтожайте авиацию противника. Самолёты и подкрепления ограничены. Победа: нужное число сбитых самолётов, исчерпание авиации противника или преимущество по окончании времени. После возрождения запросите следующий вылет через меню действий. Воздушный старт — высота над землёй."]];
private _old=objNull;private _action=-1;private _hud=controlNull;
waitUntil {sleep .1;!isNull findDisplay 46};
_hud=(findDisplay 46) ctrlCreate ["RscStructuredText",88140];
_hud ctrlSetPosition [safeZoneX+.02*safeZoneW,safeZoneY+.02*safeZoneH,.42*safeZoneW,.11*safeZoneH];_hud ctrlSetBackgroundColor [0,0,0,.6];_hud ctrlCommit 0;
while {!isNull _hud} do {
 if (player!=_old) then {
  if (!isNull _old && {_action>=0}) then {_old removeAction _action;};_old=player;
  if (side group player in [west,east]) then {
   [player] spawn {params ["_unit"];private _end=diag_tickTime+15;waitUntil {sleep .2;_unit!=player || {!alive _unit} || {diag_tickTime>_end} || {vehicle _unit!=_unit && {local vehicle _unit}}};if (_unit==player && {alive _unit} && {vehicle _unit!=_unit}) then {[vehicle _unit,_unit] call NeroOP_fnc_airAvionics;};};
   _action=player addAction ["Запросить самолёт / новый вылет",{[player] remoteExecCall ["NeroOP_fnc_airRequest",2];},nil,2,false,true,"","alive _this && {vehicle _this == _this}"];
   player addAction ["F/A-18: включить приборы",{[vehicle player,player,true] call NeroOP_fnc_airAvionics;},nil,1.5,false,true,"","alive _this && {(vehicle _this) isKindOf 'JS_JC_FA18E' || {(vehicle _this) isKindOf 'JS_JC_FA18F'}}"];
   player addAction ["F/A-18: прицел шлема — вкл./выкл.",{[vehicle player,player,true] call NeroOP_fnc_airHelmet;},nil,1.4,false,true,"","alive _this && {driver (vehicle _this)==_this} && {(vehicle _this) isKindOf 'JS_JC_FA18E' || {(vehicle _this) isKindOf 'JS_JC_FA18F'}}"];
   if (vehicle player==player) then {player setCaptive true;[player] remoteExecCall ["NeroOP_fnc_airRequest",2];} else {player setCaptive false;};
  } else {
   player allowDamage false;player setCaptive true;
   player addAction ["Наблюдать сражение",{["Initialize",[player,[],true]] call BIS_fnc_EGSpectator;}];
  };
 };
 private _state=missionNamespace getVariable ["NeroOP_state",["deployment",[[0,0,0],[0,0,0]],[0,0],[0,0],0,"",""]];
 private _stats=_state#1;private _minutes=ceil ((_state#4)/60);
 private _label=if ((_state#0)=="deployment") then {"Развёртывание авиации"} else {"Воздушное сражение"};
 private _notice=player getVariable ["NeroOP_notice",""];
 _hud ctrlSetStructuredText parseText format ["<t size='1.05'>%1 · %2 мин · цель %3</t><br/><t color='#70aaff'>Синие: сбито %4 · в воздухе %5 · запас %6</t><br/><t color='#ff8080'>Красные: сбито %7 · в воздухе %8 · запас %9</t><br/>%10",_label,_minutes,getNumber(_cfg >> "scoreTarget"),(_stats#0)#2,(_state#2)#0,(_state#3)#0,(_stats#1)#2,(_state#2)#1,(_state#3)#1,_notice];
 if (isServer && {side group player==civilian} && {!isNull getAssignedCuratorLogic player}) then {(getAssignedCuratorLogic player) addCuratorEditableObjects [vehicles,true];};
 sleep 1;
};
