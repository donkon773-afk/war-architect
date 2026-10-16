'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
test('production combat SQF parses and position, repair cancellation, priorities and dismount decisions execute',()=>{
 const r=require('../tools/verify-combat-sqf').verify();assert.equal(r.parsedFiles,17);assert.equal(r.parsedIntegrationFiles,8);assert.equal(r.executedPureFunctions.length,6);assert(r.assertions>=40);
});
test('all combat functions are registered in the addon',()=>{
 const root=path.join(__dirname,'..','addons','NeroAI3','functions'),files=fs.readdirSync(path.join(root,'combat')).filter(f=>/^fn_.*\.sqf$/.test(f)).map(f=>f.slice(3,-4)).sort();
 const cfg=fs.readFileSync(path.join(root,'CfgFunctions.hpp'),'utf8'),block=cfg.slice(cfg.indexOf('class combat {'),cfg.indexOf('class mobility {'));
 assert.deepEqual([...block.matchAll(/class (\w+) \{\};/g)].map(m=>m[1]).sort(),files);
});
