params ["_unit","_group"];
if (!isServer || {!alive _unit} || {!isPlayer _unit} || {isNull _group}) exitWith {};
private _logic=_unit getVariable ["NeroOP_hcLogic",objNull];
if (isNull _logic) then {private _logics=createGroup [sideLogic,true];_logic=_logics createUnit ["HighCommand",[0,0,0],[],0,"NONE"];_logic setVariable ["addAllGroups",false,true];_logic setVariable ["chainofcommand",false,true];_logic synchronizeObjectsAdd [_unit];_unit setVariable ["NeroOP_hcLogic",_logic,true];};
_group setVariable ["NeroOP_hcCommander",_unit,true];_group setGroupOwner owner _unit;[_unit,_group,_logic] remoteExec ["NeroOP_fnc_campaignHC",owner _unit];
