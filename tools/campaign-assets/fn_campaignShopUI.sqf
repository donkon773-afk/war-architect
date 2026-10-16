params [["_mode","OPEN"]];
if (!hasInterface) exitWith {};
if (_mode in ["OPEN","TRAVEL","INFANTRY"]) exitWith {
 if (dialog) exitWith {};
 uiNamespace setVariable ["NeroOP_shopTravel",_mode=="TRAVEL"];
 createDialog "NeroOPCampaignShop";private _display=findDisplay 88150;private _combo=_display displayCtrl 88152;
 {private _i=_combo lbAdd (_x#0);_combo lbSetData [_i,_x#1];} forEach (if (_mode=="TRAVEL") then {[["Свои безопасные секторы","TRAVEL"]]} else {[["Наземная техника","GROUND"],["Пехота в отряд","INFANTRY"],["Авиация","AIR"],["Артиллерия","ARTILLERY"],["ПВО / ЗРК / РЛС","AA"],["Беспилотники","UAV"],["Ручные ракетные комплексы","LAUNCHER"],["Винтовки","RIFLE"],["Автоматы / карабины","AUTOMATIC"],["Снайперские винтовки","SNIPER"],["Пулемёты","MACHINEGUN"],["Пистолеты-пулемёты","SMG"],["Пистолеты","PISTOL"],["Стрелковые магазины","SMALL_AMMO"],["Снаряды","SHELL"],["Ракеты","ROCKET"],["Гранаты / взрывчатка","EXPLOSIVE"],["Экипировка и снаряжение","GEAR"],["Снабжение и подкрепления","SUPPORT"],["Сесть в купленную авиацию","FLY"]]});
 (_display displayCtrl 88151) ctrlSetText (if (_mode=="TRAVEL") then {"Сброс с парашютом — 4500 м"} else {"Магазин снабжения"});
 (_display displayCtrl 88155) ctrlSetText (if (_mode=="TRAVEL") then {"Начать сброс"} else {"Купить за снабжение"});
 _combo lbSetCurSel (if (_mode=="INFANTRY") then {1} else {0});
};
private _display=findDisplay 88150;if (isNull _display) exitWith {};private _list=_display displayCtrl 88153;private _combo=_display displayCtrl 88152;private _category=_combo lbData lbCurSel _combo;private _side=[west,east] find side group player;
if (_side<0) exitWith {};
private _cfg=missionConfigFile >> "CfgNeroOperation";private _army=_cfg >> (["WEST","EAST"]#_side);
if (_mode=="REFRESH") exitWith {
 lbClear _list;private _entries=[];
 if (_category in ["GROUND","AIR","ARTILLERY","UAV","AA"]) then {
  {private _r=_x;private _cat=getText(_r >> "category");private _kind=getNumber(_r >> "kind");
   if ((_category=="GROUND" && {_kind==0} && {!(_cat in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS","AAA","SAM","RADAR","UAV"])}) || {_category=="AIR" && {_kind==1} && {_cat!="UAV"}} || {_category=="ARTILLERY" && {_cat in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS"]}} || {_category=="UAV" && {_cat=="UAV"}} || {_category=="AA" && {_cat in ["AAA","SAM","RADAR"]}}) then {
    private _class=getText(_r >> "className");_entries pushBack [format ["%1 — %2 снаб.",getText(configFile >> "CfgVehicles" >> _class >> "displayName"),getNumber(_r >> "price")],"BUY",_forEachIndex,getNumber(_r >> "price")];if (_kind==0 && {_cat!="UAV"} && {getNumber(_cfg >> "DevMode" >> "independentCrew")==1}) then {_entries pushBack [format ["%1 — ПУСТАЯ — %2 снаб.",getText(configFile >> "CfgVehicles" >> _class >> "displayName"),getNumber(_r >> "price")],"BUY_EMPTY",_forEachIndex,getNumber(_r >> "price")];};
   };
  } forEach ("true" configClasses (_army >> "Shop"));
 };
 if (_category in ["WEAPON","MAGAZINE","GEAR","LAUNCHER","RIFLE","AUTOMATIC","SNIPER","MACHINEGUN","SMG","PISTOL","SMALL_AMMO","SHELL","ROCKET","EXPLOSIVE"]) then {
  {private _kind=getText(_x >> "kind");if (_kind==_category || {getText(_x >> "category")==_category} || {_category=="GEAR" && {_kind in ["ITEM","BACKPACK","GLASSES"]}}) then {
   private _class=getText(_x >> "className");private _table=switch (_kind) do {case "MAGAZINE":{"CfgMagazines"};case "BACKPACK":{"CfgVehicles"};case "GLASSES":{"CfgGlasses"};default {"CfgWeapons"};};
   _entries pushBack [format ["%1 — %2 снаб.",getText(configFile >> _table >> _class >> "displayName"),getNumber(_x >> "price")],"GEAR",_forEachIndex,getNumber(_x >> "price")];
  };} forEach ("true" configClasses (_army >> "Gear"));
 };
 if (_category=="INFANTRY") then {private _price=(ceil (getNumber(_cfg >> "reinforcementCost")/getNumber(_army >> "groupSize"))) max 5;{_entries pushBack [format ["%1 — %2 снаб.",getText(configFile >> "CfgVehicles" >> _x >> "displayName"),_price],"RECRUIT",_forEachIndex,_price];} forEach getArray(_army >> "classes");};
 if (_category=="SUPPORT") then {private _params=_cfg >> "Gameplay";private _truckCost=getNumber(_params >> "truckCost");private _groupCost=getNumber(_cfg >> "reinforcementCost");private _service=getNumber(_params >> "serviceCost");_entries pushBack [format ["Грузовик снабжения (у базы) — %1 снаб.",_truckCost],"TRUCK",0,_truckCost];_entries pushBack [format ["Отдельный отряд High Command — %1 снаб.",_groupCost],"REINFORCE",0,_groupCost];_entries pushBack [format ["Снабжение / обслуживание техники — %1 снаб.",_service],"REARM",0,_service];};
 if (_category=="FLY") then {
  private _fleet=missionNamespace getVariable ["NeroOP_campEquipmentState",[[]]];
  {if ((_x#1)==_side && {(_x#3)==1} && {!(_x#5)} && {_x#6}) then {_entries pushBack [getText(configFile >> "CfgVehicles" >> (_x#2) >> "displayName"),"FLY",_x#0,0];};} forEach (_fleet#0);
 };
 if (_category=="TRAVEL") then {
  private _state=missionNamespace getVariable ["NeroOP_campState",[]];
  if (count _state>0) then {private _nodes="true" configClasses (_cfg >> "Sectors");private _graph=[_state#0,getArray(_cfg >> "links"),getNumber(_army >> "base"),_side] call NeroOP_fnc_campaignGraph;
   {if ((_state#0)#_forEachIndex==_side) then {_entries pushBack [getText(_x >> "name")+(if (_forEachIndex in (_graph#0)) then {" · связан"} else {" · отрезан"}),"TRAVEL",_forEachIndex,0];};} forEach _nodes;
  };
 };
 uiNamespace setVariable ["NeroOP_shopEntries",_entries];{_list lbAdd (_x#0);} forEach _entries;
 _list lbSetCurSel 0;["DETAIL"] call NeroOP_fnc_campaignShopUI;
};
private _entries=uiNamespace getVariable ["NeroOP_shopEntries",[]];private _selected=lbCurSel _list;private _entry=if (_selected>=0 && {_selected<count _entries}) then {_entries#_selected} else {[]};
if (_mode=="DETAIL") exitWith {
 private _state=missionNamespace getVariable ["NeroOP_campState",[]];private _supply=0;
 if (count _state>0) then {private _graph=[_state#0,getArray(_cfg >> "links"),getNumber(_army >> "base"),_side] call NeroOP_fnc_campaignGraph;{_supply=_supply+((_state#1)#_x);} forEach (_graph#0);};
 private _localStock=-1;private _localName="нет связанного склада рядом";private _warehouse=-1;
 if (count _state>0) then {private _nodes="true" configClasses (_cfg >> "Sectors");private _graph=[_state#0,getArray(_cfg >> "links"),getNumber(_army >> "base"),_side] call NeroOP_fnc_campaignGraph;
  {if ((_category in ["GROUND","AIR","ARTILLERY","UAV","AA","FLY"] || {getText((_nodes#_x) >> "kind") in ["base","depot"]}) && {player distance2D getArray((_nodes#_x) >> "position")<getNumber((_nodes#_x) >> "radius")+100}) then {_warehouse=_x;_localStock=(_state#1)#_x;_localName=(getText((_nodes#_x) >> "name")) select [0,25];};} forEach (_graph#0);
 };
 private _canBuy=count _entry>0;if (_canBuy && {_category!="TRAVEL"}) then {_canBuy=if ((_entry#1)=="REARM") then {true} else {_warehouse>=0 && {_localStock>=(_entry#3)}};};
 private _roster=({alive _x && {!isPlayer _x}} count units group player)+(group player getVariable ["NeroOP_pendingRecruits",0]);private _loans=0;private _key=group player getVariable ["NeroOP_groupKey",-1];private _fleet=missionNamespace getVariable ["NeroOP_campEquipmentState",[[]]];{if ((_x#1)==_side && {(_x#7)==_key} && {_x#5} && {!(_x param [8,false])} && {getNumber(configFile >> "CfgVehicles" >> (_x#2) >> "isUav")!=1}) then {_loans=_loans+(_x#4);};} forEach (_fleet#0);
 private _reserve=missionNamespace getVariable ["NeroOP_campRecruitState",[[0,0],[0,0]]];private _left=((_reserve#1)#_side)-((_reserve#0)#_side);
 if (_category=="INFANTRY") then {_canBuy=_canBuy && {leader group player==player} && {group player getVariable ["NeroOP_campGroup",false]} && {_roster+_loans<12} && {_left>0} && {!(player getVariable ["ACE_isUnconscious",false])};};
 (_display displayCtrl 88155) ctrlEnable _canBuy;
 (_display displayCtrl 88154) ctrlSetStructuredText parseText (if (_category=="TRAVEL") then {"Сброс с высоты 4500 м над своим сектором, вне контакта. Игрок открывает парашют вручную через действие. Бойцы AI открывают автоматически."} else {if (_category=="INFANTRY") then {format ["Склад: %1 · запас %2<br/>Бойцов AI: %3/12 · отдельно в экипажах: %4 · резерв пополнений стороны: %5<br/>Выбранный боец присоединится к вашему отряду. Нужны командование отрядом и безопасный связанный склад.",_localName,floor (_localStock max 0),_roster+_loans,_loans,_left max 0]} else {format ["Склад: %1 · запас %2 · сеть стороны %3<br/>Оружие и экипировка — в ящике рядом. UAV требует терминал.<br/>Техника ограничена активным парком и запасом заказов. При заказе с экипажем его стоимость добавляется к цене машины; группа отдельная.",_localName,floor (_localStock max 0),floor _supply]}});
};
if (_mode=="BUY" && {count _entry>0}) then {[player,_entry#1,_entry#2] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];closeDialog 0;};
