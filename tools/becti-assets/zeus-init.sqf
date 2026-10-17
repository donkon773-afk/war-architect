/* One server-owned curator for the host / logged-in administrator. */
if (!isServer) exitWith {};
if (missionNamespace getVariable ["WA_BECTI_zeusStarted",false]) exitWith {};
WA_BECTI_zeusStarted=true;
private _logic=(createGroup [sideLogic,true]) createUnit ["ModuleCurator_F",[0,0,0],[],0,"NONE"];
_logic setVariable ["Addons",0,true];
// Allow the BI/ACE module initializer to consume Addons=0 before installing
// the explicit validated catalog. No repeated all-addon rebuild per object.
sleep 1;
removeAllCuratorAddons _logic;
_logic addCuratorAddons WA_BECTI_curatorAddons;
{_logic setCuratorCoef [_x,0];} forEach ["place","edit","delete","destroy","group","synchronize"];
_logic addCuratorPoints 1;
removeAllCuratorEditingAreas _logic;removeAllCuratorCameraAreas _logic;
ADMIN_ZEUS=_logic;publicVariable "ADMIN_ZEUS";
diag_log "[WA BECTI ZEUS] module ready; host/admin assignment required";
while {!(missionNamespace getVariable ["CTI_GameOver",false]) && {!isNull _logic}} do {
    if (!isNull getAssignedCuratorUnit _logic) then {_logic addCuratorEditableObjects [allUnits+vehicles,true];};
    sleep 5;
};
