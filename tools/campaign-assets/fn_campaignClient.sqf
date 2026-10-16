if (!hasInterface || {missionNamespace getVariable ["NeroOP_campClientStarted",false]}) exitWith {};NeroOP_campClientStarted=true;
waitUntil {sleep .2;!isNull player && {missionNamespace getVariable ["NeroOP_campReady",false]}};
player createDiaryRecord ["Diary",["Линия фронта и снабжение","Захватывайте соседние с вашей связанной территорией секторы. При захвате нужны бойцы, отсутствие противника и снабжение в соседнем секторе. Отрезанные склады не производят ресурсы. Грузовики перевозят запасы физически: их потеря или обрыв маршрута уничтожает груз. Новые отряды расходуют снабжение и конечный резерв. Победа — захват базы противника. Сохранение работает в профиле сервера; в лобби можно продолжить кампанию или начать новую."]];
waitUntil {sleep .1;!isNull findDisplay 46};private _hud=(findDisplay 46) ctrlCreate ["RscStructuredText",88142];_hud ctrlSetPosition [safeZoneX+.33*safeZoneW,safeZoneY+.012*safeZoneH,.34*safeZoneW,.075*safeZoneH];_hud ctrlSetFontHeight (.019*safeZoneH);_hud ctrlSetBackgroundColor [0,0,0,.5];_hud ctrlCommit 0;private _old=objNull;private _lastNotice="";
private _cfg=missionConfigFile >> "CfgNeroOperation";private _nodes="true" configClasses (_cfg >> "Sectors");private _positions=_nodes apply {getArray(_x >> "position")};
while {!isNull _hud} do {
 if (player!=_old) then {_old=player;
  if (side group player in [west,east]) then {if (!(group player getVariable ["NeroOP_campGroup",false]) && {!(group player getVariable ["NeroOP_campFlight",false])}) then {player setCaptive true;[player] remoteExecCall ["NeroOP_fnc_campaignRequest",2];};
   player addAction ["Получить отряд",{[player] remoteExecCall ["NeroOP_fnc_campaignRequest",2];},nil,2,false,true,"","alive _this && {!(group _this getVariable ['NeroOP_campGroup',false])}"];
   player addAction ["Магазин снабжения",{["OPEN"] call NeroOP_fnc_campaignShopUI;},nil,2,false,true,"","alive _this"];
   player addAction ["Купить бойцов в свой отряд",{["INFANTRY"] call NeroOP_fnc_campaignShopUI;},nil,1.9,false,true,"","alive _this && {leader group _this==_this} && {group _this getVariable ['NeroOP_campGroup',false]}"];
   player addAction ["Купить грузовик снабжения",{[player,"TRUCK",0] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];},nil,1.8,false,true,"","alive _this"];
   player addAction ["Вызвать отдельный отряд (High Command)",{[player,"REINFORCE",0] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];},nil,1.8,false,true,"","alive _this"];
   player addAction ["Снабжение / боезапас ближайшей техники",{[player,"REARM",0] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];},nil,1.8,false,true,"","alive _this"];
   player addAction ["Фламинго: включить / выключить маневр уклонения",{private _v=getConnectedUAV player;if (!isNull _v) then {[player,"FP_EVADE",_v getVariable ["NeroOP_assetId",-1]] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];};},nil,1.8,false,true,"","alive _this && {!isNull getConnectedUAV _this} && {toLower typeOf getConnectedUAV _this find 'fp5'>=0}"];
   player addAction ["Сброс с парашютом — 4500 м",{["TRAVEL"] call NeroOP_fnc_campaignShopUI;},nil,1.8,false,true,"","alive _this && {vehicle _this==_this}"];
   player addAction ["Запросить снабжение в ближайший сектор",{
    private _cfg=missionConfigFile >> "CfgNeroOperation";private _nodes="true" configClasses (_cfg >> "Sectors");private _state=missionNamespace getVariable ["NeroOP_campState",[]];private _side=[west,east] find side group player;
    if (count _state>0 && {_side>=0}) then {private _rank=[];{if (((_state#0)#_forEachIndex)==_side && {getText(_x >> "kind")!="base"}) then {_rank pushBack [player distance2D getArray(_x >> "position"),_forEachIndex];};} forEach _nodes;_rank sort true;if (count _rank>0) then {[player,"CONVOY",(_rank#0)#1] remoteExecCall ["NeroOP_fnc_campaignAction",2];};};
   }];
  } else {player allowDamage false;player setCaptive true;player addAction ["Наблюдать кампанию",{["Initialize",[player,[],true]] call BIS_fnc_EGSpectator;}];};
  player addAction ["Сохранить кампанию",{[player,"SAVE"] remoteExecCall ["NeroOP_fnc_campaignAction",2];}];
  player addAction ["Показать / скрыть сводку кампании",{missionNamespace setVariable ["NeroOP_hideHUD",!(missionNamespace getVariable ["NeroOP_hideHUD",false])];}];
 };
 private _state=missionNamespace getVariable ["NeroOP_campState",[]];
 if (count _state>=8) then {
  private _rank=[_positions,getPosATL player] call NeroOP_fnc_campaignNearest;private _near=(_rank#0)#1;private _owners=_state#0;private _stock=_state#1;private _count=[{_x==0} count _owners,{_x==1} count _owners];
  _hud ctrlSetStructuredText parseText format ["<t size='.8' align='center'>Фронт · %1 мин · колонны %10<br/><t color='#70aaff'>Синие %2 сект. / %3 отр. / %4 рез.</t>   <t color='#ff8080'>Красные %5 / %6 / %7</t><br/>%8 · снабжение %9</t>",ceil((_state#7)/60),_count#0,(_state#5)#0,(_state#4)#0,_count#1,(_state#5)#1,(_state#4)#1,getText((_nodes#_near) >> "name"),floor (_stock#_near),count (_state#6)];
 };sleep 1;
 if (!isNull findDisplay 88150) then {["DETAIL"] call NeroOP_fnc_campaignShopUI;};
 _hud ctrlShow (!dialog && {isNull findDisplay 49} && {isNull findDisplay 312} && {!visibleMap} && {!isRemoteControlling player} && {!(missionNamespace getVariable ["NeroOP_hideHUD",false])});
 private _notice=player getVariable ["NeroOP_notice",""];if (_notice!="" && {_notice!=_lastNotice}) then {_lastNotice=_notice;systemChat _notice;};
};
