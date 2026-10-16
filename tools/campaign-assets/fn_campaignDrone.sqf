params ["_unit","_uav"];
if (!isRemoteExecuted || {remoteExecutedOwner!=2} || {_unit!=player} || {!local _unit} || {isNull _uav} || {!alive _uav} || {!(_uav getVariable ["NeroOP_drone",false])} || {_uav getVariable ["NeroOP_droneBuyer",objNull]!=_unit}) exitWith {};
if !(_unit connectTerminalToUAV _uav) then {systemChat "Беспилотник доставлен. Купите и экипируйте UAV-терминал своей стороны; затем подключитесь к аппарату штатным меню терминала.";};
