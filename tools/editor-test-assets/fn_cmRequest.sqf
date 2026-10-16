params ["_unit"];
if (!isServer || {isNull _unit} || {!isPlayer _unit} || {remoteExecutedOwner!=owner _unit}) exitWith {};
private _v=vehicle _unit;if (_v!=_unit && {_v isKindOf "Air"}) then {[_v] call NeroOP_fnc_campaignCountermeasure;};
