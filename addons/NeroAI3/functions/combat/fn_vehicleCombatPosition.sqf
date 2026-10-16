/* Finite search around the native objective. Uses believed contact positions,
 * terrain, hull clearance and a high/low fire ray; no hidden enemy scan. */
params ["_vehicle","_group","_objective",["_role","FIRE_SUPPORT"],["_bearing",0]];
private _intel = _group getVariable ["NeroAI_intel",[]];
private _shared = (NeroAI_sharedIntel getOrDefault [str side _group,[]]) select {diag_tickTime-(_x param [3,-1e6]) <= 120};
_intel = +_intel;
{_intel pushBack [_x # 0,_x # 1,_x # 2,_x param [5,""]];} forEach _shared;
private _targetObject = objNull;
private _focus = +_objective;private _known = false;
{
    private _type = _x param [0,""];private _pos = _x param [1,[]];
    private _armour = _type isKindOf "Tank" || {_type isKindOf "Wheeled_APC_F"} || {_type isKindOf "Tracked_APC_F"};
    if (count _pos >= 2 && {_pos distance2D _objective < 900} && {_role != "ANTI_TANK" || {_armour}}) exitWith {_focus = [_pos # 0,_pos # 1,1.2];_known = true;_targetObject = objectFromNetId (_x param [3,""]);};
} forEach _intel;
private _range = if (_role isEqualTo "ANTI_TANK") then {460} else {if (_vehicle isKindOf "Tank" && {getNumber (configOf _vehicle >> "transportSoldier") < 4}) then {420} else {300}};
private _key = format ["%1|%2|%3|%4|%5",_role,round ((_objective # 0)/30),round ((_objective # 1)/30),round ((_focus # 0)/40),round ((_focus # 1)/40)];
private _cache = _vehicle getVariable ["NeroWL_firePositionCache",["",-1e6,[]]];
if ((_cache # 0) isEqualTo _key && {diag_tickTime-(_cache # 1) < 30}) exitWith {_cache # 2};
private _box = 2 boundingBoxReal _vehicle;
private _radius = ((_box param [2,4]) max 3) min 12;
private _width = abs (((_box # 1) # 0)-((_box # 0) # 0));
private _length = abs (((_box # 1) # 1)-((_box # 0) # 1));
private _best = [];private _bestScore = -1e9;
private _origin = getPosATL _vehicle;
{
    private _p = _objective getPos [_range,_bearing+_x];
    private _water = surfaceIsWater _p && {!isOnRoad _p};
    private _slope = (surfaceNormal _p) # 2;
    private _obstacles = nearestObjects [_p,["House","Building","LandVehicle"],_radius+3];
    private _clear = (_obstacles findIf {_x != _vehicle}) < 0;
    /* Short sweeps through the prospective footprint include rocks/walls,
     * which are not necessarily returned as a House. */
    private _heading = _p getDir _focus;
    {
        private _offset = _x;
        {
            private _centre = _p getPos [_offset,_heading+90];
            private _a = _centre getPos [_length/2+1,_heading+180];
            private _b = _centre getPos [_length/2+1,_heading];
            _a set [2,_x];_b set [2,_x];
            if ((lineIntersectsSurfaces [ATLToASL _a,ATLToASL _b,_vehicle,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) then {_clear = false;};
        } forEach [0.35,1.2];
    } forEach [-(_width/2+0.5),0,_width/2+0.5];
    private _shot = +_p;_shot set [2,2.5];
    private _hull = +_p;_hull set [2,0.6];
    private _to = ATLToASL _focus;
    private _visible = !_known || {(lineIntersectsSurfaces [ATLToASL _shot,_to,_vehicle,_targetObject,true,1,"FIRE","GEOM"]) isEqualTo []};
    private _cover = _known && {(lineIntersectsSurfaces [ATLToASL _hull,_to,_vehicle,_targetObject,true,1,"GEOM","NONE"]) isNotEqualTo []};
    private _distance = _p distance2D _focus;
    private _elevation = atan (((_to # 2)-((ATLToASL _shot) # 2))/(_distance max 1));
    private _turret = configOf _vehicle >> "Turrets" >> "MainTurret";
    private _minElev = if (isNumber (_turret >> "minElev")) then {getNumber (_turret >> "minElev")} else {-10};
    private _maxElev = if (isNumber (_turret >> "maxElev")) then {getNumber (_turret >> "maxElev")} else {25};
    private _near = 1e9;
    {private _pos = _x param [1,[]];if (count _pos >= 2) then {_near = _near min (_p distance2D _pos);};} forEach _intel;
    private _back = _p getPos [15,_p getDir _origin];
    private _escape = !surfaceIsWater _back && {((surfaceNormal _back) # 2) >= 0.92};
    private _score = [_origin distance2D _p,_slope,_visible,_cover,_clear,_water,_elevation >= _minElev && {_elevation <= _maxElev},_near,_escape,_range,_distance] call NeroAI_fnc_combatPositionScore;
    if (_score > _bestScore) then {_bestScore = _score;_best = [_p # 0,_p # 1,0];};
} forEach [0,-25,25,-50,50,-75,75];
/* No suitable position: hold the current place and report, not a blind rush. */
if (_best isEqualTo []) then {_best = _origin;};
_vehicle setVariable ["NeroWL_firePositionCache",[_key,diag_tickTime,_best]];
_vehicle setVariable ["NeroWL_firePosition",[_best,_known,_bestScore],true];
_vehicle setVariable ["NeroWL_fireObjective",+_objective];
_best
