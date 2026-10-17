/* Share perceived reports; never read live positions of unseen enemies. */
params ["_group"];
private _side=side _group;private _logic=_side call CTI_CO_FNC_GetSideLogic;
private _cached=_logic getVariable ["WA_BECTI_contacts",[-100,[]]];
if (serverTime-(_cached#0)<5) exitWith {_cached#1};
private _reports=[];private _seen=[];
{
 private _observer=leader _x;
 if (alive _observer) then {
  {
   _x params ["_p","_type","_perceivedSide","_value","_object"];
   if (_perceivedSide in [west,east,resistance] && {_side getFriend _perceivedSide<.6} && {_value>1} && {!isNull _object} && {alive _object} && {!(_object in _seen)}) then {
    _seen pushBack _object;_reports pushBack [_object,+_p,_type];
   };
  } forEach (_observer nearTargets 16000);
 };
} forEach (_side call CTI_CO_FNC_GetSideGroups);
_logic setVariable ["WA_BECTI_contacts",[serverTime,_reports]];
_reports
