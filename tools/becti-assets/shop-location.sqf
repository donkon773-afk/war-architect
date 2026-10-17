// Same location rules on the client and server; server always checks again.
params ["_buyer"];
private _side=side group _buyer;
if !(_side in [west,east]) exitWith {[]};
private _hq=_side call CTI_CO_FNC_GetSideHQ;
if (alive _hq && {_buyer distance2D _hq<400}) exitWith {[getPosATL _hq,"Штаб / основная база"]};
private _structures=_side call CTI_CO_FNC_GetSideStructures;
private _i=_structures findIf {alive _x && {_buyer distance2D _x<150}};
if (_i>=0) exitWith {[getPosATL (_structures#_i),"Своя база"]};
private _towns=_side call CTI_CO_FNC_GetSideTowns;
_i=_towns findIf {_buyer distance2D _x<CTI_TOWNS_CAPTURE_RANGE};
if (_i>=0) exitWith {[getPosATL (_towns#_i),(_towns#_i) getVariable ["cti_town_name","Свой сектор"]]};
[]
