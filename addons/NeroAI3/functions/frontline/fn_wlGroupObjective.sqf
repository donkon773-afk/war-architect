/* A commander-assigned counterattack may recapture an eligible lost sector
 * while the side is voting elsewhere. It cannot create a new capturable area. */
params ["_group"];
private _counter = _group getVariable ["NeroWL_counterObjective",objNull];
if (missionNamespace getVariable ["NeroAI_rulesMode",false] && {!isNull _counter}
    && {(_group getVariable ["NeroWL_rulesMission",[]]) param [0,""] isEqualTo "ATTACK"}
    && {_counter isEqualTo ([side _group] call NeroAI_fnc_wlCounterTarget)}
    && {[_counter,side _group] call NeroAI_fnc_wlCaptureAllowed}) exitWith {_counter};
missionNamespace getVariable [format ["BIS_WL_currentSector_%1",side _group],objNull]
