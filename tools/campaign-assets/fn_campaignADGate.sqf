/* Pure authorization: external target must still be tracked by a live friendly radar. */
params ["_static","_missile","_localRange","_targetRange","_radarDistance","_radarRange","_targetRadarRange","_age","_radarOn","_friendly","_tracked"];
private _linked=_radarOn && {_friendly} && {_tracked} && {_age>=0 && {_age<=2}} && {_radarDistance>=0 && {_radarDistance<=3000}} && {_radarRange>0} && {_targetRadarRange>=0 && {_targetRadarRange<=_radarRange}};
private _fire=_targetRange>=0 && {_targetRange<=_localRange || {_static && {_missile} && {_linked} && {_targetRange<=_radarRange}}};
[_linked,_fire,if (_static) then {_localRange} else {-1}]
