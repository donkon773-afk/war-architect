"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),os=require("node:os"),path=require("node:path");
const core=require("../control-center/core"),editor=require("../control-center/warlords-editor"),journal=require("../control-center/journal");
const state={nodes:[{id:"main",model:"m",baseUrl:"http://127.0.0.1:1234/v1"},{id:"allies",model:"a",baseUrl:"http://127.0.0.1:1235/v1"}]};
const selected={scenario:"warlords",mode:"single",primaryNode:"main",primaryModel:"m",temperature:.9,maxTokens:900,profile:"donko",map:"Australia",dev:true,ace:true,parameters:{NeroWL_WestGarrison:6,NeroWL_EastGarrison:12,NeroWL_GreenGarrison:0,NeroWL_FriendlyLLM:2,NeroWL_FriendlyLimit:4},allyRoute:"separate",allyNode:"allies",allyModel:"a"};
test("uniform candidate filtering excludes weapons while preserving public uniform classes",()=>{
 const {adapt}=require("../tools/adapt-vars-init"),native=fs.readFileSync("research/native/Warlords/fn_WLVarsInit.sqf","utf8"),out=adapt(native);
 assert(out.includes("'type') == 801"));assert(out.includes("'uniformClass') != ''"));
 assert(out.includes('player isUniformAllowed configName _x'));assert(out.includes('native variables finished'));
 assert.throws(()=>adapt("changed"),/scan changed/);
 const candidates=[{scope:2,type:801,uniformClass:'soldier'},{scope:2,type:1},{scope:1,type:801,uniformClass:'soldier'},{scope:2,type:801,uniformClass:''}];
 assert.deepEqual(candidates.filter(x=>x.scope===2&&x.type===801&&!!x.uniformClass),[candidates[0]]);
});
test("tracked IFVs and MBTs in installed catalog retain distinct purchase roles",()=>{
 const x=editor.inventory();
 for(const id of ['rhs_bmp2_msv','cup_b_m3a3bradleycfv_usa_d']){const a=x.assets.find(a=>a.class.toLowerCase()===id);assert(a,id);assert.equal(a.kind,'APC',id);}
 for(const id of ['rhs_t80bv','rhs_t72bd_tv','rhs_t14_tv']){const a=x.assets.find(a=>a.class.toLowerCase()===id);assert(a,id);assert.equal(a.kind,'TANK',id);}
});
test("native purchase availability binds a local category and rejects incomplete asset rows",()=>{
 const {adapt}=require('../tools/adapt-purchase-availability');
 const s=fs.readFileSync('research/native/Warlords/fn_WLSubroutine_purchaseMenuAssetAvailability.sqf','utf8');
 const o=adapt(s);assert(o.includes('private _category = _assetDetails param [5,"",[""]]'));
 assert(o.includes('exitWith {_ret=FALSE;'));assert(o.includes('BIS_fnc_WLSubroutine_purchaseMenuHandleDLC'));
 assert.throws(()=>adapt('incompatible'),/source changed/);
});
test("city caps and separate allied route are validated and bound without changing enemy route",()=>{
 const cfg=core.makeConfig(selected,state,{lmStudio:{},transport:{}});
 assert.equal(cfg.lmStudio.model,"m");assert.equal(cfg.lmStudio.sides.ALLIED.model,"a");
 assert.equal(require("../bridge/lm-studio").effectiveLmConfig(cfg,'["side","BLUE","playerSide","BLUE"]').lm.model,"a");
 assert.equal(require("../bridge/lm-studio").effectiveLmConfig(cfg,'["side","RED","playerSide","BLUE"]').lm.model,"m");
 assert.throws(()=>core.validate({...selected,parameters:{NeroWL_GreenGarrison:7}},state));
 assert.throws(()=>core.validate({...selected,allyNode:"missing"},state));
 const shared=core.makeConfig({...selected,allyRoute:"shared"},state,{lmStudio:{sides:{ALLIED:{model:"stale"}}},transport:{}});assert.equal(shared.lmStudio.sides.ALLIED.model,"m");
});
test("all vehicle categories can be selected and appear in the correct native shop category",()=>{
 const x=editor.inventory(),army=editor.defaults();
 for(const [kind,category] of [["SHIP","Naval"],["STATIC","Defences"]]){
  const a=x.assets.find(a=>a.kind===kind&&a.side===1);assert(a);
  army.westAssets.push(a.class);const cfg=require("../tools/validate-mission").parseConfig(editor.preset(army));assert(cfg.classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.WEST.classes[category].classes[a.class]);
 }
 assert(x.mods.length>=18);assert.equal(x.errors.length,0);
});
test("journal is bounded, redacts secrets, and skips an incomplete first line",()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),"nerowl-journal-")),file=path.join(dir,"test.log");
 try{fs.writeFileSync(file,"first partial long line\nsecond complete\n");assert.equal(journal.tail(file,18),"second complete\n");assert.equal(journal.redact("Bearer token secret-value",["secret-value"]),"Bearer [hidden] [hidden]");assert.equal(journal.tail(path.join(dir,"missing")),"");}finally{fs.rmSync(dir,{recursive:true});}
});
test("garrison adaptation preserves native source when uncapped and caps only spawned defenders",()=>{
 const source=fs.readFileSync("research/native/Warlords/fn_WLSectorPopulate.sqf","utf8"),{adapt}=require("../tools/adapt-garrison"),result=adapt(source);
 assert(result.includes('getNumber (missionConfigFile >> "NeroWL_personalScenario") == 1'));
 assert(result.includes('_neroUsed+_neroCrew<=_neroCap'));assert(result.includes('3 min (_neroCap-_neroUsed)'));
 assert(result.includes('RESISTANCE && {_neroCap<0}'));assert(result.includes('BIS_fnc_WLGarrisonRetreat'));assert(!result.includes('forEach allUnits'));
 assert.throws(()=>adapt(source.replace('_sentriesTotal = 60 * _trgSizeIndex;','')),/changed/);
});
