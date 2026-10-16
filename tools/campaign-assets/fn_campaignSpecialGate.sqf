/* Pure side-wide limit and replacement cooldown, irrespective of parent squad. */
params ["_now","_until","_alive"];
_now isEqualType 0 && {_until isEqualType 0} && {_alive isEqualType 0} && {_now>=0 && {_now<1e10}} && {_until>=0 && {_until<1e10}} && {_now>=_until} && {_alive==0}
