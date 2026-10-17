// Internal server transaction. RPC authorization/serialization lives in bectiOrder.
params ["_buyer","_index",["_withCrew",true]];
if (!isServer || {isNull _buyer} || {!alive _buyer} || {!(_index isEqualType 0)} || {_index!=floor _index} || {_index<0} || {!(_withCrew isEqualType true)}) exitWith {[false,"Неверный заказ"]};
private _side=side group _buyer;
if !(_side in [west,east]) exitWith {[false,"Неизвестная сторона"]};
private _army=missionConfigFile >> "CfgWarArchitectShop" >> (if (_side==west) then {"WEST"} else {"EAST"});
private _rows="true" configClasses (_army >> "Rows");
if (_index>=count _rows) exitWith {[false,"Позиция отсутствует в сетапе"]};
private _row=_rows#_index;private _class=getText(_row >> "className");private _table=getText(_row >> "table");private _kind=getText(_row >> "kind");private _cost=getNumber(_row >> "price");
if (!isClass(configFile >> _table >> _class)) exitWith {[false,format ["Не загружен класс %1",_class]]};
private _location=[_buyer] call compile preprocessFileLineNumbers "warArchitect\shopLocation.sqf";
if (count _location==0) exitWith {[false,"Нужна своя база или захваченный сектор"]};
if (_buyer getVariable ["ACE_isUnconscious",false] || {_buyer getVariable ["REV_UNC",false]}) exitWith {[false,"Покупатель без сознания"]};
private _group=group _buyer;
// Pin the native account for this transaction; changing commander during an
// order must not charge a different pool. Quote first; commit the native
// balance only AFTER legacy spawning, which can replicate stale group state.
private _waAccountGroup=_group;private _waAccountSide=_side;
private _waCommanderAccount=(_side call CTI_CO_FNC_GetSideCommander)==_group;
private _waBalance={if (_waCommanderAccount) then {_waAccountSide call CTI_CO_FNC_GetFundsCommander} else {_waAccountGroup call CTI_CO_FNC_GetFundsTeam}};
private _waChange={params ["_waDelta"];if (_waCommanderAccount) then {[_waAccountSide,_waDelta] call CTI_CO_FNC_ChangeFundsCommander;} else {[_waAccountGroup,_waDelta] call CTI_CO_FNC_ChangeFundsTeam;};};
private _waReserved=0;private _waPaid=false;
private _waReserve={
    params ["_waAmount"];private _waOK=false;
    isNil {private _waNow=call _waBalance;if (!isNil "_waNow" && {_waNow isEqualType 0} && {_waNow>=_waReserved+_waAmount}) then {_waReserved=_waReserved+_waAmount;_waOK=true;};};
    _waOK
};
if !([_cost] call _waReserve) exitWith {[false,"Недостаточно средств BECTI"]};
private _anchor=_location#0;private _created=objNull;private _newGroup=grpNull;private _newUnits=[];private _error="";
private _waCreate=compile preprocessFileLineNumbers "warArchitect\createNative.sqf";
if (_kind in ["INFANTRY","VEHICLE"]) then {
    private _spawnClass=_class;
    if (_kind=="VEHICLE") then {private _override=getText(configFile >> "CfgNeroAirDefense" >> _class >> "spawnClass");if (_override!="") then {_spawnClass=_override;};};
    private _position=[];private _ship=_spawnClass isKindOf "Ship";
    for "_i" from 0 to 23 do {
        private _p=_anchor getPos [if (_ship) then {100+200*floor(_i/8)} else {16+12*floor(_i/8)},_i*45];
        private _free=_p findEmptyPosition [0,8,_spawnClass];
        if (count _free>=2 && {surfaceIsWater _free isEqualTo _ship} && {_free distance2D _anchor<(if (_ship) then {600} else {65})}) exitWith {_position=_free;};
    };
    if (count _position<2) then {_error="Нет свободной площадки для доставки";} else {
        if (_kind=="INFANTRY") then {
            if (leader _group!=_buyer) then {_error="Пехоту заказывает командир своего отряда";} else {
                // The player's group can belong to a remote client. Create in
                // a server-local staging group, then join the original group.
                private _staging=createGroup [_side,true];_staging setVariable ["cti_server_group",str _side];
                _created=["UNIT",[_class,_staging,_position,_side call CTI_CO_FNC_GetSideID,true]] call _waCreate;
                if (!isNull _created) then {_newUnits pushBack _created;[_created] joinSilent _group;if (group _created!=_group) then {_error="Боец создан, но не присоединился к отряду";};};
                if (!isNull _staging && {count units _staging==0}) then {deleteGroup _staging;};
            };
        } else {
            // Empty aircraft arrive on the ground. Crewed planes start straight,
            // at flying speed, using the shared aircraft launch correction.
            private _special=if (_spawnClass isKindOf "Plane" && {_withCrew}) then {"FLY"} else {"NONE"};
            private _heading=if (_spawnClass isKindOf "Air") then {_position getDir [worldSize/2,worldSize/2]} else {0};
            _created=["VEHICLE",[_spawnClass,_position,_heading,_side,true,true,true,_special]] call _waCreate;
            if (!isNull _created && {_withCrew}) then {
                _newGroup=createGroup [_side,true];_newGroup setVariable ["cti_server_group",str _side,true];
                _newGroup setVariable ["WA_BECTI_ownerUID",getPlayerUID _buyer,true];
                _newGroup setGroupIdGlobal [format ["WA %1",groupId _newGroup]];
                private _crewClass=getText(_army >> (if (_spawnClass isKindOf "Air") then {"pilotClass"} else {"crewClass"}));
                private _seats=fullCrew [_created,"",true] select {toLower(_x#1)!="cargo" && {!(_x param [4,false])}};
                private _crewPrice=getNumber(_army >> "crewPrice");
                private _extra=count _seats*_crewPrice;_cost=_cost+_extra;
                if !([_extra] call _waReserve) then {_error="Недостаточно средств на машину и экипаж";} else {
                    if (getNumber(configFile >> "CfgVehicles" >> _spawnClass >> "isUav")==1) then {
                        createVehicleCrew _created;_newUnits=crew _created;_newUnits joinSilent _newGroup;
                    } else {
                        {
                            private _u=["UNIT",[_crewClass,_newGroup,_position,_side call CTI_CO_FNC_GetSideID,true]] call _waCreate;
                            if (!isNull _u) then {
                                _newUnits pushBack _u;
                                if (toLower(_x#1)=="driver") then {_u assignAsDriver _created;_u moveInDriver _created;} else {_u assignAsTurret [_created,_x#3];_u moveInTurret [_created,_x#3];};
                            };
                        } forEach _seats;
                    };
                    if (count _newUnits<count _seats || {_newUnits findIf {vehicle _x!=_created}>=0}) then {_error="Не удалось разместить весь экипаж";};
                    if (_error=="") then {
                        _newGroup addVehicle _created;_newGroup setBehaviour "AWARE";_newGroup setCombatMode "YELLOW";
                        _newGroup setVariable ["cti_funds",0,true];_newGroup setVariable ["cti_independent",false,true];
                        private _waRole=switch (getText(_row >> "aiRole")) do {case "FIGHTER":{"AirIntercept"};case "CAS":{"AirCAS"};case "ATTACK_HELI":{"AirHeli"};case "BOMBER":{"AirBomber"};case "TANK":{"Armored"};case "APC":{"Mechanized"};case "AAA":{"AntiAir"};case "SAM":{"AntiAir"};case "RADAR":{"AntiAir"};default {"Motorized"};};
                        _newGroup setVariable ["cti_role",_waRole,true];_newGroup setVariable ["WA_BECTI_vehicle",_created,true];
                        if (_spawnClass isKindOf "Plane") then {_created setVariable ["WA_BECTI_climbUntil",serverTime+30];};
                        _newGroup setVariable ["cti_order",CTI_ORDER_MOVE,true];_newGroup setVariable ["cti_order_pos",if (_spawnClass isKindOf "Plane") then {(getPosATL _created) getPos [5000,getDir _created]} else {getPosATL _created},true];
                        [_newGroup,_side,_buyer] call {private _group=_this#0;_this call CTI_SE_FNC_InitializeGroup;};
                        [_newGroup,_side] execFSM "Server\FSM\update_ai.fsm";
                    };
                };
            };
        };
    };
    if (isNull _created && {_error==""}) then {_error="Игра не создала заказанный объект";};
} else {
    private _box=_buyer getVariable ["WA_BECTI_deliveryBox",objNull];
    if (isNull _box || {!alive _box} || {_buyer distance2D _box>30}) then {
        private _p=(getPosATL _buyer) findEmptyPosition [2,12,"Box_NATO_Equip_F"];
        if (count _p<2 || {surfaceIsWater _p}) then {_error="Нет места для ящика снаряжения";} else {
            _box=createVehicle ["Box_NATO_Equip_F",_p,[],0,"NONE"];
            clearWeaponCargoGlobal _box;clearMagazineCargoGlobal _box;clearItemCargoGlobal _box;clearBackpackCargoGlobal _box;
            _box setVariable ["cti_gc_noremove",true,true];_buyer setVariable ["WA_BECTI_deliveryBox",_box,true];
        };
    };
    if (_error=="" && {!isNull _box}) then {
        private _cargo={params ["_b","_k"];switch (_k) do {case "WEAPON":{getWeaponCargo _b};case "MAGAZINE":{getMagazineCargo _b};case "BACKPACK":{getBackpackCargo _b};default {getItemCargo _b};};};
        // Cargo insertion and payment share one unscheduled commit. Nothing
        // can spend this account between its final check and the insertion.
        isNil {
            if ((call _waBalance)<_waReserved) then {_error="Недостаточно средств: бюджет изменился во время заказа";} else {
                private _before=[_box,_kind] call _cargo;
                switch (_kind) do {case "WEAPON":{_box addWeaponCargoGlobal [_class,1];};case "MAGAZINE":{_box addMagazineCargoGlobal [_class,1];};case "BACKPACK":{_box addBackpackCargoGlobal [_class,1];};default {_box addItemCargoGlobal [_class,1];};};
                if (([_box,_kind] call _cargo) isEqualTo _before) then {_error="Предмет не помещён в ящик; деньги не списаны";} else {_created=_box;[-_waReserved] call _waChange;_waPaid=true;};
            };
        };
    };
};
if (_error=="" && {!_waPaid}) then {
    isNil {
        if (isNull _buyer || {!alive _buyer} || {group _buyer!=_waAccountGroup} || {side group _buyer!=_waAccountSide}) then {_error="Покупатель недоступен или сменил отряд; заказ отменён";} else {
            if ((call _waBalance)<_waReserved) then {_error="Недостаточно средств: бюджет изменился во время заказа";} else {[-_waReserved] call _waChange;_waPaid=true;};
        };
    };
};
if (_error!="") exitWith {
    {deleteVehicle _x;} forEach _newUnits;
    if (!isNull _newGroup) then {deleteGroup _newGroup;};
    if (_kind=="VEHICLE" && {!isNull _created}) then {deleteVehicle _created;};
    [false,_error]
};
_created setVariable ["cti_occupant",_side,true];
if (_kind=="VEHICLE") then {_created setVariable ["v_keys",[getPlayerUID _buyer,_group,_newGroup],true];_created lock 0;};
diag_log format ["[WarArchitect BECTI SHOP] delivered uid=%1 class=%2 cost=%3 object=%4 crew=%5 pos=%6 accountFunds=%7",getPlayerUID _buyer,_class,_waReserved,_created,count _newUnits,getPosATL _created,call _waBalance];
[true,format ["Куплено: %1 · %2",getText(configFile >> _table >> _class >> "displayName"),_waReserved]]
