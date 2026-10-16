/* One topology snapshot per simulation frame, shared by capture triggers.
 * Owners/connections are public map data, never hidden hostile positions. */
params ["_side"];
private _cache = missionNamespace getVariable ["NeroWL_frontlineFrame",[-1,createHashMap]];
if ((_cache # 0) != diag_frameNo) then {
    private _sectors = (missionNamespace getVariable ["BIS_WL_sectors",[]]) select {!isNull _x};
    private _nodes = _sectors apply {[netId _x,str (_x getVariable ["BIS_WL_sectorSide",sideUnknown]),(_x getVariable ["BIS_WL_connectedSectors",[]]) apply {netId _x}]};
    private _objects = createHashMapFromArray (_sectors apply {[netId _x,_x]});
    private _data = createHashMap;
    {
        private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",_x],objNull];
        private _ids = [_nodes,netId _base,str _x] call NeroAI_fnc_wlGraph;
        _data set [str _x,_ids apply {_x apply {_objects getOrDefault [_x,objNull]}}];
    } forEach [west,east];
    _cache = [diag_frameNo,_data];missionNamespace setVariable ["NeroWL_frontlineFrame",_cache];
};
(_cache # 1) getOrDefault [str _side,[]]
