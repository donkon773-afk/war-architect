/* NeroAI 4.5.1 — true when a group is only aircraft crew: UAV AI "pilots"
 * (UAV_AI_base_F) or men sitting in an Air vehicle. Such groups are never
 * enrolled: they cannot be commanded as a squad, and a drone / jet bought
 * through vanilla requisition (fn_WLAirdrop createVehicleCrew, aircraft
 * arrival) must stay vanilla.
 *
 * LIVE 14.09 22:22-22:40: "Альфа-10" (2× B_UAV_AI), "Альфа-11" (B_Fighter_Pilot_F)
 * and "Такистан-17" (O_UAV_AI) were auto-enrolled, ordered around as infantry and
 * all died within minutes. */
params ["_group"];
if (isNull _group) exitWith {false};
private _living = (units _group) select {alive _x};
if (_living isEqualTo []) exitWith {false};
/* 23:07 second run: a modded "GX_B_UAV_AI" slipped through the class check —
 * the name pattern and the vehicle's own UAV flag are checked too. */
/* 15.09 03:19-03:42: four player-bought jets were lost — the vanilla delivery
 * pilot (B_Fighter_Pilot_F) was enrolled while on the ground and sent to assault.
 * A pilot-class unit is aircraft crew whether or not it is sitting in the cockpit. */
(_living findIf {
    !(_x isKindOf "UAV_AI_base_F")
    && {((toUpper (typeOf _x)) find "UAV_AI") < 0}
    && {((toUpper (typeOf _x)) find "PILOT") < 0}
    && {!((vehicle _x) isKindOf "Air")}
    && {!(unitIsUAV (vehicle _x))}
}) < 0
