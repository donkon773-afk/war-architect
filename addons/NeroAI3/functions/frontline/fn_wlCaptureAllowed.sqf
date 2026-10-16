/* Preserve native current/historical capture rules, but require a live route
 * from the attacking side's base. History alone is not connectivity. */
params ["_sector","_side"];
if (isNull _sector || {!(_side in [west,east])}) exitWith {false};
private _listing = [_side] call NeroAI_fnc_wlSnapshot;
if (count _listing < 3 || {!(_sector in (_listing # 1))}) exitWith {false};
[_sector,missionNamespace getVariable [format ["BIS_WL_currentSector_%1",_side],objNull],
    (missionNamespace getVariable [format ["BIS_WL_conqueredSectors_%1",_side],[]]) + (missionNamespace getVariable [format ["NeroWL_ownershipHistory_%1",_side],[]]),_listing # 1] call NeroAI_fnc_wlCaptureRule
