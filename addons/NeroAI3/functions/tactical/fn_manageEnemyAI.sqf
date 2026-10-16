/* NeroAI 4.4.0 [Command]: adversarial AI manager.
 *
 * Two classes of adversary, handled differently on purpose:
 *
 *   ARMY (east or west — whichever regular army opposes the player): under
 *   NeroAI from the very first pass, with NO distance gate and its own cap.
 *   Live 13.09: RED's base sat 10.1 km from BLUE's, just past the old 9 km
 *   seed ring, so RED was never planned until the player drove within 4 km —
 *   26 minutes into the match. A regular army does not wait to be visited.
 *
 *   PARTISANS (resistance): the original 4 km activation / 4.5 km release
 *   ring with slot rotation, capped separately — dozens of GUER garrison
 *   groups across the map do not all need LLM plans at once.
 *
 * Base asset crews (mortar gunners, cold pilots) are never candidates. */
if (!isServer) exitWith {};
if (!NeroAI_transportReady || {!(missionNamespace getVariable ["NeroAI_enemyAIEnabled", true])}) exitWith {};

private _players = allPlayers select {alive _x};
if (_players isEqualTo []) exitWith {};
private _playerSide = side group (_players # 0);
private _maxPartisan = missionNamespace getVariable ["NeroAI_maxEnemyGroups", 6];
private _observer=getNumber(missionConfigFile >> "NeroWL_observer")==1;
private _maxArmy = if(_observer)then{48}else{missionNamespace getVariable ["NeroAI_maxEnemyArmyGroups", 14]};
private _activationDist = missionNamespace getVariable ["NeroAI_enemyMaxDistanceMeters", 4000];
private _releaseDist = _activationDist + 500;
private _seeding = !(missionNamespace getVariable ["NeroAI_enemySeeded", false]);

private _fnc_isArmy = { params ["_s"]; (_s isEqualTo east) || {_s isEqualTo west} || {getNumber(missionConfigFile >> "NeroWL_threeSides")==1 && {_s isEqualTo resistance}} };
private _fnc_minPlayerDist = {
    params ["_obj"];
    private _m = 1e9;
    { private _d = _obj distance _x; if (_d < _m) then {_m = _d;}; } forEach _players;
    _m
};
private _fnc_hostile = {
    params ["_grp"];
    !isNull (leader _grp) && {alive (leader _grp)} && {!isPlayer (leader _grp)} &&
    {({isPlayer _x} count units _grp) isEqualTo 0} &&
    {!(_grp getVariable ["NeroWL_garrison",false])} && {!(_grp getVariable ["NeroAI_isBaseAssetCrew", false])} &&
    {!([_grp] call NeroAI_fnc_isAirCrewGroup)} &&
    {([_grp, false] call NeroAI_fnc_validateGroup)} &&
    {_observer || {((side _grp) != _playerSide) && {(_playerSide getFriend (side _grp)) < 0.6}}}
};

/* 1. Prune: dead / empty / invalid for everyone; distance only for partisans. */
{
    private _group = _y;
    if (_group getVariable ["NeroAI_isEnemy", false] && {!(_group getVariable ["NeroWL_garrison",false])}) then {
        private _living = (units _group) select {alive _x};
        private _leader = leader _group;
        private _isArmy = [_group getVariable ["NeroAI_factionSide", side _group]] call _fnc_isArmy;
        private _tooFar = false;
        if (!_isArmy) then {
            _tooFar = isNull _leader || {!alive _leader} || {([_leader] call _fnc_minPlayerDist) > _releaseDist};
        };
        if (_living isEqualTo [] || {!([_group, false] call NeroAI_fnc_validateGroup)} || {_tooFar}) then {
            _group setVariable ["NeroAI_active", false, true];
            NeroAI_activeGroups deleteAt _x;
            ["INFO", format ["Adversarial group %1 released (%2).", _group getVariable ["NeroAI_callsign", groupId _group],
                if (_tooFar) then {format ["outside %1m", round _releaseDist]} else {"neutralized"}]] call NeroAI_fnc_log;
        };
    };
} forEach (+NeroAI_activeGroups);

/* 2. Tally. */
private _armyCount = 0;
private _partisanCount = 0;
{
    if (_y getVariable ["NeroAI_isEnemy", false]) then {
        if ([_y getVariable ["NeroAI_factionSide", side _y]] call _fnc_isArmy) then { _armyCount = _armyCount + 1; } else { _partisanCount = _partisanCount + 1; };
    };
} forEach NeroAI_activeGroups;

/* 3. Candidates. */
private _armyCandidates = [];
private _partisanCandidates = [];
{
    private _grp = _x;
    if (!(_grp getVariable ["NeroAI_active", false]) && {[_grp] call _fnc_hostile}) then {
        private _d = [leader _grp] call _fnc_minPlayerDist;
        if ([side _grp] call _fnc_isArmy) then {
            _armyCandidates pushBack [_d, _grp];
        } else {
            if (_d <= _activationDist) then { _partisanCandidates pushBack [_d, _grp]; };
        };
    };
} forEach allGroups;
_armyCandidates sort true;
_partisanCandidates sort true;

private _fnc_enroll = {
    params ["_grp", "_dist", "_kind"];
    [objNull, _grp, true] call NeroAI_fnc_registerGroup;
    ["INFO", format ["Enrolled adversarial %1 group %2 (%3) at %4m%5.", _kind,
        _grp getVariable ["NeroAI_callsign", groupId _grp], side _grp, round _dist,
        if (_seeding) then {" [start seed]"} else {""}]] call NeroAI_fnc_log;
};

/* 4a. Army: fill up to the army cap, closest first, no distance gate. */
{
    if (_armyCount >= _maxArmy) exitWith {};
    _x params ["_d", "_grp"];
    [_grp, _d, "army"] call _fnc_enroll;
    _armyCount = _armyCount + 1;
} forEach _armyCandidates;

/* 4b. Partisans: slot rotation inside the ring, then fill. */
if (_partisanCount >= _maxPartisan && {!(_partisanCandidates isEqualTo [])}) then {
    private _closestNew = (_partisanCandidates # 0) # 0;
    private _farthest = objNull;
    private _farDist = _activationDist;
    {
        if ((_y getVariable ["NeroAI_isEnemy", false]) && {!([_y getVariable ["NeroAI_factionSide", side _y]] call _fnc_isArmy)}) then {
            private _l = leader _y;
            if (!isNull _l) then {
                private _md = [_l] call _fnc_minPlayerDist;
                if (_md > _farDist) then { _farDist = _md; _farthest = _y; };
            };
        };
    } forEach NeroAI_activeGroups;
    if (!isNull _farthest && {_farDist - _closestNew > 800}) then {
        _farthest setVariable ["NeroAI_active", false, true];
        NeroAI_activeGroups deleteAt (netId _farthest);
        _partisanCount = _partisanCount - 1;
        ["INFO", format ["Rotated partisan slot: released %1 at %2m for a closer threat at %3m.", _farthest getVariable ["NeroAI_callsign", groupId _farthest], round _farDist, round _closestNew]] call NeroAI_fnc_log;
    };
};
{
    if (_partisanCount >= _maxPartisan) exitWith {};
    _x params ["_d", "_grp"];
    [_grp, _d, "partisan"] call _fnc_enroll;
    _partisanCount = _partisanCount + 1;
} forEach _partisanCandidates;

if (_seeding) then {
    NeroAI_enemySeeded = true;
    ["INFO", format ["Adversarial start seed complete: %1 army + %2 partisan group(s) under NeroAI.", _armyCount, _partisanCount]] call NeroAI_fnc_log;
};
