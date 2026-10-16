"use strict";
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const editor=require('../control-center/warlords-editor'),core=require('../control-center/core'),lm=require('../bridge/lm-studio'),protocol=require('../bridge/protocol');
const state={nodes:[{id:'mac',baseUrl:'http://127.0.0.1:1234/v1'}]};
const selection={scenario:'warlords',mode:'single',primaryNode:'mac',primaryModel:'model',temperature:.9,maxTokens:900,profile:'donko',map:'Australia',dev:true,ace:true,parameters:{},commanders:16,instructions:'Разведка перед наступлением'};
test('16 slots and instructions survive config generation; excessive counts/text fail',()=>{
 const s=core.validate(selection,state);assert.equal(s.commanders,16);
 assert.throws(()=>core.validate({...selection,commanders:17},state));
 assert.throws(()=>core.validate({...selection,instructions:'x'.repeat(3001)},state));
 const cfg=core.makeConfig(s,state,{lmStudio:{},transport:{}});
 const msg=lm.buildRequestPayload(cfg,'[]').messages.find(m=>m.content.includes(selection.instructions));assert(msg);assert.equal(msg.role,'user');
});
test('requested equipment exists and remains on its native side',()=>{
 const d=editor.defaults();for(const id of ['F4E_BLU','F16C_BLU','TT_Merkava_Mk4M','CUP_B_Leopard2A6_GER','CUP_B_FV510_GB_W'])assert(d.westAssets.includes(id));
 for(const id of ['rhs_t80bv','rhs_t72bd_tv','rhs_t14_tv','CUP_O_T90M_RU','CUP_O_SU34_RU','JS_JC_SU35'])assert(d.eastAssets.includes(id));
 assert.throws(()=>editor.validate({...d,westAssets:['rhs_t14_tv']}));assert.throws(()=>editor.validate({...d,eastAssets:['missing_class']}));assert.throws(()=>editor.validate({...d,eastFaction:'rhs_faction_usarmy_d'}));
 const cfg=require('../tools/validate-mission').parseConfig(editor.preset(d));assert.equal(cfg.classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.WEST.classes.Aircraft.classes.F16C_BLU.values.NeroWL_role,'JET_FIGHTER');
 const inventory=editor.inventory();for(const [side,ids] of [[1,d.westAssets],[0,d.eastAssets]])assert(ids.some(id=>inventory.assets.some(a=>a.class===id&&a.kind==='HELICOPTER'&&a.cargo>=13&&a.side===side)));
});
test('roles and air missions pass validated data only; executable and unknown arguments fail',()=>{
 for(const [type,support,position] of [['ASSIGN_ROLE','AIR_SUPERIORITY',[]],['AIR_TASK','TRANSPORT',[1000,2000]],['BUY','PLANE',[]]]){const r=protocol.validateModelResponse(JSON.stringify({version:3,speech:'Принял',actions:[{type,support,position,roe:''}]}));assert.equal(r.actions.length,1);}
 for(const support of ['DELETE_ALL','compile','AIR_TRANSPORT; call bad']){const r=protocol.validateModelResponse(JSON.stringify({version:3,speech:'Принял',actions:[{type:'ASSIGN_ROLE',support,position:[],roe:''}]}));assert.equal(r.actions.length,0);}
 const macro=fs.readFileSync('addons/NeroAI3/functions/core/fn_executeMacro.sqf','utf8'),dispatch=fs.readFileSync('addons/NeroAI3/functions/core/fn_dispatchResponse.sqf','utf8');
 for(const text of [macro,dispatch])assert(text.includes('["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"]'));
});
test('RAP int64 scalar retains alignment and rejects truncated values',()=>{
 const header=Buffer.alloc(16);header.write('\0raP',0,'latin1');const val=Buffer.alloc(8);val.writeBigInt64LE(8500n);
 const fixture=Buffer.concat([header,Buffer.from([0,1,1,6]),Buffer.from('cost\0'),val]);const {decodeRap}=require('../tools/read-world-config');assert.equal(decodeRap(fixture).values.cost,8500);assert.throws(()=>decodeRap(fixture.subarray(0,-2)));
});
