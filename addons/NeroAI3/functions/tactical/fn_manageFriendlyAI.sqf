/* NeroAI 4.4.0 [Command]: the player's own side under NeroAI automatically.
 *
 * Until now a BLUE AI squad joined NeroAI only when the player toggled it by
 * hand from the action menu. Now every fully-AI group on the player's side is
 * enrolled by this housekeeping pass, including anything spawned later
 * (Zeus, Warlords purchases, respawns). The manual toggle is kept for two
 * things only: switching a group OFF (it is then marked NeroAI_optOut and this
 * pass leaves it alone until toggled back ON), and forcing a group back ON.
 *
 * Skipped: groups with a player in them, base asset crews, opted-out groups. */
if (!isServer) exitWith {};
if (!NeroAI_transportReady || {!(missionNamespace getVariable ["NeroAI_friendlyAutoEnrollEnabled", true])}) exitWith {};

private _players = allPlayers select {alive _x};
if (_players isEqualTo []) exitWith {};
private _playerSide = side group (_players # 0);
private _cap = missionNamespace getVariable ["NeroAI_maxFriendlyGroups", 16];

private _active = 0;
{
    if (!(_y getVariable ["NeroAI_isEnemy", false]) && {(side _y) isEqualTo _playerSide}) then { _active = _active + 1; };
} forEach NeroAI_activeGroups;

private _candidates = [];
{
    private _grp = _x;
    if (
        (side _grp) isEqualTo _playerSide &&
        {!isNull (leader _grp)} && {alive (leader _grp)} &&
        {({isPlayer _x} count units _grp) isEqualTo 0} &&
        {!(_grp getVariable ["NeroAI_active", false])} &&
        {!(_grp getVariable ["NeroAI_optOut", false])} &&
        {!(_grp getVariable ["NeroWL_garrison",false])} && {!(_grp getVariable ["NeroAI_isBaseAssetCrew", false])} &&
        {!([_grp] call NeroAI_fnc_isAirCrewGroup)} &&
        {([_grp, false] call NeroAI_fnc_validateGroup)}
    ) then {
        private _d = 1e9;
        { private _dd = (leader _grp) distance _x; if (_dd < _d) then {_d = _dd;}; } forEach _players;
        _candidates pushBack [_d, _grp];
    };
} forEach allGroups;
_candidates sort true;

{
    if (_active >= _cap) exitWith {};
    _x params ["_d", "_grp"];
    private _r = [_players # 0, _grp, false] call NeroAI_fnc_registerGroup;
    if (_r # 0) then {
        _active = _active + 1;
        ["INFO", format ["Auto-enrolled friendly group %1 at %2m from the player.", _grp getVariable ["NeroAI_callsign", groupId _grp], round _d]] call NeroAI_fnc_log;
    };
} forEach _candidates;
