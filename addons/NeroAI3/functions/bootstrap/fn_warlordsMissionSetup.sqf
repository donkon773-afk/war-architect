/* Opt-in personal scenarios only. Bots and Zeus are mission features, never
 * enabled globally in arbitrary multiplayer missions. */
if (!isServer || {getNumber (missionConfigFile >> "NeroWL_personalScenario") != 1}) exitWith {};
[] spawn {
    waitUntil {sleep 2; !isNil "BIS_WL_allWarlords" && {!isNil "BIS_WL_base_EAST"} && {!isNil "BIS_WL_base_WEST"} &&
        {count (missionNamespace getVariable ["BIS_WL_purchasableEAST",[]]) >= 5}};
    sleep 10;
    {
        private _side = _x;
        private _bots = BIS_WL_allWarlords select {!isPlayer _x && {alive _x} && {side group _x isEqualTo _side}};
        // If the host disabled lobby AI, add ten RHS AI commanders per side
        // once. No unlimited fallback spawning and no garrison/air freebies.
        if (_bots isEqualTo []) then {
            private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",_side],objNull];
            if (!isNull _base) then {
                for "_i" from 0 to 9 do {
                    private _group = createGroup [_side,true];
                    private _class = if (_side isEqualTo east) then {"rhs_msv_emr_sergeant"} else {"rhsusf_army_ocp_squadleader"};
                    private _pos = (getPosATL _base) findEmptyPosition [15,150,_class];
                    if !(_pos isEqualTo []) then {
                        private _bot = _group createUnit [_class,_pos,[],0,"NONE"];
                        _bot setVariable ["BIS_WL_selectedSector",objNull];
                        _bot setVariable ["BIS_WL_funds",missionNamespace getVariable ["BIS_WL_startCP",1500],true];
                        _bot setVariable ["BIS_WL_funds_backup",_bot getVariable ["BIS_WL_funds",1500]];
                        _bot setVariable ["BIS_WL_purchasable",missionNamespace getVariable [format ["BIS_WL_purchasable%1",_side],[]]];
                        _bot setVariable ["BIS_WL_pointer",_bot,true];
                        _bot setVariable ["BIS_WL_purchased",[],true];
                        _bot setVariable ["NeroWL_fallbackCommander",true,true];
                        _group setVariable ["BIS_WL_groupVehs",[],true];
                        BIS_WL_allWarlords pushBackUnique _bot;
                        _bot allowFleeing 0;
                        _bot setVariable ["BIS_WL_AIHandle",_bot call BIS_fnc_WLAICore];
                        _bots pushBack _bot;
                    } else {deleteGroup _group;};
                };
            };
        };
        { _x enableAI "ALL"; } forEach _bots;
        diag_log format ["[NeroWL] start bots %1=%2; lobby disabledAI=%3",_side,count _bots,getNumber (missionConfigFile >> "disabledAI")];
    } forEach [east,west];
    publicVariable "BIS_WL_allWarlords";
};
addMissionEventHandler ["EntityCreated",{
    params ["_object"];
    if !(_object isKindOf "Logic") then {{_x addCuratorEditableObjects [[_object],true];} forEach allCurators;};
}];
[] spawn {
    private _curator = objNull;
    // Build Zeus catalogs after native Warlords initialization, not alongside
    // its host-side inventory scan. Keep the loading screen responsive.
    waitUntil {sleep 1; count (missionNamespace getVariable ["BIS_WL_sectors",[]]) >= 3 && {!isNull (missionNamespace getVariable ["BIS_WL_base_WEST",objNull])} && {!isNull (missionNamespace getVariable ["BIS_WL_base_EAST",objNull])}};
    while {true} do {
        // This is the local host, regardless of slot/faction/profile/respawn.
        // Dedicated servers keep their own mission admin/UID Zeus implementation.
        if (hasInterface && {!isNull player} && {alive player}) then {
            if (isNull _curator) then {
                private _group = createGroup [sideLogic,true];
                _curator = _group createUnit ["ModuleCurator_F",[0,0,0],[],0,"NONE"];
                _curator setVariable ["Owner","",true];
                _curator setVariable ["Addons",3,true];
                _curator addCuratorAddons activatedAddons;
                removeAllCuratorEditingAreas _curator;
                removeAllCuratorCameraAreas _curator;
                _curator setCuratorWaypointCost 0;
                _curator addEventHandler ["CuratorObjectRegistered",{params ["_curator","_classes"];_classes apply {[true,0,0]}}];
                _curator addCuratorEditableObjects [((allMissionObjects "All") select {!(_x isKindOf "Logic")}),true];
                {_curator setCuratorCoef [_x,0];} forEach ["place","edit","delete","destroy","group","synchronize"];
            };
            if (isNull getAssignedCuratorLogic player) then {
                unassignCurator _curator;
                player assignCurator _curator;
            };
            // Configure the curator actually assigned to the host. Another
            // mission/module may have assigned a different logic already.
            private _active = getAssignedCuratorLogic player;
            if (!isNull _active) then {
                if !(_active getVariable ["NeroWL_attributeHandlers",false]) then {
                    // Dynamic modules may lack the native module's local UI
                    // handlers. Preserve ZEN handlers; a dialog opened by an
                    // earlier handler must not be opened a second time.
                    {
                        _active addEventHandler [_x,{
                            if (hasInterface && {!dialog}) then {
                                private _opened=(_this # 1) call BIS_fnc_showCuratorAttributes;
                                diag_log format ["[NeroWL Zeus] attributes opened=%1 target=%2",_opened,_this # 1];
                            };
                        }];
                    } forEach ["CuratorObjectDoubleClicked","CuratorGroupDoubleClicked","CuratorWaypointDoubleClicked","CuratorMarkerDoubleClicked"];
                    {_active setVariable ["BIS_fnc_curatorAttributes"+_x,["%ALL"]];} forEach ["object","group","waypoint","marker"];
                    {_active setCuratorCoef [_x,0];} forEach ["place","edit","delete","destroy","group","synchronize"];
                    removeAllCuratorEditingAreas _active;
                    removeAllCuratorCameraAreas _active;
                    _active setVariable ["NeroWL_attributeHandlers",true];
                    diag_log format ["[NeroWL Zeus] host attribute handlers ready: %1",_active];
                };
                _active addCuratorEditableObjects [allUnits + vehicles,true];
            };
        };
        sleep 20;
    };
};
