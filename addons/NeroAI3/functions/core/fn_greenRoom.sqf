/* Lobby-wide cap on living GREEN AI (native sector garrisons + NeroAI partisans).
 *   [0]  call NeroAI_fnc_greenRoom -> free slots (may be negative when over cap); -1e6 unused
 *   [n]  reserve up to n slots for a spawner that has not created its units yet -> granted
 *   [-n] release a reservation once the units exist (they are then counted alive)
 * Returns 1e6 when the cap is off (-1). */
params [["_reserve",0]];
private _cap=missionNamespace getVariable ["NeroWL_greenTotalCap",-1];
if (!(_cap isEqualType 0) || {_cap<0}) exitWith {1e6};
private _room=0;
isNil {
    private _held=missionNamespace getVariable ["NeroWL_greenReserved",0];
    private _alive={alive _x && {!isPlayer _x} && {(side group _x) isEqualTo resistance}} count allUnits;
    _room=_cap-_alive-_held;
    if (_reserve>0) then {
        private _take=_reserve min (_room max 0);
        missionNamespace setVariable ["NeroWL_greenReserved",_held+_take];
        _room=_take;
    };
    if (_reserve<0) then {missionNamespace setVariable ["NeroWL_greenReserved",(_held+_reserve) max 0];};
};
_room
