params["_unit","_class"];
if(!isServer || {!(_unit isEqualType objNull)} || {!(_class isEqualType "")} || {isNull _unit} || {!isPlayer _unit})exitWith{};
if(isRemoteExecuted && {remoteExecutedOwner!=owner _unit})exitWith{};
[_unit,_class]call NeroWL_Design_fnc_cqPurchase;
