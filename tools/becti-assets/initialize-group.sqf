/* Native BECTI contract, with private locals and a ready first life. */
params ["_team","_side"];
if (isNull _team) exitWith {};
private _logic=_side call CTI_CO_FNC_GetSideLogic;
if (isMultiplayer && {isPlayer (_team getVariable ["bis_dg_cre",objNull])}) then {_team setVariable ["cti_client_group",true];};
if (isNil {_team getVariable "cti_role_evo"}) then {_team setVariable ["cti_role_evo","Infantry"];};
if (isNil {_team getVariable "cti_order"}) then {_team setVariable ["cti_order",CTI_ORDER_TAKETOWNS,true];};
if (isNil {_team getVariable "cti_order_pos"}) then {_team setVariable ["cti_order_pos",[0,0],true];};
if (isNil {_team getVariable "cti_nextrespawn"}) then {_team setVariable ["cti_nextrespawn",time max 0.001];};
if (isNil {_team getVariable "cti_role"}) then {_team setVariable ["cti_role","Infantry",true];};
if (isNil {_team getVariable "cti_independent"}) then {_team setVariable ["cti_independent",true,true];};
if (isNil {_team getVariable "cti_funds"}) then {
    _team setVariable ["cti_funds",if (isPlayer leader _team) then {0} else {missionNamespace getVariable format ["CTI_ECONOMY_STARTUP_FUNDS_%1",_side]},true];
};
private _teams=(_logic getVariable ["cti_teams",[]])-[grpNull];
if (!(_team in _teams)) then {_logic setVariable ["cti_teams",_teams+[_team],true];};
