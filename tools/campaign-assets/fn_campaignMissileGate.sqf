/* Pure launch envelope; never changes ammunition or bypasses player ownership. */
params ["_range","_minimum","_maximum","_angle","_cone","_targetSpeed","_speedLimit","_stable","_cooldown","_ammo","_reloading","_visible"];
_maximum>0 && {_range>=_minimum} && {_range<=_maximum} && {_angle<=_cone} && {_speedLimit<=0 || {_targetSpeed<=_speedLimit}} && {_stable>=2} && {_cooldown>=4} && {_ammo>0} && {_reloading<=0} && {_visible}
