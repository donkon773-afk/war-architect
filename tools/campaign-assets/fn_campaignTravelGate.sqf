/* Pure travel rules, also used by engine checks. */
params ["_side","_owner","_connected","_enemy","_onFoot","_alive","_conscious","_sourceEnemy"];
_side in [0,1] && {_owner==_side} && {_connected} && {!_enemy} && {_onFoot} && {_alive} && {_conscious} && {!_sourceEnemy}
