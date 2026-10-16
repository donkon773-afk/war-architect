/* One bounded RPT line per minute: per-side economy, fleet and strength, GREEN
 * against its lobby cap, and server FPS. Read-only apart from resetting the
 * per-minute purchase counters written by fn_purchaseAsset/fn_purchaseAirAsset. */
if (!isServer) exitWith {};
private _wls=missionNamespace getVariable ["BIS_WL_allWarlords",[]];
private _lines=[];
{
    private _side=_x;
    private _ai=_wls select {alive _x && {!isPlayer _x} && {(side group _x) isEqualTo _side}};
    private _cps=_ai apply {private _f=_x getVariable ["BIS_WL_funds",0]; if (_f isEqualType 0) then {_f} else {0}};
    private _sum=0;
    {_sum=_sum+_x;} forEach _cps;
    private _ground=vehicles select {alive _x && {_x isKindOf "LandVehicle"} && {private _o=_x getVariable ["BIS_WL_itemOwner",objNull]; !isNull _o && {(side group _o) isEqualTo _side}}};
    private _crewed=_ground select {({alive _x} count crew _x)>0};
    private _air=vehicles select {alive _x && {_x isKindOf "Air"} && {(_x getVariable ["NeroAI_ownerSide",sideUnknown]) isEqualTo _side}};
    private _units={alive _x && {!isPlayer _x} && {(side group _x) isEqualTo _side}} count allUnits;
    private _llm=0;
    {if ((side _y) isEqualTo _side) then {_llm=_llm+1;};} forEach NeroAI_activeGroups;
    private _kb=format ["NeroWL_buys_%1",_side];
    private _kr=format ["NeroWL_buyRefusals_%1",_side];
    _lines pushBack format ["%1 cmd=%2 cp=%3 avg=%4 min=%5 ground=%6 crewed=%7 air=%8[%9] ai=%10 llmGroups=%11 buys=%12 refused=%13",
        _side, count _ai, round _sum, if (_ai isEqualTo []) then {0} else {round (_sum / count _ai)}, if (_cps isEqualTo []) then {0} else {round (selectMin _cps)},
        count _ground, count _crewed, count _air, (_air apply {_x getVariable ["NeroAI_airState","?"]}) joinString "/", _units, _llm,
        missionNamespace getVariable [_kb,0], missionNamespace getVariable [_kr,0]];
    missionNamespace setVariable [_kb,0];
    missionNamespace setVariable [_kr,0];
} forEach [west,east];
private _green={alive _x && {!isPlayer _x} && {(side group _x) isEqualTo resistance}} count allUnits;
["INFO", format ["TELEMETRY fps=%1 fpsMin=%2 pending=%3 green=%4/%5 | %6",
    round diag_fps, round diag_fpsMin, count NeroAI_pending, _green, missionNamespace getVariable ["NeroWL_greenTotalCap",-1], _lines joinString " | "]] call NeroAI_fnc_log;
