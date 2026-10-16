if (getNumber (missionConfigFile >> "NeroWL_customCatalog") == 1) exitWith {};
/* Archive presets are data, not executable instructions. Match native category
 * order and validate scope, side, services and cost before showing any row. */
[] spawn {
    waitUntil {sleep 2; !isNil "BIS_WL_scenarioServices" && {!isNil "BIS_WL_allWarlords"}};
    private _preset = getText (missionConfigFile >> "NeroWL_archivePreset");
    private _rows = [];
    {
        private _side = _x;
        {
            _x params ["_category","_index"];
            {
                private _class = configName _x;
                private _cfg = configFile >> "CfgVehicles" >> _class;
                private _cost = getNumber (_x >> "cost");
                private _requirements = getArray (_x >> "requirements");
                if (isClass _cfg && {getNumber (_cfg >> "scope") == 2} && {_cost > 0} &&
                    {_category != "Aircraft" || {missionNamespace getVariable ["NeroAI_airEnabled",true]}} &&
                    {getNumber (_cfg >> "side") == ([east,west] find _side)} &&
                    {(_requirements findIf {!(_x in BIS_WL_scenarioServices)}) < 0}) then {
                    private _floor = switch (_category) do {
                        case "Infantry": {60};
                        case "Aircraft": {if (_class isKindOf "Plane") then {6000} else {3000}};
                        case "Vehicles": {if (_class isKindOf "Wheeled_APC_F" || {_class isKindOf "Tracked_APC_F"}) then {1800} else {if (_class isKindOf "Tank") then {3200} else {400}}};
                        default {300};
                    };
                    private _row = [_class,_cost max _floor,_requirements,getText (_cfg >> "displayName"),getText (_cfg >> "editorPreview"),"RHS: paid CP requisition",_category];
                    if (_category == "Defences") then {_row pushBack (getArray (_x >> "offset"));};
                    _rows pushBack [_side,_index,_row];
                };
            } forEach ("true" configClasses (missionConfigFile >> "CfgWLRequisitionPresets" >> _preset >> str _side >> _category));
        } forEach [["Infantry",0],["Vehicles",1],["Defences",3],["Aircraft",4],["Naval",5]];
    } forEach [west,east];
    diag_log format ["[NeroWL] archive preset %1: %2 validated rows",_preset,count _rows];
    private _apply = {
        params ["_catalog","_side"];
        if (count _catalog < 6) exitWith {};
        // RHS commanders must recruit RHS infantry, including native AI purchases.
        private _infantry = (_rows select {(_x # 0) isEqualTo _side && {(_x # 1) == 0}}) apply {+(_x # 2)};
        if !(_infantry isEqualTo []) then {_catalog set [0,_infantry];};
        {
            if ((_x # 0) isEqualTo _side) then {
                private _bucket = _catalog # (_x # 1);
                private _row = _x # 2;
                private _i = _bucket findIf {toLower (_x # 0) == toLower (_row # 0)};
                if (_i < 0) then {_bucket pushBack (+_row);} else {_bucket set [_i,+_row];};
            };
        } forEach _rows;
    };
    while {true} do {
        if (isServer) then {
            {
                private _name = format ["BIS_WL_purchasable%1",_x];
                private _catalog = missionNamespace getVariable [_name,[]];
                [_catalog,_x] call _apply;
                missionNamespace setVariable [_name,_catalog];
            } forEach [west,east];
            {
                private _catalog = _x getVariable ["BIS_WL_purchasable",[]];
                [_catalog,side group _x] call _apply;
                _x setVariable ["BIS_WL_purchasable",_catalog];
            } forEach (BIS_WL_allWarlords select {!isNull _x && {!isPlayer _x}});
        };
        if (hasInterface && {!isNull player}) then {
            private _catalog = player getVariable ["BIS_WL_purchasable",[]];
            [_catalog,side group player] call _apply;
            player setVariable ["BIS_WL_purchasable",_catalog];
        };
        sleep 20;
    };
};
