/* Vehicles contain typed data and whitelisted classes, never executable content. */
params ["_fleet","_issued","_lastBuy","_shops","_groups","_infantry","_sizes","_world","_limits","_budget",["_groupIssued",[1000000,1000000]],["_recruits",[]]];
if !(_fleet isEqualType [] && {_issued isEqualType []} && {_lastBuy isEqualType []}) exitWith {false};
if (count _issued!=2 || {count _lastBuy!=2} || {count _fleet>2*((_limits#0)+(_limits#1))}) exitWith {false};
private _number={params ["_v","_a","_b"];_v isEqualType 0 && {_v>=_a} && {_v<=_b}};
if ([0,1] findIf {!([_issued#_x,0,_budget] call _number) || {floor (_issued#_x)!=(_issued#_x)} || {!([_lastBuy#_x,0,600] call _number)}}>=0) exitWith {false};
private _counts=[[0,0],[0,0]];private _seen=[];private _loans=[];private _valid=true;
{if !(_x isEqualType [] && {count _x in [11,12]}) then {_valid=false;} else {
 _x params ["_side","_class","_parent","_pos","_dir","_damage","_fuel","_crew","_ai"];
 if (!(_side isEqualType 0) || {!(_side in [0,1])} || {!(_class isEqualType "")} || {!(_crew isEqualType [])} || {!(_ai isEqualType true)} || {!([_parent,1,1000000] call _number)} || {floor _parent!=_parent} || {!(_pos isEqualType [])} || {count _pos!=3}) then {_valid=false;} else {
  private _independent=count _x==12;private _meta=_x param [11,[false,""]];if (_independent && {!(_meta isEqualType []) || {count _meta!=2} || {!((_meta#0) isEqualType true)} || {!((_meta#1) isEqualType "")} || {count (_meta#1)>64}}) then {_valid=false;};
  private _row=(_shops#_side) findIf {(_x#0)==_class};
  if (_row<0 || {!([_pos#0,500,_world-500] call _number)} || {!([_pos#1,500,_world-500] call _number)} || {!([_pos#2,0,5000] call _number)} || {!([_dir,0,360] call _number)} || {!([_damage,0,.99] call _number)} || {!([_fuel,0,1] call _number)}) then {_valid=false;} else {
   private _kind=((_shops#_side)#_row)#1;if (_independent && {_kind!=0 || {!((_meta#0) isEqualTo (count _crew>0))}}) then {_valid=false;};private _key=[_side,_parent,_kind];
   private _drone=(((_shops#_side)#_row)#3)=="UAV" || {((_shops#_side)#_row) param [4,false]};
   private _artillery=(((_shops#_side)#_row)#3) in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS","AAA","SAM","RADAR","STATIC"];
   if (_key in _seen && {!_independent} && {!(!_ai && {_artillery})} || {count _crew>(if (_independent) then {8} else {2})} || {_crew findIf {!(_x isEqualType "") || {!(_x in (_infantry#_side))}}>=0} || {_kind==0 && {!_artillery} && {!(((_shops#_side)#_row)#3 in ["CAR","APC","TANK"])} && {count _crew>0} && {!_independent}} || {_kind==1 && {_ai} && {!_drone} && {count _crew<1}} || {_artillery && {_ai} && {!_drone} && {count _crew<1}} || {!_ai && {count _crew>0}} || {_drone && {count _crew>0}} || {!([_x#9,_x#10] call NeroOP_fnc_campaignAmmoSnapshot)}) then {_valid=false;} else {
    _seen pushBack _key;(_counts#_side) set [_kind,((_counts#_side)#_kind)+1];
    if (!_independent && {(_kind==1 || {_artillery} || {count _crew>0}) && {_ai} && {!_drone}}) then {_loans pushBack [_side,_parent,count _crew];};
   };
  };
 };
};} forEach _fleet;
private _over=[0,1] findIf {private _n=_counts#_x;(_n#0)>(_limits#0) || {(_n#1)>(_limits#1)} || {(_n#0)+(_n#1)>(_issued#_x)}};
if (!_valid || {_over>=0}) exitWith {false};
/* A split pilot roster cannot duplicate the original ground squad. */
{private _side=_x#0;private _parent=_x#1;private _crew=0;{if ((_x#0)==_side && {(_x#1)==_parent}) then {_crew=_crew+(_x#2);};} forEach _loans;
 private _g=_groups findIf {count _x>=6 && {(_x#0)==_side} && {(_x#5)==_parent}};private _ground=if (_g>=0) then {count ((_groups#_g)#3)} else {0};private _paid=_recruits findIf {(_x#0)==_side && {(_x#1)==_parent}};private _extra=if (_paid<0) then {0} else {(_recruits#_paid)#2};if (_ground+_crew>(((_sizes#_side)+_extra) min 12)) then {_valid=false;};
} forEach _loans;
for "_side" from 0 to 1 do {private _total=0;{if ((_x#0)==_side) then {_total=_total+count (_x#3);};} forEach _groups;{if ((_x#0)==_side) then {_total=_total+(_x#2);};} forEach _loans;private _extra=0;{if ((_x#0)==_side) then {_extra=_extra+(_x#2);};} forEach _recruits;if (_total>(_groupIssued#_side)*(_sizes#_side)+_extra) then {_valid=false;};};
_valid
