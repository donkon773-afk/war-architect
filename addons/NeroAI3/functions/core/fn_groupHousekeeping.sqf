/* 4.5.0 [Vanilla Command]: the former psyche tick without the psyche. Every
 * 2 s it prunes stale groups, installs the casualty watcher on new members and
 * asks for a replan when the leader mounts or leaves a vehicle. It never touches
 * skills, behaviour, formation or composition — vanilla AI stays authoritative. */
if (!isServer) exitWith {};

private _stale = [];
{
    private _group = _y;
    if (!([_group] call NeroAI_fnc_validateGroup)) then {
        _stale pushBack _x;
    } else {
        private _leader = leader _group;
        private _strength={alive _x} count units _group;
        // Native recruits arrive after a lone commander was enrolled. Keep the
        // baseline at the largest actual roster, instead of reporting 9/1 alive.
        if (_strength > (_group getVariable ["NeroAI_initialStrength",0])) then {
            _group setVariable ["NeroAI_initialStrength",_strength,true];
        };
        private _leaderVehicle = vehicle _leader;
        private _vehicleId = if (_leaderVehicle isEqualTo _leader) then {""} else {netId _leaderVehicle};
        private _oldVehicleId = _group getVariable ["NeroAI_lastLeaderVehicle", ""];
        if (_vehicleId != _oldVehicleId) then {
            _group setVariable ["NeroAI_lastLeaderVehicle", _vehicleId, true];
            _group setVariable ["NeroAI_forcePlan", true, true];
        };
        { if (alive _x && {local _x}) then { [_x] call NeroAI_fnc_installUnitWatchers; }; } forEach units _group;
    };
} forEach NeroAI_activeGroups;
{ NeroAI_activeGroups deleteAt _x; } forEach _stale;
