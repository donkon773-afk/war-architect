'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..'),base=path.join(root,'addons/NeroAI3/functions');
test('production logistics decisions execute with fake time and cancellation; integrations parse',()=>{
 const r=require('../tools/verify-logistics-sqf').verify();assert.equal(r.parsedFiles,17);assert.equal(r.parsedIntegrationFiles,5);assert.equal(r.executedPureFunctions.length,6);assert(r.assertions>=38);
});
test('logistics functions are registered and native generated delivery keeps base routing',()=>{
 const files=fs.readdirSync(path.join(base,'logistics')).filter(n=>/^fn_.*\.sqf$/.test(n)).map(n=>n.slice(3,-4)).sort(),cfg=fs.readFileSync(path.join(base,'CfgFunctions.hpp'),'utf8'),block=cfg.slice(cfg.indexOf('class logistics {'),cfg.indexOf('class frontline {'));
 assert.deepEqual([...block.matchAll(/class (\w+) \{\};/g)].map(m=>m[1]).sort(),files);
 const raw=fs.readFileSync(path.join(root,'research/native/Warlords/fn_WLAirdrop.sqf'),'latin1'),generated=fs.readFileSync(path.join(base,'native/fn_WLAirdrop.sqf'),'latin1');assert.equal(require('../tools/adapt-airdrop').adapt(raw),generated);
 assert(generated.includes('if (!_neroGround && {isNull _neroFlight}) then {_item attachTo [_para, _bBoxCenter];};'));
 assert(generated.includes('if (_neroGround || {!isNull _neroFlight}) then {_finalPos} else {position (_this # 0)}'));
 const purchases=fs.readFileSync(path.join(root,'research/native/Warlords/fn_WLAIPurchases.fsm'),'utf8');assert.equal(require('../tools/adapt-ai-purchases').adapt(purchases),fs.readFileSync(path.join(base,'native/fn_WLAIPurchases.fsm'),'utf8'));
});
