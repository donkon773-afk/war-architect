/* Validate bounded data from persistent storage; never evaluate saved content. */
params ["_save","_signature","_nodes","_allowed","_active","_budgets","_groupSizes","_size","_cargo","_limit","_captureTarget",["_shops",[[],[]]],["_fleetLimits",[8,2]],["_fleetBudget",24]];
if !(_save isEqualType []) exitWith {false};if !(count _save in [10,13,14,15,16]) exitWith {false};
if (_save findIf {isNil {_x}}>=0 || {!((_save#0) isEqualType 0)} || {!((_save#0) in [1,2,3,4,5])} || {(_save#0)==1 && {count _save!=10}} || {(_save#0)==2 && {count _save!=13}} || {(_save#0)==3 && {count _save!=14}} || {(_save#0)==4 && {count _save!=15}} || {(_save#0)==5 && {count _save!=16}} || {!((_save#1) isEqualTo _signature)}) exitWith {false};
private _owners=_save#2;private _stocks=_save#3;private _progress=_save#4;private _issued=_save#5;private _groups=_save#6;private _convoys=_save#7;private _winner=_save#8;private _elapsed=_save#9;
if ([_owners,_stocks,_progress,_issued,_groups,_convoys] findIf {!(_x isEqualType [])}>=0) exitWith {false};
if (count _owners!=_nodes || {count _stocks!=_nodes} || {count _progress!=_nodes} || {count _issued!=2} || {count _groups>(_active#0)+(_active#1)} || {count _convoys>2*_limit}) exitWith {false};
private _number={params ["_v","_min","_max"];_v isEqualType 0 && {_v>=_min} && {_v<=_max}};
private _point={params ["_p"];_p isEqualType [] && {count _p==2} && {[_p#0,500,_size-500] call _number} && {[_p#1,500,_size-500] call _number}};
if (_owners findIf {!(_x isEqualType 0) || {!(_x in [-1,0,1])}}>=0 || {_stocks findIf {!([_x,0,5000] call _number)}>=0}) exitWith {false};
if (_progress findIf {!(_x isEqualType []) || {count _x!=2} || {_x findIf {!([_x,0,_captureTarget] call _number)}>=0}}>=0) exitWith {false};
if ([0,1] findIf {!([_issued#_x,0,_budgets#_x] call _number) || {floor (_issued#_x)!=(_issued#_x)}}>=0) exitWith {false};
if (!(_winner isEqualType 0) || {!(_winner in [-1,0,1,2])} || {!([_elapsed,0,1e10] call _number)}) exitWith {false};
private _credits=if ((_save#0)>=4) then {_save#14} else {[]};private _recruitBudget=[_credits,_issued,_budgets,_groupSizes] call NeroOP_fnc_campaignRecruitBudget;if !(_recruitBudget#0) exitWith {false};
if ((_save#0)==5) then {private _cd=_save#15;if (!([_cd,_save#10] call NeroOP_fnc_campaignSpecialSnapshot)) exitWith {_recruitBudget=[false];};};if !(_recruitBudget#0) exitWith {false};
private _counts=[0,0];private _valid=true;private _keys=[];
{if !(_x isEqualType []) then {_valid=false;} else {
 if !(count _x in [4,5,6,7]) then {_valid=false;} else {_x params ["_side","_target","_position","_classes"];if (count _x==7 && {!((_x#6) isEqualType "") || {count (_x#6)>64}}) then {_valid=false;};private _guard=if (count _x>=5) then {_x#4} else {false};
  if ((_save#0)>=2) then {private _key=_x param [5,-1];if (!([_key,1,1000000] call _number) || {floor _key!=_key} || {_key in _keys}) then {_valid=false;} else {_keys pushBack _key;};};
  if (!(_side isEqualType 0) || {!(_side in [0,1])} || {!([_target,0,_nodes-1] call _number)} || {floor _target!=_target} || {!([_position] call _point)} || {!(_classes isEqualType [])} || {!(_guard isEqualType true)}) then {_valid=false;} else {
   _counts set [_side,(_counts#_side)+1];private _groupKey=_x param [5,-1];private _paid=_credits findIf {(_x#0)==_side && {(_x#1)==_groupKey}};private _extra=if (_paid<0) then {0} else {(_credits#_paid)#2};private _maximum=((_groupSizes#_side)+_extra) min 12;if (count _classes<1 || {count _classes>_maximum} || {_classes findIf {!(_x isEqualType "") || {!(_x in (_allowed#_side))}}>=0}) then {_valid=false;};
  };
 };
};} forEach _groups;
if (!_valid || {_counts#0>_active#0} || {_counts#1>_active#1} || {_counts#0>_issued#0} || {_counts#1>_issued#1}) exitWith {false};_counts=[0,0];
{if !(_x isEqualType []) then {_valid=false;} else {if (count _x!=6) then {_valid=false;} else {_x params ["_side","_source","_target","_amount","_pos","_ttl"];
 if (!(_side isEqualType 0) || {!(_side in [0,1])} || {!([_source,0,_nodes-1] call _number)} || {!([_target,0,_nodes-1] call _number)} || {floor _source!=_source} || {floor _target!=_target} || {!([_amount,1,_cargo] call _number)} || {!([_pos] call _point)} || {!([_ttl,1,1800] call _number)}) then {_valid=false;} else {_counts set [_side,(_counts#_side)+1];};
};};} forEach _convoys;
if ((_save#0)>=3) then {private _idle=_save#13;if !(_idle isEqualType []) then {_valid=false;} else {if (count _idle>2*_limit) then {_valid=false;};{if !(_x isEqualType [] && {count _x==4}) then {_valid=false;} else {_x params ["_side","_pos","_damage","_fuel"];if (!(_side isEqualType 0) || {!(_side in [0,1])} || {!([_pos] call _point)} || {!([_damage,0,.99] call _number)} || {!([_fuel,0,1] call _number)}) then {_valid=false;} else {_counts set [_side,(_counts#_side)+1];};};} forEach _idle;};};
_valid && {_counts#0<=_limit} && {_counts#1<=_limit} && {(_save#0)==1 || {[_save#10,_save#11,_save#12,_shops,_groups,_allowed,_groupSizes,_size,_fleetLimits,_fleetBudget,_issued,_credits] call NeroOP_fnc_campaignFleetSnapshot}}
