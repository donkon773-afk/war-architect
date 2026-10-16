/* Bootstrap only; ASSIGN_ROLE from the model may change this at any time. */
params ["_group"];
if (!isServer || {isNull _group} || {isPlayer leader _group} || {(_group getVariable ["NeroWL_role",""]) != ""}) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_enemyAIEnabled",true]) && {!(missionNamespace getVariable ["NeroAI_friendlyAutoEnrollEnabled",false])}) exitWith {};
private _players=allPlayers select {!(_x isKindOf "HeadlessClient_F")};
if (_players isEqualTo [] || {(_players findIf {(side _group getFriend side group _x)<0.6})<0 && {!(missionNamespace getVariable ["NeroAI_friendlyAutoEnrollEnabled",false])}}) exitWith {};
private _commanders=(missionNamespace getVariable ["BIS_WL_allWarlords",[]]) select {side (group _x) == side _group && {!isPlayer _x} && {alive _x}};
private _index=_commanders find (leader _group);
private _role="INFANTRY";
if (_index >= 0 && {missionNamespace getVariable ["NeroAI_airEnabled",true]} && {(missionNamespace getVariable ["NeroWL_airLimit",5])>0}) then {
 _role=if (_index < 3) then {["AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"] # _index} else {["ARMOR","MECHANIZED","RECON","INFANTRY"] # ((_index-3) mod 4)};
};
_group setVariable ["NeroWL_role",_role,true];
