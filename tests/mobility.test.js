'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
test('production mobility SQF parses and fake-clock, authority, corridors and crew decisions execute',()=>{
 const r=require('../tools/verify-mobility-sqf').verify();assert.equal(r.parsedFiles,10);assert.equal(r.parsedIntegrationFiles,8);assert.equal(r.executedPureFunctions.length,5);assert(r.assertions>=23);
 assert.deepEqual(r.parserOnlyStubs,['isAISteeringComponentEnabled'],'engine-only command is explicitly a parser stub, not a simulation');
});
test('all mobility functions are registered in the addon',()=>{
 const root=path.join(__dirname,'..','addons','NeroAI3','functions'),files=fs.readdirSync(path.join(root,'mobility')).filter(f=>/^fn_.*\.sqf$/.test(f)).map(f=>f.slice(3,-4)).sort();
 const cfg=fs.readFileSync(path.join(root,'CfgFunctions.hpp'),'utf8'),block=cfg.slice(cfg.indexOf('class mobility {'),cfg.indexOf('class tactical {'));
 assert.deepEqual([...block.matchAll(/class (\w+) \{\};/g)].map(m=>m[1]).sort(),files);
});
