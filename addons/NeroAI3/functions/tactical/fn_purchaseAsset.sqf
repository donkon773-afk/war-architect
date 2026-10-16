/* NeroAI 4.5.0 [Vanilla Command] — BUY: a group spends its own Warlords
 * Command Points on vanilla requisition, exactly the way the vanilla AI
 * commander FSM does (functions_f_warlords/fn_WLAIPurchases.fsm), so nothing
 * is invented: the purse is the warlord's BIS_WL_funds, the catalogue is the
 * warlord's BIS_WL_purchasable (the mission's own CfgWLRequisitionPresets),
 * delivery is BIS_fnc_WLAirdrop with the "ordered by AI" flag, and the group's
 * vehicles are booked in BIS_WL_groupVehs.
 *
 *   [_group, _kind, _source] call NeroAI_fnc_purchaseAsset  ->  [ok, message]
 *
 * _kind: INFANTRY | CAR | APC | TANK | TRUCK. Vehicles: the BEST affordable
 * class of that kind (the vanilla FSM buys the cheapest — the point of the CP
 * pool is to field real armour). Infantry: up to 4 men of random affordable
 * classes, never past BIS_WL_maxSubordinates. Aircraft, statics and naval
 * assets are not bought — their vanilla delivery paths are player-UI bound.
 *
 * Only a group whose member is a warlord (BIS_WL_allWarlords) has a purse;
 * sector garrisons and response teams get "no purse" and the planner is told.
 * Drop point: an own sector within 600 m at the base airdrop cost, otherwise
 * on the group at the vanilla remote rate (BIS_WL_dropCost x 40). */
params ["_group", ["_kind", "TANK"], ["_source", "AUTONOMY"],["_dispatch",false],["_dispatchToken",-1]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};
if (isNil "BIS_WL_allWarlords" || {isNil "BIS_fnc_WLAirdrop"}) exitWith {[false, "Реквизиция Warlords недоступна в этом сценарии."]};
if (_group getVariable ["NeroWL_purchaseBlocked", false]) exitWith {[false, "BUY: предыдущая доставка не подтверждена; покупки остановлены до проверки."]};

_kind = toUpper _kind;
if(getNumber(missionConfigFile >> "NeroWL_threeSides")==1)exitWith{private _wl=((units _group)select{_x in (missionNamespace getVariable["BIS_WL_allWarlords",[]])})param[0,objNull];[_wl,"",_kind]call NeroWL_Design_fnc_cqPurchase};
if (_kind in ["HELICOPTER","PLANE","UAV"]) exitWith {[_group,_kind] call NeroAI_fnc_purchaseAirAsset};
if !(_kind in ["INFANTRY", "CAR", "APC", "TANK", "TRUCK"]) exitWith {[false, format ["BUY: неизвестный тип '%1' (INFANTRY/CAR/APC/TANK/TRUCK).", _kind]]};

private _now = diag_tickTime;
private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
private _cooldown = missionNamespace getVariable ["NeroAI_purchaseCooldownSeconds", 90];
if ((_now - (_group getVariable ["NeroAI_lastPurchase", -1e6])) < _cooldown) exitWith {[false, "BUY: реквизиция ещё в пути, повтор позже."]};

private _warlords = missionNamespace getVariable ["BIS_WL_allWarlords", []];
private _living = (units _group) select {alive _x};
private _wl = objNull;
if ((leader _group) in _warlords) then { _wl = leader _group; } else {
    { if (_x in _warlords) exitWith { _wl = _x; }; } forEach _living;
};
if (isNull _wl) exitWith {[false, "BUY: у группы нет командира с кошельком CP — реквизиция недоступна."]};

private _result = [false, "BUY: неизвестная ошибка."];
private _queued = false;

/* Atomic critical section: serialized against vanilla fn_WLAIPurchases.fsm and kill-reward EH.
 * The airdropping test-and-set is inside it — checked outside, a scheduler switch could
 * let the vanilla FSM claim the purse between the check and our flag. */
isNil {
    if (_dispatch && {(_group getVariable ["NeroAI_opToken",0]) != _dispatchToken ||
        {!(_source in ["PLAYER","PLAYER_DEFERRED"]) && {_group getVariable ["NeroAI_playerHold",false] || {diag_tickTime < (_group getVariable ["NeroAI_manualOrderUntil",0])}}}}) exitWith {
        _result = [false,"BUY: заказ устарел или действует новый приказ игрока; CP не списаны."];
    };
    if (_wl getVariable ["BIS_WL_AI_airdropping", false]) exitWith {
        _result = [false, "BUY: предыдущая доставка ещё не завершена (BIS_WL_AI_airdropping)."];
    };
    _wl setVariable ["BIS_WL_AI_airdropping", true];

    private _funds = _wl getVariable ["BIS_WL_funds", 0];
    if !(_funds isEqualType 0) then { _funds = 0; };
    private _maxCP = missionNamespace getVariable ["BIS_WL_maxCP", 10e10];
    if !(_maxCP isEqualType 0) then { _maxCP = 10e10; };
    private _reserve = missionNamespace getVariable ["NeroAI_purchaseReserveCP", 300];

    private _purchasable = _wl getVariable ["BIS_WL_purchasable", nil];
    if (isNil "_purchasable") then {
        _purchasable = missionNamespace getVariable [format ["BIS_WL_purchasable%1", side (group _wl)], nil];
    };
    if (isNil "_purchasable" || {!(_purchasable isEqualType [])} || {(count _purchasable) < 2}) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        _result = [false, "BUY: каталог реквизиции пуст."];
    };
    /* The native airdrop records purchased objects through this mission pointer.
     * Refuse before payment if the Warlords unit is not fully initialized. */
    private _pointer = _wl getVariable ["BIS_WL_pointer", objNull];
    // Native player tracking creates a pointer only for human players. AI
    // purchases use an explicit ledger on their own commander, never a player tracker.
    if (isNull _pointer && {!isPlayer _wl}) then {
        _pointer = _wl;
        _wl setVariable ["BIS_WL_pointer",_wl,true];
        _wl setVariable ["BIS_WL_purchased",[],true];
    };
    if (isNull _pointer || {!((_pointer getVariable ["BIS_WL_purchased", []]) isEqualType [])}) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        _result = [false, "BUY: Warlords ещё не подготовил учёт купленных объектов."];
    };

    /* Drop point and its cost, as the vanilla AI does it. */
    private _dropCost = missionNamespace getVariable ["BIS_WL_dropCost", 25];
    if !(_dropCost isEqualType 0) then { _dropCost = 25; };
    private _dropAt = _wl;
    private _dropFee = _dropCost * 40;
    private _mySide = side (group _wl);
    {
        if ((_x distance2D _wl) < 200 && {(_x getVariable ["BIS_WL_sectorSide", sideUnknown]) isEqualTo _mySide}) exitWith {
            _dropAt = _x; _dropFee = _dropCost;
        };
    } forEach (missionNamespace getVariable ["BIS_WL_sectors", []]);

    private _budget = _funds - _dropFee - _reserve;
    if (_budget <= 0) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        _result = [false, format ["BUY: не хватает CP (есть %1, доставка %2).", round _funds, _dropFee]];
    };

    private _cfgVehs = configFile >> "CfgVehicles";
    private _cfgWeapons = configFile >> "CfgWeapons";

    private _fnc_weaponDetails = {
        params ["_class"];
        private _cfg = _cfgVehs >> _class;
        private _weapons = +(getArray (_cfg >> "weapons"));
        {
            _weapons append (getArray (_x >> "weapons"));
            { _weapons append (getArray (_x >> "weapons")); } forEach ("true" configClasses (_x >> "Turrets"));
        } forEach ("true" configClasses (_cfg >> "Turrets"));

        private _hasCannon = false;
        private _hasATGM = false;
        private _hasMG = false;

        {
            private _w = toLower _x;
            if (!(_w isEqualTo "") && {(_w find "horn") < 0} && {(_w find "smoke") < 0} && {(_w find "laser") < 0} && {(_w find "counter") < 0}) then {
                private _cfgW = _cfgWeapons >> _x;
                private _wName = toLower (getText (_cfgW >> "displayName"));
                private _cursor = toLower (getText (_cfgW >> "cursor"));
                private _cursorAim = toLower (getText (_cfgW >> "cursorAim"));

                // Cannon >= 20mm (autocannons, tank guns)
                if ((_cursor find "cannon") >= 0 || {(_cursorAim find "cannon") >= 0} ||
                    {(_w find "cannon") >= 0} || {(_w find "autocannon") >= 0} ||
                    {(_w find "2a42") >= 0} || {(_w find "2a72") >= 0} || {(_w find "2a70") >= 0} || {(_w find "2a46") >= 0} ||
                    {(_w find "m242") >= 0} || {(_w find "m230") >= 0} || {(_w find "m256") >= 0} || {(_w find "d81") >= 0} ||
                    {(_w find "120mm") >= 0} || {(_w find "125mm") >= 0} || {(_w find "105mm") >= 0} || {(_w find "100mm") >= 0} ||
                    {(_w find "73mm") >= 0} || {(_w find "76mm") >= 0} || {(_w find "57mm") >= 0} || {(_w find "40mm") >= 0} ||
                    {(_w find "35mm") >= 0} || {(_w find "30mm") >= 0} || {(_w find "25mm") >= 0} || {(_w find "20mm") >= 0} ||
                    {(_wName find "cannon") >= 0} || {(_wName find "пушк") >= 0} || {(_wName find "орудие") >= 0}) then {
                    _hasCannon = true;
                };

                // ATGM / Missile launcher
                if ((_cursor find "rocket") >= 0 || {(_cursor find "missile") >= 0} ||
                    {(_w find "atgm") >= 0} || {(_w find "missile") >= 0} || {(_w find "launcher") >= 0} ||
                    {(_w find "kornet") >= 0} || {(_w find "konkurs") >= 0} || {(_w find "metis") >= 0} ||
                    {(_w find "tow") >= 0} || {(_w find "titan") >= 0} || {(_w find "vorona") >= 0} ||
                    {(_w find "spandrel") >= 0} || {(_w find "ataka") >= 0} || {(_w find "malyutka") >= 0} ||
                    {(_w find "9m113") >= 0} || {(_w find "9m133") >= 0} || {(_w find "9m119") >= 0} ||
                    {(_wName find "птур") >= 0} || {(_wName find "atgm") >= 0} || {(_wName find "missile") >= 0}) then {
                    _hasATGM = true;
                };

                // Machine gun
                if ((_w find "mg") >= 0 || {(_w find "hmg") >= 0} || {(_w find "pkt") >= 0} || {(_w find "pkm") >= 0} ||
                    {(_w find "kord") >= 0} || {(_w find "dshk") >= 0} || {(_w find "m2") >= 0} || {(_w find "m240") >= 0} ||
                    {(_w find "gatling") >= 0} || {(_w find "minigun") >= 0} || {(_w find "coaxial") >= 0} ||
                    {(_wName find "пулемёт") >= 0} || {(_wName find "mg") >= 0}) then {
                    _hasMG = true;
                };
            };
        } forEach _weapons;

        [_hasCannon, _hasATGM, _hasMG]
    };

    /* Armed = a real weapon on the hull or in any turret (horns, smoke launchers and
     * lasers do not count). 15.09 night: "BMP-2 Ambulance" passed as a TANK. */
    private _fnc_armed = {
        params ["_class"];
        private _details = [_class] call _fnc_weaponDetails;
        (_details # 0) || {(_details # 1)} || {(_details # 2)}
    };

    private _fnc_vehicleSeats = {
        params ["_class"];
        private _cfg = _cfgVehs >> _class;
        private _cargo = getNumber (_cfg >> "transportSoldier");
        private _turrets = count ("true" configClasses (_cfg >> "Turrets"));
        private _hasDriver = getNumber (_cfg >> "hasDriver");
        private _driver = if (_hasDriver > 0) then {1} else {0};
        _cargo + _turrets + _driver
    };

    private _fnc_kindOf = {
        params ["_class"];
        private _name = toLower (getText (_cfgVehs >> _class >> "displayName"));
        private _support = (_name find "ambulance") >= 0 || {(_name find "medic") >= 0} || {(_name find "repair") >= 0} || {(_name find "fuel") >= 0} || {(_name find "ammo") >= 0} || {(_name find "salvage") >= 0} || {(_name find "санитар") >= 0};
        private _armed = !_support && {[_class] call _fnc_armed};
        private _kind=[_class] call NeroAI_fnc_groundAssetKind;
        if (_kind=="") exitWith {""};
        if (_armed) then {_kind} else {"TRUCK"}
    };

    private _fnc_assetScore = {
        params ["_class", "_cost", "_livingCount", "_enemyAT", "_kind"];
        private _cfg = _cfgVehs >> _class;
        private _name = toLower (getText (_cfg >> "displayName"));
        private _support = (_name find "ambulance") >= 0 || {(_name find "medic") >= 0} || {(_name find "repair") >= 0} || {(_name find "fuel") >= 0} || {(_name find "ammo") >= 0} || {(_name find "salvage") >= 0} || {(_name find "санитар") >= 0};
        if (_support) exitWith { 0 };

        private _details = [_class] call _fnc_weaponDetails;
        _details params ["_hasCannon", "_hasATGM", "_hasMG"];
        if (!_hasCannon && {!_hasATGM} && {!_hasMG}) exitWith { 0 };

        private _seats = [_class] call _fnc_vehicleSeats;

        // Base firepower
        private _power = 0;
        if (_hasCannon) then { _power = _power + 100; };
        if (_hasATGM) then { _power = _power + 80; };
        if (_hasMG) then { _power = _power + 30; };

        // Seating relative to living squad members
        if (_seats >= _livingCount) then {
            _power = _power + 40;
        } else {
            _power = _power + ((_seats min _livingCount) * 5);
        };

        // Tactical suitability
        if (_kind isEqualTo "APC" && {_livingCount >= 4}) then {
            _power = _power + 40;
        };
        if (_kind isEqualTo "TANK") then {
            if (_enemyAT == 0) then {
                _power = _power + 60;
            } else {
                _power = _power - 10;
            };
        };

        // Combat value per CP
        (_power * 1000) / (_cost max 100)
    };

    private _shared = NeroAI_sharedIntel getOrDefault [str _mySide, []];
    private _enemyAT = 0;
    {
        private _type = toLower (_x param [0, ""]);
        private _netId = _x param [5, ""];
        private _hasAT = false;
        if (_netId != "") then {
            private _obj = objectFromNetId _netId;
            if (!isNull _obj && {alive _obj}) then {
                if ((_obj isKindOf "Man" && {secondaryWeapon _obj != ""}) ||
                    {_obj isKindOf "Tank"} || {_obj isKindOf "Wheeled_APC_F"} || {_obj isKindOf "Tracked_APC_F"}) then {
                    _hasAT = true;
                };
            };
        };
        if (!_hasAT && {_type != ""}) then {
            if ((_type find "_at") >= 0 || {(_type find "_aat") >= 0} || {(_type find "_lat") >= 0} ||
                {(_type find "_hat") >= 0} || {(_type find "rpg") >= 0} || {(_type find "tank") >= 0} ||
                {(_type find "bmp") >= 0} || {(_type find "btr") >= 0}) then {
                _hasAT = true;
            };
        };
        if (_hasAT) then { _enemyAT = _enemyAT + 1; };
    } forEach _shared;

    private _pool = [];      /* [class, cost] */
    private _cart = [];      /* classes to drop */
    private _cartCost = 0;

    if (_kind isEqualTo "INFANTRY") then {
        private _maxSub = missionNamespace getVariable ["BIS_WL_maxSubordinates", 9];
        if !(_maxSub isEqualType 0) then { _maxSub = 9; };
        private _room = (_maxSub + 1) - (count _living);
        _room = _room - ({alive _x && {group _x != _group}} count (_group getVariable ["NeroWL_supplyManifest",[]]));
        private _pilotReserve = if (([_wl,_dropAt,[typeOf _wl]] call NeroAI_fnc_baseDeliveryContext) # 0) then {0} else {1};
        _room = _room min (((["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity)-_pilotReserve) max 0);
        if (_room <= 0) exitWith {};
        {
            if (_x isEqualType [] && {(count _x) >= 2} && {(_x # 1) isEqualType 0} && {(_x # 1) <= _budget}) then { _pool pushBack [_x # 0, _x # 1]; };
        } forEach (_purchasable # 0);
        private _n = 0;
        while {_n < (4 min _room) && {!(_pool isEqualTo [])}} do {
            private _pick = selectRandom _pool;
            if ((_cartCost + (_pick # 1)) > _budget) exitWith {};
            _cart pushBack (_pick # 0);
            _cartCost = _cartCost + (_pick # 1);
            _n = _n + 1;
        };
    } else {
        private _groupVehs = (_group getVariable ["BIS_WL_groupVehs", []]) select {!isNull _x && {alive _x}};
        {
            if (alive _x && {(_x getVariable ["BIS_WL_itemOwner",objNull]) in _living}) then {_groupVehs pushBackUnique _x;};
        } forEach (nearestObjects [leader _group,["LandVehicle"],1500]);
        private _maxVehs = missionNamespace getVariable ["NeroAI_purchaseMaxVehicles", 2];
        if ((count _groupVehs) >= _maxVehs) exitWith {};
        {
            if (_x isEqualType [] && {(count _x) >= 2} && {(_x # 0) isEqualType ""} && {(_x # 1) isEqualType 0}
                && {(_x # 1) <= _budget} && {([_x # 0] call _fnc_kindOf) isEqualTo _kind}) then {
                _pool pushBack [_x # 0, _x # 1];
            };
        } forEach (_purchasable # 1);
        if !(_pool isEqualTo []) then {
            /* 4.5.1 T20: best combat value per CP, taking into account weapons, seating, and enemy intel */
            private _best = [];
            private _bestScore = 0;
            {
                private _score = [_x # 0, _x # 1, count _living, _enemyAT, _kind] call _fnc_assetScore;
                if (_score > _bestScore) then {
                    _best = _x;
                    _bestScore = _score;
                };
            } forEach _pool;
            if !(_best isEqualTo []) then {
                _cart = [_best # 0];
                _cartCost = _best # 1;
            };
        };
    };

    if (_cart isEqualTo []) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        private _why = if (_kind isEqualTo "INFANTRY") then {"группа уже полная"} else {format ["в каталоге нет доступного %1 по цене до %2 CP или лимит техники группы исчерпан", _kind, round _budget]};
        _result = [false, format ["BUY %1: нечего купить — %2.", _kind, _why]];
    };

    /* Re-read funds right before payment to prevent lost updates or stale overspends */
    private _withCrew = _kind != "INFANTRY" && {missionNamespace getVariable ["NeroAI_groundPurchaseCrew",true]};
    if (_withCrew) then {
        private _profile = [_cart # 0,_group] call NeroAI_fnc_groundCrewProfile;
        if ((_profile # 1) <= 0 || {(_profile # 1) > 8} || {(_profile # 1) > (["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity)}) then {_cart = [];};
    };
    if (_cart isEqualTo []) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [false,"BUY: нет места для необходимого экипажа; CP не списаны."];
    };
    if (!_dispatch) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [_group,_kind,_source] call NeroAI_fnc_queuePurchase;
        _queued = _result # 0;
    };
    private _baseDelivery = [_wl,_dropAt,_cart] call NeroAI_fnc_baseDeliveryContext;
    private _flightPlan = [];
    if (_kind == "INFANTRY" && {!(_baseDelivery # 0)} && {missionNamespace getVariable ["NeroAI_transportDropEnabled",true]}) then {
        _flightPlan = [_group,_cart,_dropAt] call NeroAI_fnc_airdropPlan;
        if (_flightPlan # 0) then {_wl setVariable ["NeroWL_supplyOffer",[_flightPlan,diag_tickTime+2]];} else {_cart = [];};
    };
    if (_cart isEqualTo []) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [false,"BUY: " + (_flightPlan param [1,"Самолёт доставки недоступен."]) + " CP не списаны."];
    };
    if (_baseDelivery # 0) then {
        private _positions = [_baseDelivery # 1,_cart] call NeroAI_fnc_baseSpawnPositions;
        if (_positions isEqualTo []) then {_cart = [];} else {_wl setVariable ["NeroWL_groundDeliveryPlan",[+_cart,_positions,_dropAt,diag_tickTime+5]];};
    };
    if (_cart isEqualTo []) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping",false];
        _result = [false,"BUY: на базе нет подходящей свободной площадки; CP не списаны."];
    };
    private _fundsNow = _wl getVariable ["BIS_WL_funds", 0];
    if !(_fundsNow isEqualType 0) then { _fundsNow = 0; };
    private _totalCost = _cartCost + _dropFee;
    if (_fundsNow < _totalCost) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        _result = [false, format ["BUY %1: средства изменились во время оформления (было %2, сейчас %3, требуется %4).", _kind, round _funds, round _fundsNow, round _totalCost]];
    };

    private _oldPurchaseHold = _group getVariable ["NeroAI_purchaseHoldUntil",0];
    if !([_group,_kind,_baseDelivery # 0] call NeroAI_fnc_claimSidePurchaseSlot) exitWith {
        _wl setVariable ["BIS_WL_AI_airdropping", false];
        _result = [false, "BUY: действует пауза стороны или достигнут общий лимит ресурсов миссии."];
    };

    /* Pay with delta: funds_now - cost - fee */
    private _newFunds = ((_fundsNow - _totalCost) max 0) min _maxCP;
    _wl setVariable ["BIS_WL_funds", _newFunds, true];
    _wl setVariable ["BIS_WL_dropPos", _dropAt];

    private _delivered = [_wl, _cart, true] call BIS_fnc_WLAirdrop;
    _wl setVariable ["BIS_WL_AI_airdropping", false];

    if !(_delivered isEqualType []) then { _delivered = []; };
    _group setVariable ["NeroAI_lastPurchase", _now, true];
    if (_baseDelivery # 0 || {!isNull (_group getVariable ["NeroWL_supplyFlight",objNull])}) then {_group setVariable ["NeroAI_purchaseHoldUntil",_oldPurchaseHold,true];};
    private _confirmed = {(_x isEqualType objNull) && {!isNull _x} && {alive _x}} count _delivered;
    if !([count _cart,count _delivered,_confirmed] call NeroAI_fnc_deliveryConfirmed) then {_delivered = [];};
    if (_delivered isEqualTo []) exitWith {
        _group setVariable ["NeroWL_purchaseBlocked", true, true];
        ["ERROR", format ["%1 BUY %2: Warlords delivery confirmed %3/%4 living assets after CP payment; no automatic retry.", _callsign, _kind,_confirmed,count _cart]] call NeroAI_fnc_log;
        _result = [false, "Warlords не подтвердил весь состав доставки после списания CP; повторная покупка остановлена."];
    };

    private _names = _cart apply { private _dn = getText (_cfgVehs >> _x >> "displayName"); if (_dn isEqualTo "") then {_x} else {_dn} };
    private _left = round (_wl getVariable ["BIS_WL_funds", 0]);

    if (_kind isEqualTo "INFANTRY") then {
        ["INFO", format ["%1 BUY INFANTRY: %2 за %3 CP + доставка %4; осталось %5 CP.", _callsign, _names joinString ", ", _cartCost, _dropFee, _left]] call NeroAI_fnc_log;
        _result = [true, format ["%1: %2 (−%3 CP, осталось %4).",if (isNull (_group getVariable ["NeroWL_supplyFlight",objNull])) then {"Пополнение доставлено"} else {"Десант на борту транспортника, доставка ещё в пути"},_names joinString ", ", _cartCost + _dropFee, _left]];
    } else {
        private _vehs = _delivered select {_x isEqualType objNull && {!isNull _x} && {!(_x isKindOf "Man")}};
        _group setVariable ["BIS_WL_groupVehs", ((_group getVariable ["BIS_WL_groupVehs", []]) select {!isNull _x}) + _vehs, true];
        { _x setVariable ["NeroAI_ownerSide", _mySide, true]; } forEach _vehs;
        private _crewFailures = [];
        if (_withCrew) then {
            {private _crewResult = [_x,_group,_wl] call NeroAI_fnc_crewGroundAsset;if !(_crewResult # 0) then {_crewFailures pushBack (_crewResult # 1);};} forEach _vehs;
        };
        if (_crewFailures isNotEqualTo []) exitWith {
            _group setVariable ["NeroWL_purchaseBlocked",true,true];
            _result = [false,"Машина доставлена, но экипаж не подтверждён: " + (_crewFailures joinString "; ")];
            ["ERROR",format ["%1 BUY CREW failed: %2; no automatic retry",_callsign,_crewFailures]] call NeroAI_fnc_log;
        };
        /* Boarding is fn_autoRequisition's job (own vehicle first, exact target)
         * once the drop has landed — no second boarding path here. */
        ["INFO", format ["%1 BUY %2: %3 за %4 CP + доставка %5 на %6; осталось %7 CP.", _callsign, _kind, _names joinString ", ", _cartCost, _dropFee, if (_dropAt isEqualTo _wl) then {"группу"} else {"свой сектор"}, _left]] call NeroAI_fnc_log;
        _result = [true, format ["Реквизиция: %1 (−%2 CP, осталось %3), доставка с экипажем; пехота занимает свободные пассажирские места по прибытии.", _names joinString ", ", _cartCost + _dropFee, _left]];
    };
};

/* Per-minute counters for fn_sideTelemetry. */
if (!_queued) then {if (_result # 0) then {private _k=format ["NeroWL_buys_%1",side _group];missionNamespace setVariable [_k,(missionNamespace getVariable [_k,0])+1];} else {private _k=format ["NeroWL_buyRefusals_%1",side _group];missionNamespace setVariable [_k,(missionNamespace getVariable [_k,0])+1];};};
_result
