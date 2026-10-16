"use strict";
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const read=name=>fs.readFileSync(path.join(__dirname,'../addons/NeroAI3/functions',name),'utf8');
test('rejected autonomous movement returns before any route or template can start',()=>{
 const s=read('core/fn_executeMacro.sqf');
 assert(s.indexOf('if (_moveGuardResult isNotEqualTo []) exitWith {_moveGuardResult}')<s.indexOf('private _result ='));
 assert(s.includes('_moveGuardResult = [false, _why]'));
 assert(s.indexOf('private _moveGuardResult = []')<s.indexOf('if (_tooClose || _repeat)'));
});
test('LAMBS handoff invalidates and terminates tracked routes before launching a task',()=>{
 const s=read('tactical/fn_tacticOrder.sqf'),stop=read('tactical/fn_routeStop.sqf');
 assert(s.indexOf('_epoch = [_group] call NeroAI_fnc_routeStop')<s.indexOf('private _task = switch'));
 for(const field of ['NeroWL_routeEpoch','NeroWL_routeMovers','NeroWL_pathAgent','NeroWL_pathKey'])assert(stop.includes(field),field);
 assert(stop.includes('terminate _handle'));
 assert.doesNotMatch(stop,/allUnits|vehicles select|deleteWaypoint|deleteGroup/);
});
test('an obsolete route cannot clear the new movement owner on completion',()=>{
 const s=read('tactical/fn_vehicleRoute.sqf'),tail=s.slice(s.indexOf('if (_state == "") then'));
 const guard=tail.indexOf('if (_state == "CANCELLED" || {(_group getVariable ["NeroWL_routeEpoch",0]) != _epoch}) exitWith');
 assert(guard>=0 && guard<tail.indexOf('"lambs_danger_disableGroupAI",_danger # 0'), 'obsolete worker cannot restore group flags');
 assert.match(tail,/NeroWL_motionOwner[\s\S]*isEqualTo \[_group,_epoch\][\s\S]*call NeroAI_fnc_motionRestore/, 'vehicle restoration requires the same owner');
 assert(s.includes('deleteVehicle _agent'));
 assert(s.includes('!(call _current) || {diag_tickTime > _t}'));
});
test('cancelling a template restores the prior mission AI flags and group attack permission',()=>{
 const s=read('tactical/fn_tacticOrder.sqf'),stop=read('tactical/fn_tacticStop.sqf');
 assert(s.includes('"AUTOCOMBAT"'));assert(s.includes('_unit checkAIFeature _x'));assert(s.includes('attackEnabled _group'));
 assert(stop.includes('_group enableAttack (_restore # 0)'));assert(stop.includes('_unit enableAIFeature _x'));
 assert(stop.includes('group _unit isEqualTo _group'));assert(stop.includes('!isPlayer _unit'));
});
test('defensive positioning has one cancelable worker and preserves native group waypoints',()=>{
 const order=read('tactical/fn_tacticOrder.sqf'),defend=read('tactical/fn_tacticDefend.sqf');
 for(const kind of ['GARRISON','DEFEND'])assert.match(order,new RegExp(`case "${kind}".*spawn NeroAI_fnc_tacticDefend`));
 assert.doesNotMatch(defend,/CBA_fnc|deleteWaypoint|addWaypoint|createGroup|setPos|setVehiclePosition/);
 assert(defend.includes('NeroWL_routeEpoch'));assert(defend.includes('sleep 3'));
});
test('foot templates order cargo out without ejecting vehicle crews',()=>{
 const s=read('tactical/fn_tacticOrder.sqf');
 assert(s.includes('(assignedVehicleRole _x param [0, ""]) isEqualTo "cargo"'));
 assert.doesNotMatch(s,/"DISEMBARK"\] call NeroAI_fnc_vehicleTactics/);
});
test('air transport requires the same operation, route and logistics lease before resuming the target',()=>{
 const s=read('tactical/fn_airTransport.sqf'),current=s.match(/private _current = \{[^\n]+/)[0];
 for(const field of ['NeroAI_opToken','NeroWL_routeEpoch','NeroWL_transportLease'])assert(current.includes(field),field);
 assert(s.includes('private _guard={(call _current)'));
 assert(s.includes('if ((call _current) && {(call _aboard)==0}) then'));
 assert(s.includes('"NeroWL_logisticsUntil",0]) isEqualTo _leaseUntil'));
 assert(s.includes('"NeroWL_transportScript",_handle'));
});
test('repeated autonomous movement retains a live matching route while player orders still interrupt',()=>{
 const s=read('core/fn_executeMacro.sqf'),reuse=s.slice(s.indexOf('private _reuseRoute = false'),s.indexOf('if (_type in ["ADVANCE","ASSAULT"'));
 assert(reuse.includes('_autonomousSource'));assert(reuse.includes('"ADVANCE","RETREAT"'));
 assert(reuse.includes('"NeroWL_routeOrderType",""'));assert(reuse.includes('"NeroWL_tactic",[]'));
 assert(reuse.includes('scriptDone _handle'));assert(reuse.includes('"NeroWL_routeEpoch",-1'));
 assert(reuse.includes('_target distance2D _position >= 60'));
 assert(s.indexOf('if (_reuseRoute) exitWith')<s.indexOf('[_group] call NeroAI_fnc_tacticStop;'));
});
