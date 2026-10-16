/* Pure ownership/state gate shared by march and vehicle supervisors. */
params ["_human","_lift","_ride","_drop"];
!_human && {!_lift} && {!_ride} && {!_drop}
