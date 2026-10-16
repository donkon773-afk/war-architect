params[["_unit",objNull,[objNull]],["_target",objNull,[objNull]],["_id","",[""]]];
if(!isServer || {isNull _unit} || {!alive _unit} || {!isPlayer _unit} || {!(_unit in (missionNamespace getVariable["BIS_WL_allWarlords",[]]))})exitWith{};
if(isRemoteExecuted && {remoteExecutedOwner!=owner _unit})exitWith{};
if(!(["BEGIN",_unit,_id]call NeroWL_Design_fnc_cqRequest))exitWith{};
private _side=side group _unit;private _allowed=[_side]call NeroWL_Design_fnc_cqTargets;
private _key=format["NeroWL_CQvote_%1",_side];private _state=missionNamespace getVariable[_key,[0,objNull,0,0]];
if((_state#0)>0 && {serverTime>=(_state#0)})exitWith{["END",_unit,_id,[false,"Текущее голосование завершается. Подождите несколько секунд.",0]]call NeroWL_Design_fnc_cqRequest;};
private _result=[false,"Сектор недоступен для голосования вашей стороны.",0];
if(_target in _allowed)then{
 private _slot=[west,east,resistance]find _side;
 private _ballots=NeroWL_CQballots#_slot;private _uid=getPlayerUID _unit;
 private _index=_ballots findIf{(_x#1)==_unit || {_uid!="" && {(_x#0)==_uid}}};private _vote=[_uid,_unit,_target];
 if(_index<0)then{_ballots pushBack _vote;}else{_ballots set[_index,_vote];};
 NeroWL_CQballots set[_slot,_ballots];
 if((_state#0)<=0)then{_state=[serverTime+30,_target,1,1];};
 missionNamespace setVariable[_key,_state,true];
 _result=[true,format["Голос за «%1» принят. Выбор цели завершится через %2 с.",_target getVariable["Name",""],ceil((_state#0)-serverTime)],0];
};
["END",_unit,_id,_result]call NeroWL_Design_fnc_cqRequest;
