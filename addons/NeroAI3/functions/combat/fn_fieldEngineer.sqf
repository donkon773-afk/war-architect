params ["_unit"];
if (isNull _unit || {!alive _unit} || {isPlayer _unit} || {!local _unit} || {!(lifeState _unit in ["HEALTHY","INJURED"])} || {_unit getVariable ["ACE_isUnconscious",false]}) exitWith {false};
private _ace = _unit getVariable ["ACE_IsEngineer",0];
if (_ace isEqualType false) then {_ace = if (_ace) then {1} else {0};};
(_unit getUnitTrait "Engineer") || {_ace isEqualType 0 && {_ace >= 1}}
