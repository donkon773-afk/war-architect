/* Pure partial repair. Unrelated hitpoints, including spent ERA blocks and APS components, are preserved. */
params ["_damage","_names","_values"];
private _next=+_values;
{private _name=toLower _x;if (_name find "wheel">=0 || {_name find "track">=0} || {_name find "engine">=0}) then {private _old=_values#_forEachIndex;_next set [_forEachIndex,((_old-.25) max .15) min _old];};} forEach _names;
[((_damage-.25) max .15) min _damage,_next]
