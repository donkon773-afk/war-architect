/* Server critical section: create a delivery crate, spend, then add paid cargo. */
params ["_unit","_side","_index"];
private _rows=NeroOP_campGear#_side;if (_index<0 || {_index>=count _rows}) exitWith {false};
private _row=_rows#_index;_row params ["_class","_kind","_price"];
private _table=switch (_kind) do {case "WEAPON":{"CfgWeapons"};case "MAGAZINE":{"CfgMagazines"};case "BACKPACK":{"CfgVehicles"};case "GLASSES":{"CfgGlasses"};default {"CfgWeapons"};};
if (!isClass(configFile >> _table >> _class) || {_unit getVariable ["ACE_isUnconscious",false]}) exitWith {false};
private _source=[_unit,_side,_price] call NeroOP_fnc_campaignWarehouse;if (_source<0) exitWith {false};
private _crate=_unit getVariable ["NeroOP_deliveryCrate",objNull];private _new=isNull _crate || {!alive _crate} || {_crate distance2D _unit>60};
if (_new && {{alive _x} count NeroOP_campCrates>=32}) exitWith {false};
if (_new) then {private _p=(getPosATL _unit) findEmptyPosition [2,20,"Box_NATO_Equip_F"];if (count _p>0) then {_crate=createVehicle ["Box_NATO_Equip_F",_p,[],0,"NONE"];if (!isNull _crate) then {clearWeaponCargoGlobal _crate;clearMagazineCargoGlobal _crate;clearItemCargoGlobal _crate;clearBackpackCargoGlobal _crate;};} else {_crate=objNull;};};
if (isNull _crate) exitWith {false};
private _oldStocks=+NeroOP_campStocks;private _oldLedger=+NeroOP_campLedger;NeroOP_campSeq=NeroOP_campSeq+1;private _spent=[NeroOP_campStocks,NeroOP_campLedger,"spend","gear:"+str NeroOP_campSeq,_source,-1,_price] call NeroOP_fnc_campaignStock;
if !(_spent#2) exitWith {if (_new) then {deleteVehicle _crate;};false};
NeroOP_campStocks=_spent#0;NeroOP_campLedger=_spent#1;
private _delivery=if (_kind=="ITEM" && {getNumber(configFile >> "CfgWeapons" >> _class >> "type")==4096}) then {"WEAPON"} else {_kind};
private _quantity={private _cargo=switch (_delivery) do {case "WEAPON":{getWeaponCargo _crate};case "MAGAZINE":{getMagazineCargo _crate};case "BACKPACK":{getBackpackCargo _crate};default {getItemCargo _crate};};private _i=(_cargo#0) findIf {toLower _x==toLower _class};if (_i<0) then {0} else {(_cargo#1)#_i}};
private _before=call _quantity;
switch (_delivery) do {case "WEAPON":{_crate addWeaponCargoGlobal [_class,1];};case "MAGAZINE":{_crate addMagazineCargoGlobal [_class,1];};case "BACKPACK":{_crate addBackpackCargoGlobal [_class,1];};default {_crate addItemCargoGlobal [_class,1];};};
if ((call _quantity)!=_before+1) exitWith {NeroOP_campStocks=_oldStocks;NeroOP_campLedger=_oldLedger;if (_new) then {deleteVehicle _crate;};false};
_unit setVariable ["NeroOP_deliveryCrate",_crate,true];_crate setVariable ["NeroOP_deliveryOwner",getPlayerUID _unit,true];
_unit setVariable ["NeroOP_notice",format ["Покупка за %1 снабжения доставлена в ящик рядом. Откройте его инвентарь; магазины покупаются отдельно.",_price],true];
if (_new) then {NeroOP_campCrates pushBack _crate;};
true
