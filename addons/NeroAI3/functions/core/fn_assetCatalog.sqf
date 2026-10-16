/* NeroAI 4.4.0 [Command]: mod-tolerant class resolution.
 *
 * The player's load order changes between sessions (CUP, RHS, standalone packs).
 * Hardcoding a class name means a silent spawn failure whenever that mod is off.
 * So every role is a PRIORITY LIST of candidate classes: the first one that
 * actually exists in CfgVehicles wins, and an unresolved role is logged loudly
 * and skipped rather than crashing the spawn pass.
 *
 * Usage: ["JET_CAS", "BLUE"] call NeroAI_fnc_assetCatalog  ->  "" or a class.
 * Side keys: "BLUE" (coalition), "RED" (Takistani regular army), "GREEN"
 * (partisans / militia). */
params [["_role", ""], ["_sideKey", "BLUE"]];
_role = toUpper _role;
_sideKey = toUpper _sideKey;

private _cache = missionNamespace getVariable ["NeroAI_assetCache", createHashMap];
private _key = format ["%1|%2", _sideKey, _role];
private _hit = _cache getOrDefault [_key, "??"];
if !(_hit isEqualTo "??") exitWith {_hit};

private _blue = switch (_role) do {
    case "UAV_ARMED": {["CUP_B_MQ9_USA", "RHS_MQ9", "rhsusf_mq9", "B_UAV_02_CAS_F", "B_UAV_02_F"]};
    case "UAV_RECON": {["CUP_B_MQ9_USA", "B_UAV_01_F", "B_UAV_02_F"]};
    case "MORTAR": {["CUP_B_M252_US", "rhsusf_m252", "B_Mortar_01_F"]};
    case "JET_CAS": {["CUP_B_A10_DYN_USA", "CUP_B_A10_CAS_USA", "RHS_A10", "B_Plane_CAS_01_dynamicLoadout_F", "B_Plane_CAS_01_F"]};
    /* F-22 specifically requested; RHS carries it, CUP does not, so vanilla
     * F/A-18 or the Apex fighter are the fallback rather than a second F-22 mod. */
    case "JET_FIGHTER": {["rhsusf_f22", "JS_JC_FA18E", "CUP_B_F35B_USMC", "B_Plane_Fighter_01_F"]};
    case "HELI_ATTACK": {["CUP_B_AH64D_USA", "RHS_AH64D", "rhsusf_AH64D", "B_Heli_Attack_01_dynamicLoadout_F", "B_Heli_Attack_01_F"]};
    /* 4.4.0 multirole: F-16 and F-4 Phantom (mod packs), vanilla fighters as fallback. */
    case "JET_MULTI_A": {["FIR_F16C_Blk50", "FIR_F16C", "USAF_F16C", "usaf_f16c", "B_Plane_Fighter_01_F"]};
    case "JET_MULTI_B": {["FIR_F4E", "FIR_F4E_USAF", "sab_F4E_USAF", "usaf_f4e", "B_Plane_CAS_01_F"]};
    /* 4.4.0: two more rotary airframes — a transport and a second gunship. */
    case "HELI_TRANSPORT": {["RHS_UH60M", "CUP_B_UH60M_US", "CUP_B_UH60M_Unarmed_US", "B_Heli_Transport_01_F"]};
    case "HELI_ATTACK_2": {["RHS_AH1Z", "CUP_B_AH1Z_Dynamic_USMC", "CUP_B_AH1Z_USMC", "B_Heli_Light_01_dynamicLoadout_F"]};
    case "TRUCK_AMMO": {["CUP_B_MTVR_Ammo_USMC", "rhsusf_M977A4_AMMO_usarmy_wd", "B_Truck_01_ammo_F"]};
    case "TRUCK_FUEL": {["CUP_B_MTVR_Refuel_USMC", "rhsusf_M978A4_usarmy_wd", "B_Truck_01_fuel_F"]};
    case "TRUCK_REPAIR": {["CUP_B_MTVR_Repair_USMC", "rhsusf_M977A4_REPAIR_usarmy_wd", "B_Truck_01_Repair_F"]};
    /* BLUE's fixed base armour: LAV-25 / Bradley / Abrams, any modification.
     * Vanilla has no true equivalent, so the Apex analogues (Rhino, Cheetah's
     * IFV cousin, Slammer) are the last resort rather than an unresolved role. */
    case "APC_LAV25": {["rhsusf_lav25_usmc", "CUP_B_LAV25_USMC", "B_APC_Wheeled_01_cannon_F"]};
    case "IFV_BRADLEY": {["rhs_M2A3_BUSKIII_usarmy", "rhs_M2A2_usarmy", "CUP_B_M2A3_BUSK_USA", "CUP_B_M2A2_ODS_USA", "B_APC_Tracked_01_CRV_F"]};
    case "TANK_ABRAMS": {["rhsusf_M1A2_TUSK_wd", "rhsusf_M1A1_FEP_wd", "CUP_B_M1A2_USA", "CUP_B_M1A1_TUSK_USA", "B_MBT_01_cannon_F"]};
    default {[]};
};

private _red = switch (_role) do {
    /* Armed first, deliberately. The Pchela-1T is a pure recon airframe with no
     * weapons at all, so it must never fill the strike slot — RED fields the
     * armed Ababil-3 as its answer to the coalition MQ-9. */
    case "UAV_ARMED": {["O_UAV_02_CAS_F", "O_UAV_02_dynamicLoadout_F", "CUP_O_MQ9_TKA", "RHS_MQ9", "O_UAV_02_F"]};
    case "UAV_RECON": {["CUP_O_Pchela1T_RU", "RHS_Pchela1T_vvs", "O_UAV_01_F", "O_UAV_02_F"]};
    case "MORTAR": {["CUP_O_2b14_82mm_TKA", "CUP_O_2b14_82mm_RU", "rhs_2b14_82mm_msv", "O_Mortar_01_F"]};
    case "JET_CAS": {["CUP_O_Su25_TKA", "CUP_O_Su25_RU", "rhs_su25sm_vvsc", "O_Plane_CAS_02_dynamicLoadout_F", "O_Plane_CAS_02_F"]};
    /* MiG-29 specifically requested; RHS's -29S is prioritised over the MiG-21
     * and Su-35 that used to lead this list. */
    case "JET_FIGHTER": {["rhs_mig29s_vvsc", "rhs_mig29_vpvo", "CUP_O_MiG21_TKA", "SU35_base_F", "O_Plane_Fighter_02_F"]};
    case "HELI_ATTACK": {["CUP_O_Mi24_D_TK", "CUP_O_Mi24_V_RU", "rhs_mi24p_vvs", "O_Heli_Attack_02_dynamicLoadout_F", "O_Heli_Attack_02_F"]};
    /* 4.4.0 multirole: Su-34 (CUP) and T-50/PAK-FA (mods; vanilla Shikra is a T-50 lookalike). */
    case "JET_MULTI_A": {["CUP_O_Su34_RU", "CUP_O_SU34_RU", "rhs_su34_vvs", "O_Plane_CAS_02_dynamicLoadout_F"]};
    case "JET_MULTI_B": {["RHS_T50_vvs", "rhs_t50_vvs", "T50_base", "sab_su57", "O_Plane_Fighter_02_F"]};
    case "HELI_TRANSPORT": {["RHS_Mi8mt_vvs", "RHS_Mi8MTV3_vvs", "CUP_O_Mi8_TK", "CUP_O_Mi8_RU", "O_Heli_Light_02_F"]};
    case "HELI_ATTACK_2": {["RHS_Ka52_vvs", "CUP_O_Ka52_RU", "RHS_Mi28N_vvs", "O_Heli_Attack_02_F"]};
    case "TRUCK_AMMO": {["CUP_O_Ural_Reammo_TKA", "rhs_gaz66_ammo_msv", "O_Truck_02_ammo_F"]};
    case "TRUCK_FUEL": {["CUP_O_Ural_Refuel_TKA", "rhs_gaz66_ammo_msv", "O_Truck_02_fuel_F"]};
    case "TRUCK_REPAIR": {["CUP_O_Ural_Repair_TKA", "rhs_gaz66_repair_msv", "O_Truck_02_box_F"]};
    /* RED's fixed base armour: BTR-80A, BMP-2, T-72BV (or a close modification)
     * — a standardised regular-army loadout, distinct from GREEN's scavenged
     * mixed park below. */
    case "APC_BTR80A": {["CUP_O_BTR80A_RU", "rhs_btr80a_msv", "CUP_O_BTR80_TK", "O_APC_Wheeled_02_rcws_F"]};
    case "IFV_BMP2": {["CUP_O_BMP2_TKA", "CUP_O_BMP2_TK", "rhs_bmp2k_msv", "O_APC_Tracked_02_cannon_F"]};
    case "TANK_T72BV": {["rhs_t72b3_tv", "CUP_O_T72_TKA", "rhs_t72a_msv", "O_MBT_02_cannon_F"]};
    /* Legacy roles kept for the RED base-armour rework's fallback path. */
    case "TANK_MAIN": {["CUP_O_T72_TKA", "rhs_t72b3_tv", "CUP_O_T55_TK", "O_MBT_02_cannon_F"]};
    case "APC_BTR60": {["CUP_O_BTR60_TK", "CUP_O_BTR60_RU", "O_APC_Wheeled_02_rcws_F"]};
    case "IFV_BMP1": {["CUP_O_BMP1_TKA", "CUP_O_BMP1_TK", "rhs_bmp1_msv", "O_APC_Tracked_02_cannon_F"]};
    default {[]};
};

/* GREEN's scavenged park, deliberately older/mixed and distinct from RED's
 * and BLUE's standardised base armour: T-55, T-34, BTR-60, BRDM-2, BMP-1. */
private _green = switch (_role) do {
    case "TANK_MAIN": {["CUP_I_T55_TKG", "CUP_O_T55_TK", "CUP_B_T55_CDF", "O_MBT_02_cannon_F"]};
    case "TANK_LEGACY": {["CUP_O_T34_TKA", "CUP_I_T34_NAPA", "CUP_O_T55_TK"]};
    case "APC_BTR60": {["CUP_I_BTR60_TK_GUE", "CUP_O_BTR60_TK", "CUP_O_BTR60_RU"]};
    /* Live incident: none of the first four resolved in this load order
     * (logged "unresolved"), so GREEN silently lost this role entirely —
     * widened the candidate list and added a generic wheeled fallback so the
     * role degrades to a plausible substitute instead of vanishing. */
    case "APC_BRDM2": {["CUP_I_BRDM2_TKG", "CUP_O_BRDM2_TK", "CUP_O_BRDM2_TKA", "CUP_O_BRDM2_HQ_RU", "rhs_brdm2_msv", "rhs_brdm2a_msv", "O_APC_Wheeled_02_rcws_F"]};
    case "IFV_BMP1": {["CUP_I_BMP1_TKG", "CUP_O_BMP1_TKA", "CUP_O_BMP1_TK", "rhs_bmp1_msv"]};
    case "UAV_RECON": {["I_UAV_01_F", "B_UAV_01_F", "O_UAV_01_F"]};
    case "MORTAR": {["CUP_I_2b14_82mm_TK_INS", "CUP_O_2b14_82mm_TKA", "I_Mortar_01_F", "O_Mortar_01_F"]};
    default {[]};
};

private _candidates = switch (_sideKey) do {
    case "RED": {_red};
    case "GREEN": {_green};
    default {_blue};
};

/* A strike role must actually be able to shoot. Recon airframes (Pchela-1T,
 * Darter) carry nothing, and quietly resolving one into an armed slot is how a
 * side ends up with a "gunship" that can only watch. Weapons live either on the
 * hull, on a turret, or — for dynamic-loadout aircraft — on pylons. */
private _fnc_hasWeapon = {
    params ["_class"];
    private _cfg = configFile >> "CfgVehicles" >> _class;
    if (isClass (_cfg >> "Components" >> "TransportPylonsComponent")) exitWith {true};
    private _real = { (count (_this select {!((toLower _x) in ["", "cmflauncher", "sensorsmanager", "trueheadlights"])})) > 0 };
    if ((getArray (_cfg >> "weapons")) call _real) exitWith {true};
    private _armed = false;
    {
        if ((getArray (_x >> "weapons")) call _real) exitWith { _armed = true; };
    } forEach ("true" configClasses (_cfg >> "Turrets"));
    _armed
};

private _mustShoot = _role in ["UAV_ARMED", "JET_CAS", "JET_FIGHTER", "JET_MULTI_A", "JET_MULTI_B", "HELI_ATTACK", "HELI_ATTACK_2"];
private _existing = _candidates select {isClass (configFile >> "CfgVehicles" >> _x)};

private _resolved = "";
if (_mustShoot) then {
    private _armedOnes = _existing select {[_x] call _fnc_hasWeapon};
    if !(_armedOnes isEqualTo []) then {
        _resolved = _armedOnes # 0;
    } else {
        if !(_existing isEqualTo []) then {
            _resolved = _existing # 0;
            ["WARN", format ["Asset role %1/%2 filled by %3, which config says carries no weapon — check the class list.", _sideKey, _role, _resolved]] call NeroAI_fnc_log;
        };
    };
} else {
    if !(_existing isEqualTo []) then { _resolved = _existing # 0; };
};

if (_resolved isEqualTo "" && {!(_candidates isEqualTo [])}) then {
    ["WARN", format ["Asset role %1/%2 unresolved; none of %3 exist in this load order.", _sideKey, _role, _candidates]] call NeroAI_fnc_log;
};

_cache set [_key, _resolved];
missionNamespace setVariable ["NeroAI_assetCache", _cache];
_resolved
