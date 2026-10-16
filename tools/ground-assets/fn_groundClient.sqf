if (!hasInterface || {missionNamespace getVariable ["NeroOP_groundClientStarted",false]}) exitWith {};
NeroOP_groundClientStarted=true;
waitUntil {sleep .2;!isNull player && {missionNamespace getVariable ["NeroOP_groundReady",false]}};
private _cfg=missionConfigFile >> "CfgNeroOperation",_old=objNull;
player createDiaryRecord ["Diary",["Штурм и оборона","Атакующая сторона должна занять отмеченный район без живых защитников и накопить время захвата. При встрече сторон захват останавливается. Защитники побеждают по времени или после исчерпания атакующих. Резерв ограничен числом отрядов. Игрок командует своим отрядом штатными командами Arma; его отряд не получает новых приказов от сценария."]];
waitUntil {sleep .1;!isNull findDisplay 46};
private _hud=(findDisplay 46) ctrlCreate ["RscStructuredText",88141];_hud ctrlSetPosition [safeZoneX+.02*safeZoneW,safeZoneY+.02*safeZoneH,.43*safeZoneW,.12*safeZoneH];_hud ctrlSetBackgroundColor [0,0,0,.65];_hud ctrlCommit 0;
while {!isNull _hud} do {
 if (player!=_old) then {_old=player;
  if (side group player in [west,east]) then {if !(group player getVariable ["NeroOP_groundGroup",false]) then {player setCaptive true;[player] remoteExecCall ["NeroOP_fnc_groundRequest",2];};player addAction ["Получить отряд / вернуться в бой",{[player] remoteExecCall ["NeroOP_fnc_groundRequest",2];},nil,2,false,true,"","alive _this && {!(group _this getVariable ['NeroOP_groundGroup',false])}"];} else {
   player allowDamage false;player setCaptive true;player addAction ["Наблюдать сражение",{["Initialize",[player,[],true]] call BIS_fnc_EGSpectator;}];
  };
 };
 private _state=missionNamespace getVariable ["NeroOP_groundState",[0,"defended",0,[0,0],[0,0]]];
 private _label=["Синие","Красные"]#(["WEST","EAST"] find getText(_cfg >> "attackerSide"));
 private _phase=switch (_state#1) do {case "capturing":{"Идёт захват"};case "contested":{"Бой в районе — захват остановлен"};case "defended":{"Район удерживают защитники"};default {"Район пуст"};};
 _hud ctrlSetStructuredText parseText format ["<t size='1.05'>Штурм и оборона · %1 мин</t><br/>Атакуют: %2 · %3 · захват %4/%5 с<br/><t color='#70aaff'>Синие: живы %6 · резерв отрядов %7</t><br/><t color='#ff8080'>Красные: живы %8 · резерв отрядов %9</t><br/>%10",ceil((_state#2)/60),_label,_phase,floor(_state#0),getNumber(_cfg >> "captureSeconds"),(_state#3)#0,(_state#4)#0,(_state#3)#1,(_state#4)#1,player getVariable ["NeroOP_notice",""]];
 if (isServer && {side group player==civilian} && {!isNull getAssignedCuratorLogic player}) then {(getAssignedCuratorLogic player) addCuratorEditableObjects [allUnits,true];};sleep 1;
};
