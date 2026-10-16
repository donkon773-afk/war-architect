if (!hasInterface) exitWith {};

[] spawn {
    waitUntil {!isNull player};
    [player] call NeroAI_fnc_installPlayerActions;
    [] call NeroAI_fnc_visionCaptureLoop;
};

addMissionEventHandler ["EntityRespawned", {
    params ["_newEntity", "_oldEntity"];
    if (hasInterface && {_newEntity isEqualTo player}) then {
        /* EntityRespawned fires after the old variable namespace is copied.
           addAction entries are not copied, so clear the stale installation
           guard before rebuilding the actions on the new player object. */
        _newEntity setVariable ["NeroAI_actionsInstalled", false];
        [_newEntity] call NeroAI_fnc_installPlayerActions;
        /* The server accepts this only from the owner of the respawned player
           and only when it already holds a pre-death UID snapshot. */
        [_newEntity] remoteExecCall ["NeroAI_fnc_restorePlayerAuthority", 2];
    };
}];

addMissionEventHandler ["HandleChatMessage", {
    _this call NeroAI_fnc_handleChat;
}];
