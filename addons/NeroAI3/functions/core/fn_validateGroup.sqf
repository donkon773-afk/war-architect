params ["_group", ["_requireActive", true]];
if (isNull _group) exitWith {false};
private _leader = leader _group;
if (isNull _leader || {!alive _leader}) exitWith {false};
if (({isPlayer _x} count units _group) > 0) exitWith {false};
if (isServer && {!local _leader}) exitWith {false};
if (_requireActive && {!(_group getVariable ["NeroAI_active", false])}) exitWith {false};
true
