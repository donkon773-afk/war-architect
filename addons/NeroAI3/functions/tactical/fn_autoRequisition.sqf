/* NeroAI 4.5.0 [Vanilla Command] — deterministic requisition policy, run for
 * every active group on the fast autonomy tick (8 s), before any LLM plan.
 *
 * LIVE INCIDENT (14.09 21:46): every warlord got 15 000 CP; the vanilla AI
 * commander FSM (and later BUY) airdrops vehicles to the group's base sector,
 * and the vanilla FSM then boards them with a GETIN waypoint. NeroAI's own
 * doMove plans (SET_ROE + ADVANCE on every cycle) walked the squads away from
 * their fresh vehicles, which stayed EMPTY at the RED base — the user saw
 * "empty GREEN vehicles at RED's base" (T-34/T-55/BTR-60 are the Takistani
 * army's own requisition in this mission). gpt-4o-mini also never chose BUY or
 * BOARD on its own in 35 plans. So both are policy now, not a model whim:
 *
 *   A) OWN VEHICLE FIRST — a group on foot whose BIS_WL_groupVehs holds an
 *      alive, drivable, EMPTY vehicle boards it (≤ 550 m: BOARD; ≤ 1500 m:
 *      move to it first). Vanilla purchase or NeroAI BUY, same rule.
 *   B) SPEND — a group with a purse, no vehicle of its own and cp ≥
 *      NeroAI_purchaseAutoMinCP buys one (APC when the squad is ≥ 4 men so
 *      everybody rides, else TANK; falls back through TANK/CAR when the
 *      catalogue lacks the kind). One attempt per cooldown; a refusal is logged
 *      once and retried later. The LLM keeps BUY for tactical purchases on top.
 *
 * Player hold / manual order window suppress both. Nothing is spawned here. */
params ["_group"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_purchaseAutoEnabled", true])) exitWith {};
if (isNil "BIS_WL_allWarlords") exitWith {};

private _now = diag_tickTime;
[_group] call NeroAI_fnc_assignDefaultRole;
if (_group getVariable ["NeroAI_playerHold", false]) exitWith {};
if (_group getVariable ["NeroWL_vehicleService",false]) exitWith {};
if (_now < (_group getVariable ["NeroAI_manualOrderUntil", 0])) exitWith {};
/* 8.10: a running behaviour template (LAMBS task) owns the squad — no boarding walks or purchases mid-fight. */
if ((((_group getVariable ["NeroWL_tactic", []]) param [3, ""])) isEqualTo "EXEC") exitWith {};
[_group] call NeroAI_fnc_autoAirTask;
if (_group getVariable ["NeroWL_transportActive",false]) exitWith {};
if (_now < (_group getVariable ["NeroWL_logisticsUntil",0]) && {(_group getVariable ["NeroAI_vehicleState",""]) != "MOVING"}) exitWith {};
if ((_group getVariable ["NeroAI_vehicleState", ""]) in ["BOARDING", "PARTIAL_BOARDING"]) exitWith {};
/* A confirmed assault dismount must not immediately trigger auto-boarding. */
private _footObjective = _group getVariable ["NeroWL_assaultOnFoot",[]];
private _nativeObjective = [_group] call NeroAI_fnc_wlGroupObjective;
if (count _footObjective >= 2 && {!isNull _nativeObjective}
    && {_footObjective distance2D _nativeObjective < 60} && {(leader _group) distance2D _footObjective < 1000}) exitWith {};
_group setVariable ["NeroWL_assaultOnFoot",nil];

private _leader = leader _group;
private _living = (units _group) select {alive _x};
if (_living isEqualTo []) exitWith {};
private _onFoot = (vehicle _leader) isEqualTo _leader;
private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];

/* Own vehicles: the group's BIS_WL_groupVehs plus any airdropped vehicle whose
 * BIS_WL_itemOwner is one of us — the vanilla "AI veh" handler drops a vehicle
 * from groupVehs after 180 s unboarded, and it must not be forgotten for that. */
private _ownAll = (_group getVariable ["BIS_WL_groupVehs", []]) select {!isNull _x && {alive _x} && {_x isKindOf "LandVehicle"}};
{
    if (((_x getVariable ["BIS_WL_itemOwner", objNull]) in _living) && {alive _x} && {!(_x in _ownAll)}) then { _ownAll pushBack _x; };
} forEach (nearestObjects [_leader, ["LandVehicle"], 1500]);
private _own = _ownAll select {
    canMove _x && {isNull (attachedTo _x)} && {((getPosATL _x) # 2) < 3}
};
/* Live 22:26-22:40: one group re-tried the same unreachable ZSU-23 every cycle.
 * After 3 failed attempts a vehicle is set aside for 10 minutes. */
private _shelved = _group getVariable ["NeroAI_autoBoardShelved", []];
_shelved = _shelved select {!isNull (_x # 0) && {(_now - (_x # 1)) < 600}};
_group setVariable ["NeroAI_autoBoardShelved", _shelved, true];
private _shelvedVehs = _shelved apply {_x # 0};
private _empty = _own select {((crew _x) isEqualTo []) && {!(_x in _shelvedVehs)}};
private _mannedWithSeats = _own select {
    !((crew _x) isEqualTo []) && {!(_x in _shelvedVehs)} &&
    {((fullCrew [_x, "", true]) findIf {
        isNull (_x param [0, objNull]) && {isNull (_x param [5, objNull])}
    }) >= 0}
};
private _boardable = _empty + _mannedWithSeats;

/* Board owned vehicles with free seats, including one whose driver has already
 * mounted while the pedestrian tail is still outside. */
private _pedestrians = _living select {vehicle _x isEqualTo _x};
private _manned = _own select {!((crew _x) isEqualTo [])};
private _canBoardInitial = _onFoot && {!(_boardable isEqualTo [])};
private _canBoardTail = (!(_pedestrians isEqualTo [])) && {!(_boardable isEqualTo [])} && {(!_onFoot) || {!(_manned isEqualTo [])}};

if ((_canBoardInitial || _canBoardTail) && {!(_boardable isEqualTo [])}) exitWith {
    if ((_now - (_group getVariable ["NeroAI_lastAutoBoard", -1e6])) < 45) exitWith {};
    private _refUnit = if (_onFoot) then {_leader} else {_pedestrians # 0};
    private _v = _boardable # 0;
    { if ((_x distance2D _refUnit) < (_v distance2D _refUnit)) then { _v = _x; }; } forEach _boardable;
    private _d = _v distance2D _refUnit;
    if (_d > 1500) exitWith {};
    _group setVariable ["NeroAI_lastAutoBoard", _now, true];
    private _progress=_group getVariable ["NeroWL_boardProgress",[objNull,1e9,_now]];
    if ((_progress # 0) != _v || {_d < (_progress # 1) - 15}) then {_progress=[_v,_d,_now];};
    _group setVariable ["NeroWL_boardProgress",_progress];
    _group setVariable ["NeroWL_logisticsUntil",_now+55];
    private _tries = _group getVariable ["NeroAI_autoBoardTries", [objNull, 0]];
    if (_d <= 200 || {_now - (_progress # 2) > 180}) then {
      if ((_tries # 0) isEqualTo _v) then { _tries set [1, (_tries # 1) + 1]; } else { _tries = [_v, 1]; };
    };
    _group setVariable ["NeroAI_autoBoardTries", _tries, true];
    if ((_tries # 1) > 3) exitWith {
        _group setVariable ["NeroWL_logisticsUntil",0];
        _shelved pushBack [_v, _now];
        _group setVariable ["NeroAI_autoBoardShelved", _shelved, true];
        _group setVariable ["NeroAI_autoBoardTries", [objNull, 0], true];
        private _payer=(_living select {_x in BIS_WL_allWarlords}) param [0,objNull];
        private _resume=if(isNull _payer)then{[]}else{_payer getVariable ["BIS_WL_curWP",[]]};
        if (waypointType [_group,currentWaypoint _group]=="GETIN" && {_resume isEqualType []} && {count _resume==2} && {(_resume # 0) isEqualTo _group} && {(_resume # 1)>0} && {(_resume # 1)<count waypoints _group} && {waypointType _resume in ["MOVE","SAD"]}) then {
            _group setCurrentWaypoint _resume;
            _group setVariable ["NeroAI_forcePlan",true,true];
        };
        ["WARN", format ["%1 could not board its own %2 after 3 attempts — set aside for 10 min.", _callsign, typeOf _v]] call NeroAI_fnc_log;
    };
    private _vpos = getPosATL _v;
    if (_d <= 200) then {
        private _r = [_group, "BOARD", _vpos, _v] call NeroAI_fnc_vehicleTactics;
        ["INFO", format ["%1 auto-board own %2 at %3 m: %4", _callsign, typeOf _v, round _d, _r # 1]] call NeroAI_fnc_log;
    } else {
        private _r = [_group, "MOVE", _vpos] call NeroAI_fnc_vehicleTactics;
        ["INFO", format ["%1 moves to its own %2 at %3 m before boarding: %4", _callsign, typeOf _v, round _d, _r # 1]] call NeroAI_fnc_log;
    };
};

/* B) spend only when the group has no vehicle of its own. Partial boarding
 * must be resolved before this group asks for another asset. */
private _maxVehicles = missionNamespace getVariable ["NeroAI_purchaseMaxVehicles", 2];
private _minCP = missionNamespace getVariable ["NeroAI_purchaseAutoMinCP", 2500];
private _cooldown = missionNamespace getVariable ["NeroAI_purchaseCooldownSeconds", 90];
if ((_group getVariable ["NeroWL_pendingPurchase",[]]) isNotEqualTo []) exitWith {};
private _vState = _group getVariable ["NeroAI_vehicleState", ""];
private _aliveOwn = _ownAll select {alive _x};

private _role=_group getVariable ["NeroWL_role","INFANTRY"];
private _airRole=(_role in ["AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"]) && {missionNamespace getVariable ["NeroAI_airEnabled",true]};
private _wls = missionNamespace getVariable ["BIS_WL_allWarlords", []];
private _wl = _living select {_x in _wls};
/* A newly enrolled solo warlord must recruit infantry; a ratio of 1/1 is
 * not a full assault squad. Native buying is disabled for enrolled groups. */
private _reinforced = false;
if (!_airRole && {_wl isNotEqualTo []} && {_role in ["INFANTRY","MECHANIZED","RECON"]}
    && {count _living < (_group getVariable ["NeroAI_rulesMinAssaultStrength",missionNamespace getVariable ["NeroAI_rulesMinAssaultStrength",6]])}
    && {_now-(_group getVariable ["NeroWL_lastInfantryTry",-1e6]) >= _cooldown}) then {
    _group setVariable ["NeroWL_lastInfantryTry",_now];
    private _result = [_group,"INFANTRY","AUTONOMY"] call NeroAI_fnc_purchaseAsset;
    _reinforced = _result # 0;
};
if (_reinforced) exitWith {};

/* C) Air roles buy their own aircraft regardless of any ground vehicle the
 * group may hold: AIR_TRANSPORT a transport helicopter, AIR_CAS a strike plane
 * (attack helicopter when no plane is affordable), AIR_SUPERIORITY a fighter.
 * One paid aircraft per air group; side air cap, side pause and CP reserve are
 * enforced in fn_purchaseAirAsset. A changed refusal reason is logged. */
if (_airRole) exitWith {
    if (_wl isEqualTo []) exitWith {};
    if ((_now - (_group getVariable ["NeroAI_lastAutoBuyTry", -1e6])) < _cooldown) exitWith {};
    private _fleet=vehicles select {alive _x && {_x getVariable ["NeroWL_paidAir",false]} && {(_x getVariable ["BIS_WL_itemOwner",objNull]) == (_wl # 0)}};
    if !(_fleet isEqualTo []) exitWith {};
    private _cp = (_wl # 0) getVariable ["BIS_WL_funds", 0];
    if (!(_cp isEqualType 0) || {_cp < _minCP}) exitWith {};
    _group setVariable ["NeroAI_lastAutoBuyTry", _now, true];
    private _kinds=switch (_role) do {case "AIR_TRANSPORT": {["HELICOPTER"]}; case "AIR_CAS": {["PLANE","HELICOPTER"]}; default {["PLANE"]};};
    private _why=[];
    {
        private _r=[_group,_x,"AUTONOMY"] call NeroAI_fnc_purchaseAsset;
        if (_r # 0) exitWith {
            _why=[];
            _group setVariable ["NeroAI_forcePlan",true,true];
            _group setVariable ["NeroWL_lastAirRefusal",""];
            ["INFO", format ["%1 auto-requisition AIR %2 role=%3 (cp %4): %5", _callsign, _x, _role, round _cp, _r # 1]] call NeroAI_fnc_log;
        };
        _why pushBack format ["%1: %2", _x, _r # 1];
    } forEach _kinds;
    if !(_why isEqualTo []) then {
        private _msg=_why joinString " | ";
        if !(_msg isEqualTo (_group getVariable ["NeroWL_lastAirRefusal",""])) then {
            _group setVariable ["NeroWL_lastAirRefusal",_msg];
            ["WARN", format ["%1 air requisition role=%2 cp %3 refused — %4", _callsign, _role, round _cp, _msg]] call NeroAI_fnc_log;
        };
    };
};

private _canBuyInitial = (_ownAll isEqualTo []) && {_onFoot};
/* 8.10 live 7.10: native Warlords buys AI commanders tanks / ZSU (3-4 seats),
 * "места назначены 3 из 10" — six men walked 15 km beside their tank and the
 * squad never bought anything again. A partly mounted squad with a walking
 * tail and no free seat buys one carrier (max 2 vehicles, 90 s cooldown). */
private _canBuyTail = (_vState isEqualTo "PARTIAL_MOUNTED") && {(count _pedestrians) >= 2} && {(count _aliveOwn) < _maxVehicles} && {_boardable isEqualTo []};

/* D) A squad on foot without its own vehicle whose native objective is far
 * takes a ready side transport helicopter (real boarding and flight in
 * fn_airTransport) before spending CP on a ground vehicle. Never into the
 * protected bubble of an enemy base; one attempt per 120 s. */
if (_canBuyInitial && {missionNamespace getVariable ["NeroAI_airEnabled",true]} && {(_now - (_group getVariable ["NeroWL_lastLiftTry",-1e6])) > 120}) then {
    private _objective=missionNamespace getVariable [format ["BIS_WL_currentSector_%1",side _group],objNull];
    if (!isNull _objective && {(_leader distance2D _objective) > 2500}) then {
        private _enemyBases=[missionNamespace getVariable ["BIS_WL_base_EAST",objNull],missionNamespace getVariable ["BIS_WL_base_WEST",objNull]] select {!isNull _x && {!((_x getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo side _group)}};
        if ((_enemyBases findIf {_objective distance2D _x < (missionNamespace getVariable ["NeroAI_airEnemyBaseNoFlyMeters",1400])}) >= 0) exitWith {};
        _group setVariable ["NeroWL_lastLiftTry",_now];
        private _r=[_group,getPosATL _objective] call NeroAI_fnc_airTransport;
        if (_r # 0) then {
            ["INFO", format ["%1 air lift to %2 (%3 m): %4", _callsign, _objective getVariable ["BIS_WL_sectorName",str _objective], round (_leader distance2D _objective), _r # 1]] call NeroAI_fnc_log;
        };
    };
};
if (_group getVariable ["NeroWL_transportActive",false]) exitWith {};

if (!_canBuyInitial && {!_canBuyTail}) exitWith {};
if ((_now - (_group getVariable ["NeroAI_lastAutoBuyTry", -1e6])) < _cooldown) exitWith {};

if (_wl isEqualTo []) exitWith {};
private _cp = (_wl # 0) getVariable ["BIS_WL_funds", 0];
if !(_cp isEqualType 0) exitWith {};
if (_cp < _minCP) exitWith {};
_group setVariable ["NeroAI_lastAutoBuyTry", _now, true];
private _order = if (_canBuyTail) then {
    ["APC", "CAR"]
} else {
    /* 4.5.1 T20: prioritize APC for squads >= 4 when enemy has AT, otherwise TANK when enemy has no AT */
    private _mySide = side _group;
    private _shared = (missionNamespace getVariable ["NeroAI_sharedIntel", createHashMap]) getOrDefault [str _mySide, []];
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

    /* 7.10: a squad of 5+ needs seats — a 4-seat tank left six men walking and
     * the crew was abandoned by the native stuck check. APC first for it;
     * small squads (crews, recon) still take a tank when no AT is known. */
    if ((count _living) >= 5) then {
        ["APC", "TANK", "CAR"]
    } else {
        if (_enemyAT == 0) then {["TANK", "APC", "CAR"]} else {["APC", "TANK", "CAR"]}
    }
};
private _bought = false;
private _whyNot = [];
{
    private _r = [_group, _x, "AUTONOMY"] call NeroAI_fnc_purchaseAsset;
    if !(_r # 0) then { _whyNot pushBack format ["%1: %2", _x, _r # 1]; };
    if (_r # 0) exitWith {
        _bought = true;
        ["INFO", format ["%1 auto-requisition %2 (cp %3): %4", _callsign, _x, round _cp, _r # 1]] call NeroAI_fnc_log;
        [leader _group, format ["%1: заказываю %2 по реквизиции. Заказ принят, ждём подтверждения доставки.", _callsign, switch (_x) do { case "APC": {"бронетранспортёр"}; case "TANK": {"танк"}; default {"машину"} }], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
        _group setVariable ["NeroAI_forcePlan", true, true];
    };
    /* the purchase cooldown itself refused → stop trying this tick */
    if ((_r # 1) find "повтор позже" >= 0) exitWith {};
} forEach _order;
/* The catalogue is not there yet in the first seconds (vanilla assigns
 * BIS_WL_purchasable after its own init) — that is not worth a warning. */
private _catalogueMissing = (_whyNot findIf {(_x find "каталог реквизиции пуст") >= 0}) >= 0;
/* 8.10: log every CHANGE of the refusal reason (was: once per group, so a
 * whole session of silent refusals could not be diagnosed). */
private _whyMsg = _whyNot joinString " | ";
if (!_bought && {!_catalogueMissing} && {!(_whyMsg isEqualTo (_group getVariable ["NeroWL_lastGroundRefusal", ""]))}) then {
    _group setVariable ["NeroWL_lastGroundRefusal", _whyMsg];
    ["WARN", format ["%1 auto-requisition (%2): nothing bought with cp %3 — %4", _callsign, if (_canBuyTail) then {"tail"} else {"initial"}, round _cp, _whyMsg]] call NeroAI_fnc_log;
};
