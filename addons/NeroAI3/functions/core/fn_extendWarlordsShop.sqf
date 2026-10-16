if (getNumber (missionConfigFile >> "NeroWL_customCatalog") == 1) exitWith {};
/* Native Warlords category order: Infantry, Vehicles, Gear, Defences, Aircraft,
 * Naval, Gear_custom, Services. Add a small verified subset, never missing classes.
 * Runs locally for the player's UI and on the server for AI purses. */
if (missionNamespace getVariable ["NeroWL_shopWorker", false]) exitWith {};
missionNamespace setVariable ["NeroWL_shopWorker", true];
[] spawn {
    waitUntil {sleep 2; !isNil "BIS_WL_allWarlords" && {!isNil "BIS_WL_sectors"}};
    if (getNumber (missionConfigFile >> "NeroWL_modShopEnabled") != 1) exitWith {};
    private _rows = [];
    {
        private _cfg = configFile >> "CfgVehicles" >> (_x # 0);
        if (isClass _cfg && {getNumber (_cfg >> "scope") == 2} && {getNumber (_cfg >> "side") in [0,1]}) then {
            private _side = [east,west] # (getNumber (_cfg >> "side"));
            private _category = if ((_x # 2) == 4) then {"Aircraft"} else {"Vehicles"};
            _rows pushBack [_side, _x # 2, [_x # 0,_x # 1,_x # 3,getText (_cfg >> "displayName"),getText (_cfg >> "editorPreview"),"NeroAI: CP requisition; no free replacement",_category]];
        };
    } forEach [
        ["rhsusf_M1A2_TUSK_wd",4200,1,[]], ["rhsusf_M1A1_FEP_wd",3400,1,[]],
        ["rhs_m2a3_buskiii",2600,1,[]], ["rhsusf_M1126_M2_wd",1800,1,[]],
        ["rhs_t72bb_tv",3200,1,[]], ["rhs_t90_tv",4400,1,[]],
        ["rhs_bmp2_msv",2200,1,[]], ["rhs_btr80a_msv",1800,1,[]], ["rhs_zsu234_aa",2600,1,[]],
        ["CUP_B_M1A2_USA",4200,1,[]], ["CUP_B_M2A3_BUSK_USA",2600,1,[]], ["CUP_B_LAV25_USMC",2200,1,[]],
        ["CUP_O_T72_RU",3200,1,[]], ["CUP_O_BMP2_RU",2200,1,[]], ["CUP_O_BTR80A_RU",1800,1,[]],
        ["RHS_AH64D",5000,4,["H"]], ["RHS_AH1Z",4500,4,["H"]], ["RHS_UH60M",3000,4,["H"]],
        ["rhs_mi24v_vdv",4500,4,["H"]], ["rhs_mi28n_vvs",5200,4,["H"]],
        ["CUP_B_AH64D_USA",5000,4,["H"]], ["CUP_O_Mi24_V_RU",4500,4,["H"]],
        ["RHS_A10",6500,4,["A"]], ["rhsusf_f22",8500,4,["A"]], ["JS_JC_FA18E",7500,4,["A"]],
        ["RHS_Su25SM_vvs",6000,4,["A"]], ["JS_JC_SU35",7500,4,["A"]],
        ["CUP_B_A10_DYN_USA",6500,4,["A"]], ["CUP_O_Su25_Dyn_RU",6000,4,["A"]],
        ["CUP_B_MQ9_USA",4000,4,["A"]]
    ];
    diag_log format ["[NeroWL] validated mod shop: %1 public RHS/CUP/FA18/SU35 classes", count _rows];
    private _extend = {
        params ["_catalog","_side"];
        private _changed = false;
        if !(_catalog isEqualType [] && {count _catalog >= 5}) exitWith {false};
        {
            if ((_x # 0) isEqualTo _side && {(_x # 1) != 4 || {missionNamespace getVariable ["NeroAI_airEnabled",true]}}) then {
                private _bucket = _catalog # (_x # 1);
                private _row = _x # 2;
                // Let native Warlords enforce the service at the destination too.
                if ((_bucket findIf {(_x # 0) isEqualTo (_row # 0)}) < 0) then {_bucket pushBack (+_row); _changed = true;};
            };
        } forEach _rows;
        _changed
    };
    while {true} do {
        if (isServer) then {
            {
                private _name = format ["BIS_WL_purchasable%1",_x];
                private _catalog = missionNamespace getVariable [_name,[]];
                if ([_catalog,_x] call _extend) then {missionNamespace setVariable [_name,_catalog];};
            } forEach [west,east];
            {
                private _catalog = _x getVariable ["BIS_WL_purchasable",[]];
                if ([_catalog,side group _x] call _extend) then {_x setVariable ["BIS_WL_purchasable",_catalog];};
            } forEach (BIS_WL_allWarlords select {!isNull _x && {!isPlayer _x}});
        };
        if (hasInterface && {!isNull player}) then {
            private _catalog = player getVariable ["BIS_WL_purchasable",[]];
            if ([_catalog,side group player] call _extend) then {player setVariable ["BIS_WL_purchasable",_catalog];};
        };
        sleep 15;
    };
};
