/* 11.10 Tactical AI without LLM — PURE squad decision (utility rules).
 * The planner (fn_rulesGroupPlan) collects the facts from the engine and turns
 * the decision into whitelisted macro actions; this file only decides, so the
 * SQF-VM tests run the production logic itself.
 *
 *   _facts call NeroAI_fnc_rulesChooseBehaviour -> [decision, reason, extras]
 *
 * facts (positional):
 *  0 mission  "ATTACK" | "DEFEND" | "RESERVE" | "GARRISON" | "NONE"
 *  1 alive            2 initial          3 contacts (hostiles ≤ 600 m)
 *  4 nearestContact m 5 armourNear (enemy armour ≤ 900 m)
 *  6 antiTank (launchers in the squad)   7 armedVehicles (own, can fire)
 *  8 ambush (fresh close ambush)         9 distTarget m (-1 = none)
 * 10 targetRadius m  11 phase "" | "APPROACH" | "STAGE" | "ASSAULT"
 * 12 stageWait s     13 readyPartners (attack squads at this objective, self included)
 * 14 neededPartners  15 fireReady (side mortar/artillery ready)
 * 16 cluster (hostiles in the densest known cluster) 17 clusterDist m
 * 18 posture 0..2    19 enemiesInTarget (known hostiles at the objective)
 * 20 canBuyInfantry  21 contactsInTarget (hostiles inside the defended sector)
 *
 * decisions: BREAK, COUNTER, ADVANCE, STAGE, ASSAULT, DEFEND_MOVE, DEFEND,
 *            RESERVE, IDLE
 * extras:    FIRE, RECON, REQUEST_SUPPORT, BUY_INFANTRY, SHARE_INTEL */
params [
    ["_mission", "NONE", [""]], ["_alive", 0, [0]], ["_initial", 0, [0]], ["_contacts", 0, [0]],
    ["_nearestContact", 1e9, [0]], ["_armourNear", 0, [0]], ["_antiTank", 0, [0]], ["_armedVehicles", 0, [0]],
    ["_ambush", false, [false]], ["_distTarget", -1, [0]], ["_radius", 150, [0]], ["_phase", "", [""]],
    ["_stageWait", 0, [0]], ["_readyPartners", 1, [0]], ["_neededPartners", 1, [0]], ["_fireReady", false, [false]],
    ["_cluster", 0, [0]], ["_clusterDist", 1e9, [0]], ["_posture", 1, [0]], ["_enemiesInTarget", 0, [0]],
    ["_canBuyInfantry", false, [false]], ["_contactsInTarget", 0, [0]],
    ["_assaultReady",false,[false]],["_operation","",[""]],["_combatRole","ASSAULT",[""]],["_supportReached",false,[false]]
];
_posture = (round _posture) max 0 min 2;
if (count _this < 23) then {_assaultReady = ([_alive,_initial,false] call NeroAI_fnc_rulesReadiness) # 0;};
if (_alive <= 0 && {!_assaultReady}) exitWith {["IDLE", "нет боеспособных", []]};
private _ratio = if (_initial > 0) then {_alive / _initial} else {1};
private _extras = [];
/* Indirect fire only on a real cluster that is clear of the squad itself. */
private _fireOk = _fireReady && {_cluster >= 3} && {_clusterDist > 300};
/* This is ammunition suitable for the observed threat, supplied by the adapter.
 * An arbitrary armed truck or an empty launcher no longer makes AT true. */
private _hasAT = _antiTank > 0;

/* 1. Survival: shattered and outnumbered, or armour close with nothing to stop it. */
private _shattered = _ratio <= 0.4 && {_contacts > _alive};
private _armourThreat = _armourNear > 0 && {!_hasAT} && {_nearestContact < 600};
if (_shattered || _armourThreat || {_ambush && {_ratio <= 0.5}}) exitWith {
    _extras pushBack "REQUEST_SUPPORT";
    if (_fireOk) then {_extras pushBack "FIRE";};
    if (_canBuyInfantry && {_ratio <= 0.6}) then {_extras pushBack "BUY_INFANTRY";};
    ["BREAK", if (_armourThreat) then {"бронетехника противника, нечем бить"} else {"тяжёлые потери под огнём"}, _extras]
};

/* Weak groups can defend themselves; they do not start/restart CQB or HUNT.
 * Evaluate this before the continuation shortcut for an existing assault. */
if (!_assaultReady && {_contacts > 0} && {_nearestContact < 300}) exitWith {
    if (_canBuyInfantry) then {_extras pushBack "BUY_INFANTRY";};
    ["SELF_DEFEND","самооборона истощённой группы",_extras]
};
if (_mission isEqualTo "ATTACK" && {!_assaultReady}) exitWith {
    if (_canBuyInfantry) then {_extras pushBack "BUY_INFANTRY";};
    ["REGROUP","штурм запрещён: группа не готова",_extras]
};

if (_mission isEqualTo "ATTACK" && {_combatRole in ["FIRE_SUPPORT","ANTI_TANK"]}) exitWith {
    if (_fireOk) then {_extras pushBack "FIRE";};
    [if (!_supportReached && {_distTarget >= 0}) then {"SUPPORT_MOVE"} else {"FIRE_SUPPORT"},"огневая поддержка штурма",_extras]
};

/* 2. Ambush with fight left in us: turn into it. */
if (_ambush) exitWith {
    _extras pushBack "SHARE_INTEL";
    if (_fireOk) then {_extras pushBack "FIRE";};
    ["COUNTER", "засада — контратака", _extras]
};

/* 3. Enemy in front: fight it, except a defender inside its sector holds it. */
private _closeFight = _contacts > 0 && {_nearestContact < 300};
private _inDefendedSector = (_mission in ["DEFEND", "GARRISON","CONSOLIDATE"]) && {_distTarget >= 0} && {_distTarget <= _radius + 100};
if (_closeFight && {!(_phase isEqualTo "ASSAULT")} && {!_inDefendedSector}) exitWith {
    _extras pushBack "SHARE_INTEL";
    if (_fireOk) then {_extras pushBack "FIRE";};
    ["COUNTER", "ближний контакт", _extras]
};

/* 4. Mission. Plain if/else chains: the decision is the value of the block. */
private _stageReach = ((_radius + 300) min 480) + 150;
private _result = ["IDLE", "задача не назначена", []];
if (_mission isEqualTo "ATTACK") then {
    if (_distTarget < 0) then {
        _result = ["IDLE", "нет цели Warlords", []];
    } else {
        if (_ratio < 0.5 && {_canBuyInfantry}) then {_extras pushBack "BUY_INFANTRY";};
        if (_distTarget > _stageReach && {!(_phase isEqualTo "ASSAULT")}) then {
            _result = ["ADVANCE", "выдвижение на рубеж атаки", _extras];
        } else {
            if (_phase isEqualTo "ASSAULT" && {_operation in ["","ASSAULT"]}) then {
                if (_fireOk) then {_extras pushBack "FIRE";};
                _result = ["ASSAULT", "штурм продолжается", _extras];
            } else {
                private _maxWait = [150, 100, 60] # _posture;
                private _gathered = _readyPartners >= _neededPartners;
                private _go = _gathered && {_operation in ["","ASSAULT"]};
                if (_go && {_assaultReady}) then {
                    if (_fireOk && {_enemiesInTarget >= 3}) then {_extras pushBack "FIRE";};
                    _result = ["ASSAULT", "группа штурма собрана", _extras];
                } else {
                    _extras pushBack "RECON";
                    _result = ["STAGE", if (_stageWait >= _maxWait) then {"пересмотр операции: партнёры не готовы"} else {"рубеж атаки: разведка и сбор"}, _extras];
                };
            };
        };
    };
};
if (_mission in ["DEFEND","CONSOLIDATE"]) then {
    _result = if (_distTarget < 0) then {["IDLE", "нет сектора обороны", []]} else {
        if (_distTarget > (_radius * 0.6) + 150) then {["DEFEND_MOVE", "выдвижение на оборону сектора", _extras]} else {
            if (_contactsInTarget > 0) then {
                if (_fireOk) then {_extras pushBack "FIRE";};
                ["COUNTER", "противник в секторе — контратака", _extras]
            } else {["DEFEND", "оборона сектора", _extras]}
        }
    };
};
if (_mission isEqualTo "GARRISON") then {
    _result = if (_contacts > 0 && {_nearestContact < 400} && {_contactsInTarget > 0}) then {["COUNTER", "противник у гарнизона", _extras]} else {
        if (_distTarget > (_radius * 0.6) + 150) then {["DEFEND_MOVE", "возврат в свой сектор", _extras]} else {["DEFEND", "гарнизон держит сектор", _extras]}
    };
};
if (_mission isEqualTo "RESERVE") then {
    if (_canBuyInfantry && {_ratio < 0.7}) then {_extras pushBack "BUY_INFANTRY";};
    _result = if (_distTarget > 300) then {["DEFEND_MOVE", "отход в резерв", _extras]} else {["RESERVE", "резерв: пополнение и готовность", _extras]};
};
_result
