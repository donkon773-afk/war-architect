params["_unit","_target",["_mode","TRAVEL"]];
if(!isServer || {!(_unit isEqualType objNull)} || {!(_target isEqualType objNull)} || {isNull _unit} || {!alive _unit} || {!isPlayer _unit} || {!(_target in BIS_WL_sectors)})exitWith{};
if(isRemoteExecuted && {remoteExecutedOwner!=owner _unit})exitWith{};
private _s=side group _unit;
if(_mode=="TARGET")exitWith{if(!(_target getVariable["NeroWL_isBase",false]))then{missionNamespace setVariable[format["BIS_WL_currentSector_%1",_s],_target,true];};};
if(_mode!="TRAVEL" || {vehicle _unit!=_unit} || {(_target getVariable["BIS_WL_sectorSide",sideUnknown])!=_s} || {diag_tickTime-(_unit getVariable["NeroWL_lastTravel",-100])<60})exitWith{};
if((allUnits findIf{alive _x && {(_s getFriend side group _x)<0.6} && {(_x distance2D _unit<300)||{_x distance2D _target<300}}})>=0)exitWith{};
private _pos=(getPosATL _target)findEmptyPosition[15,100,typeOf _unit];if(_pos isEqualTo [])exitWith{};
_unit setPosATL _pos;_unit setVariable["NeroWL_lastTravel",diag_tickTime];
