// playable AI units keep loadouts

if (isServer) then {
  addMissionEventHandler ["entityKilled", { 
    params ["_unit"]; 
    if (isNil {_unit getVariable "loadout"} && !isPlayer _unit) then {
      _unit setVariable ["loadout", getUnitLoadout _unit]
    };
  }];
  addMissionEventHandler ["entityRespawned", { 
    params ["_unit"];
    _unit setUnitLoadout (_unit getVariable "loadout")
  }]
};


//// variables

marker_number=1;

specop_list= [];
lowSkill_list= [];

artillery_list= [];
artillery_list= ["CUP_B_M270_HE_USA", "CUP_B_M270_DPICM_USA", "CUP_B_M1129_MC_MK19_Desert", "CUP_B_M252_US", "CUP_B_M119_US", "CUP_O_Hilux_UB32_TK_INS", "CUP_O_BM21_TKA", "CUP_O_Hilux_podnos_TK_INS", "CUP_O_2b14_82mm_TK_INS", "CUP_O_D30_TK"];


//INIT warlords
["CAManBase", "InitPost", {nul = [_this # 0] execVM "unitsInit.sqf"}] call CBA_fnc_addClassEventHandler;

["AllVehicles", "Fired", {nul = [_this # 0] execVM "artilleryRadar.sqf"}] call CBA_fnc_addClassEventHandler;


//["AllVehicles", "Fired", {systemChat str _this}] call CBA_fnc_addClassEventHandler;
