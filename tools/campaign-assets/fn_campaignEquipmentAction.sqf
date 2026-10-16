params [["_unit",objNull,[objNull]],["_mode","",[""]],["_index",-1,[0]]];
if (!isServer || {NeroOP_campFinished} || {!NeroOP_campReady} || {isNull _unit} || {!isPlayer _unit} || {!alive _unit} || {isRemoteExecuted && {remoteExecutedOwner!=owner _unit}} || {floor _index!=_index}) exitWith {};
private _side=[west,east] find side group _unit;if (_side<0) exitWith {};
if (_mode=="READY") exitWith {
 private _found=NeroOP_campEquipment findIf {(_x#0)==_index && {(_x#1)==_side} && {(_x#3)==1}};
 if (_found>=0) then {private _plane=(NeroOP_campEquipment#_found)#4;
  if ((_plane getVariable ["NeroOP_pendingPilot",objNull])==_unit && {driver _plane==_unit}) then {
   private _row=NeroOP_campEquipment#_found;private _old=_row#6;_row set [6,group _unit];if (!isNull _old && {_old!=group _unit} && {count units _old==0}) then {deleteGroup _old;};
   _plane enableSimulationGlobal true;_plane allowDamage true;_plane setVariable ["NeroOP_equipmentLaunched",true,true];_plane setVariable ["NeroOP_pendingPilot",objNull,true];_unit setCaptive false;
  };
 };
};
if (_mode=="CM") exitWith {private _v=vehicle _unit;private _uav=getConnectedUAV _unit;if (!isNull _uav) then {_v=_uav;};if (_v isKindOf "Air" && {driver _v==_unit || {gunner _v==_unit} || {getConnectedUAV _unit==_v}}) then {[_v] call NeroOP_fnc_campaignCountermeasure;};};
if (_mode=="FP_EVADE") exitWith {private _i=NeroOP_campEquipment findIf {(_x#0)==_index && {(_x#1)==_side} && {(_x#4) getVariable ["NeroOP_specialKind",-1]==0} && {getConnectedUAV _unit==(_x#4)}};if (_i>=0) then {private _v=(NeroOP_campEquipment#_i)#4;private _on=!(_v getVariable ["NeroOP_fpEvade",false]);_v setVariable ["NeroOP_fpEvade",_on,true];_unit setVariable ["NeroOP_notice",if (_on) then {"Фламинго: маневр при обнаруженном пуске перехватчика включён."} else {"Фламинго: маневр уклонения выключен."},true];};};
if !(_mode in ["BUY_EMPTY","BUY","FLY","GEAR","TRAVEL","TRUCK","REINFORCE","REARM","RECRUIT"]) exitWith {};
if (serverTime-(_unit getVariable ["NeroOP_equipmentAt",-100])<3) exitWith {};_unit setVariable ["NeroOP_equipmentAt",serverTime];
if (_mode=="RECRUIT") exitWith {private _ok=false;isNil {_ok=[_unit,_side,_index] call NeroOP_fnc_campaignRecruit;};if (!_ok) then {_unit setVariable ["NeroOP_notice","Нужны командование своим отрядом, связанная база/склад рядом, снабжение, безопасная зона и место до 12 бойцов AI с экипажами. Проверьте резерв пополнений.",true];};};
if (_mode=="TRUCK") exitWith {private _truck=objNull;isNil {_truck=[_side,_unit] call NeroOP_fnc_campaignSupplyTruck;};_unit setVariable ["NeroOP_notice",if (isNull _truck) then {"Недостаточно снабжения склада или парк грузовиков заполнен."} else {"Грузовик снабжения куплен. Диспетчер использует его для доставки от базы."},true];};
if (_mode=="REINFORCE") exitWith {private _ok=false;isNil {_ok=[_unit,_side] call NeroOP_fnc_campaignReinforce;};_unit setVariable ["NeroOP_notice",if (_ok) then {"Отдельный отряд оплачен и передан в High Command."} else {"Подкрепление недоступно: связанный склад, запас, резерв и свободное место."},true];};
if (_mode=="REARM") exitWith {[_unit,_side] spawn NeroOP_fnc_campaignRearm;};
if (_mode=="TRAVEL") exitWith {if !(_unit getVariable ["ACE_isUnconscious",false]) then {[_unit,_side,_index] spawn NeroOP_fnc_campaignTravel;};};
if (_mode=="GEAR") exitWith {private _ok=false;isNil {_ok=[_unit,_side,_index] call NeroOP_fnc_campaignGearBuy;};if (!_ok) then {_unit setVariable ["NeroOP_notice","Нет местного снабжения или связанного склада рядом; проверьте доступность предмета.",true];};};
if (_mode=="FLY") exitWith {
 if (vehicle _unit!=_unit || {[_unit,_side,0,true] call NeroOP_fnc_campaignWarehouse<0}) exitWith {};
 private _found=NeroOP_campEquipment findIf {(_x#0)==_index && {(_x#1)==_side} && {(_x#3)==1} && {alive (_x#4)} && {isNull driver (_x#4)} && {!(_x#7)}};
 if (_found>=0) then {private _row=NeroOP_campEquipment#_found;[_unit,_row#4,_row#6] call NeroOP_fnc_campaignLaunchFlight;};
};
private _group=group _unit;if !(_group getVariable ["NeroOP_campGroup",false]) exitWith {_unit setVariable ["NeroOP_notice","Закупку выполняет командир наземного отряда.",true];};
private _vehicle=objNull;isNil {_vehicle=[_side,_index,_group,_unit,[],_mode=="BUY_EMPTY"] call NeroOP_fnc_campaignBuy;};
_unit setVariable ["NeroOP_notice",if (isNull _vehicle) then {"Покупка отклонена: нужны связанный свой сектор рядом, местное снабжение, свободный лимит и пауза между заказами. Фламинго: 20 мин после потери, Ту-95: 15 мин; по одному на сторону."} else {"Техника куплена. Наземная машина готова рядом; самолёт передаётся пилоту."},true];
