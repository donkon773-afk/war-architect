params [["_mode","OPEN"]];
if (!hasInterface || {isRemoteExecuted}) exitWith {};
disableSerialization;
if (_mode=="OPEN") exitWith {
    if (dialog) exitWith {};
    private _context=[missionName,worldName,player,side group player];
    if !(_context isEqualTo (uiNamespace getVariable ["WA_BECTI_cartContext",[]])) then {
        uiNamespace setVariable ["WA_BECTI_cartContext",_context];uiNamespace setVariable ["WA_BECTI_cart",[]];uiNamespace setVariable ["WA_BECTI_pending",-1];
    };
    createDialog "WarArchitectBectiShop";
    private _display=findDisplay 88150;private _combo=_display displayCtrl 88152;
    {private _i=_combo lbAdd (_x#0);_combo lbSetData [_i,_x#1];} forEach [["Все позиции сетапа","ALL"],["Пехота","INFANTRY"],["Наземная техника","GROUND"],["Авиация","AIR"],["ПВО и РЛС","AA"],["Артиллерия","ARTILLERY"],["Беспилотники","UAV"],["Катера и лодки","NAVAL"],["Оружие","WEAPON"],["Ручные ракетные комплексы","LAUNCHER"],["Боеприпасы","MAGAZINE"],["Экипировка","GEAR"]];
    (_display displayCtrl 88151) ctrlSetText "WAR ARCHITECT · BECTI · Арсенал";
    (_display displayCtrl 88162) ctrlSetText (if (uiNamespace getVariable ["WA_BECTI_withCrew",true]) then {"Техника: с экипажем"} else {"Техника: пустая"});
    _combo lbSetCurSel 0;
    [_display] spawn {disableSerialization;params ["_display"];while {!isNull _display} do {["TICK"] call NeroOP_fnc_bectiShopUI;uiSleep 0.3;};};
};
private _display=findDisplay 88150;if (isNull _display) exitWith {};
private _list=_display displayCtrl 88153;private _queue=_display displayCtrl 88156;
private _side=if (side group player==west) then {"WEST"} else {"EAST"};
private _army=missionConfigFile >> "CfgWarArchitectShop" >> _side;private _rows="true" configClasses (_army >> "Rows");
if (_mode=="REFRESH") exitWith {
    lbClear _list;
    private _combo=_display displayCtrl 88152;private _category=_combo lbData lbCurSel _combo;
    private _search=toLower ctrlText (_display displayCtrl 88161);
    {
        private _kind=getText(_x >> "kind");private _cat=getText(_x >> "category");private _class=getText(_x >> "className");private _table=getText(_x >> "table");private _mod=getText(_x >> "mod");
        private _name=getText(configFile >> _table >> _class >> "displayName");if (_name=="") then {_name=_class;};
        private _matches=switch (_category) do {
            case "ALL":{true};case "GROUND":{_kind=="VEHICLE" && {!(_class isKindOf "Air")} && {!(_cat in ["AAA","SAM","RADAR","ARTILLERY_SP","ARTILLERY_STATIC","MLRS","UAV","SHIP"])}};
            case "AIR":{_kind=="VEHICLE" && {_class isKindOf "Air"} && {_cat!="UAV"}};
            case "AA":{_cat in ["AAA","SAM","RADAR"]};case "ARTILLERY":{_cat in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS"]};
            case "UAV":{_cat=="UAV"};case "NAVAL":{_cat=="SHIP"};case "GEAR":{_kind in ["ITEM","BACKPACK","GLASSES"]};case "LAUNCHER":{_cat=="LAUNCHER"};default {_kind==_category};
        };
        if (_matches && {_search=="" || {toLower(_name+" "+_class+" "+_mod) find _search>=0}}) then {
            private _loaded=isClass(configFile >> _table >> _class);
            private _i=_list lbAdd format ["[%1] %2 · %3%4",_mod,_name,getNumber(_x >> "price"),if (_loaded) then {""} else {" · МОД НЕ ЗАГРУЖЕН"}];
            _list lbSetValue [_i,_forEachIndex];_list lbSetData [_i,_class];_list lbSetTooltip [_i,format ["%1 | %2 | %3",_class,_mod,_cat]];
            if (!_loaded) then {_list lbSetColor [_i,[0.9,0.4,0.3,1]];};
        };
    } forEach _rows;
    _list lbSetCurSel 0;["DETAIL"] call NeroOP_fnc_bectiShopUI;
};
private _selected=lbCurSel _list;private _index=if (_selected>=0) then {_list lbValue _selected} else {-1};
if (_mode=="BUY") exitWith {
    if (_index<0 || {_index>=count _rows} || {uiNamespace getVariable ["WA_BECTI_pending",-1]>=0}) exitWith {};
    private _row=_rows#_index;private _class=getText(_row >> "className");
    if (!isClass(configFile >> getText(_row >> "table") >> _class)) exitWith {(_display displayCtrl 88160) ctrlSetText ("Не загружен класс: "+_class);};
    private _crew=uiNamespace getVariable ["WA_BECTI_withCrew",true];
    private _label=_list lbText _selected;
    if (getText(_row >> "kind")=="VEHICLE") then {_label=_label+(if (_crew) then {" · с экипажем"} else {" · пустая"});};
    private _cart=uiNamespace getVariable ["WA_BECTI_cart",[]];_cart pushBack [_index,_crew,_label,getNumber(_row >> "price")];uiNamespace setVariable ["WA_BECTI_cart",_cart];["CART"] call NeroOP_fnc_bectiShopUI;
};
if (_mode=="CREW") exitWith {
    private _crew=!(uiNamespace getVariable ["WA_BECTI_withCrew",true]);uiNamespace setVariable ["WA_BECTI_withCrew",_crew];
    (_display displayCtrl 88162) ctrlSetText (if (_crew) then {"Техника: с экипажем"} else {"Техника: пустая"});
};
if (_mode=="REMOVE") exitWith {
    if (uiNamespace getVariable ["WA_BECTI_pending",-1]>=0) exitWith {};
    private _cart=uiNamespace getVariable ["WA_BECTI_cart",[]];private _i=lbCurSel _queue;if (_i>=0) then {_cart deleteAt _i;};uiNamespace setVariable ["WA_BECTI_cart",_cart];["CART"] call NeroOP_fnc_bectiShopUI;
};
if (_mode=="ORDER") exitWith {
    private _cart=uiNamespace getVariable ["WA_BECTI_cart",[]];if (count _cart==0 || {uiNamespace getVariable ["WA_BECTI_pending",-1]>=0}) exitWith {};
    private _id=floor random 1000000000;uiNamespace setVariable ["WA_BECTI_pending",_id];uiNamespace setVariable ["WA_BECTI_sent",+_cart];
    (_display displayCtrl 88160) ctrlSetText "Проверка и доставка заказа…";
    [player,_cart apply {[_x#0,_x#1]},_id] remoteExecCall ["NeroOP_fnc_bectiOrder",2];["CART"] call NeroOP_fnc_bectiShopUI;
};
if (_mode in ["TICK","DETAIL"]) exitWith {
    private _pending=uiNamespace getVariable ["WA_BECTI_pending",-1];private _result=player getVariable ["WA_BECTI_orderResult",[-2,[],false]];
    if (_pending>=0 && {(_result#0)==_pending}) then {
        private _results=_result#1;private _last=if (count _results>0) then {(_results#(count _results-1))#1} else {"Доставка…"};
        (_display displayCtrl 88160) ctrlSetText _last;
        if (_result#2) then {
            private _sent=uiNamespace getVariable ["WA_BECTI_sent",[]];private _remaining=[];private _ok=0;
            {if (_forEachIndex<count _results && {(_results#_forEachIndex)#0}) then {_ok=_ok+1;} else {_remaining pushBack _x;};} forEach _sent;
            uiNamespace setVariable ["WA_BECTI_cart",_remaining];uiNamespace setVariable ["WA_BECTI_pending",-1];
            (_display displayCtrl 88160) ctrlSetText format ["Куплено %1 · осталось %2 · %3",_ok,count _remaining,_last];
        };
    };
    private _location=[player] call compile preprocessFileLineNumbers "warArchitect\shopLocation.sqf";
    private _funds=call CTI_CL_FNC_GetPlayerFunds;
    (_display displayCtrl 88154) ctrlSetStructuredText parseText format ["Средства BECTI: %1<br/>%2<br/>Снаряжение поступает в ящик рядом. Машина с экипажем — отдельный отряд; цена экипажа добавляется. Список использует ваш сетап.",_funds,if (count _location>0) then {_location#1} else {"Для заказа нужна своя база или захваченный сектор"}];
    ["CART"] call NeroOP_fnc_bectiShopUI;
};
if (_mode=="CART") exitWith {
    private _sum=0;private _cart=uiNamespace getVariable ["WA_BECTI_cart",[]];
    if !(_cart isEqualTo (_queue getVariable ["WA_BECTI_drawn",[]])) then {
        private _old=lbCurSel _queue;lbClear _queue;{_queue lbAdd (_x#2);} forEach _cart;_queue lbSetCurSel (_old min (count _cart-1));_queue setVariable ["WA_BECTI_drawn",+_cart];
    };
    {_sum=_sum+(_x#3);} forEach _cart;
    private _busy=uiNamespace getVariable ["WA_BECTI_pending",-1]>=0;
    (_display displayCtrl 88157) ctrlSetText format ["Заказать %1 · от %2",count _cart,_sum];
    private _location=[player] call compile preprocessFileLineNumbers "warArchitect\shopLocation.sqf";
    (_display displayCtrl 88157) ctrlEnable (!_busy && {count _cart>0} && {count _location>0});
    (_display displayCtrl 88155) ctrlEnable (!_busy && {_index>=0});(_display displayCtrl 88158) ctrlEnable (!_busy);
};
