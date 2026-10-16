'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
test('generated delivery position survives the planned-ground and aircraft branches in SQF',()=>{
 const source=fs.readFileSync(path.join(root,'addons/NeroAI3/functions/native/fn_WLAirdrop.sqf'),'latin1');
 const start=source.indexOf('\tprivate _finalPos = [];'),end=source.indexOf('\t_para = objNull;',start);
 assert(start>=0&&end>start);
 const block=source.slice(start,end).replaceAll('isNull _neroFlight','(_neroFlight == 0)').replaceAll('getPosATL _neroFlight','[30,40,0]');
 let script='';
 for(const [flight,planned,expected] of [[0,[[10,20,0]],[10,20,0]],[1,[],[30,40,0]]]){
  script+=`call {private _neroFlight=${flight};private _neroPlanned=${JSON.stringify(planned)};private _forEachIndex=0;${block}\nif (isNil "_finalPos") then {throw "position lost";};if !(_finalPos isEqualTo ${JSON.stringify(expected)}) then {throw "position wrong";};};\n`;
 }
 const fsm=fs.readFileSync(path.join(root,'addons/NeroAI3/functions/native/fn_WLAICore.fsm'),'latin1'),adapt=require('../tools/adapt-frontline');
 script+='BIS_fnc_WLSyncedTime={0};BIS_WL_selectionTimeout=10;\n';
 for(const [name,variable] of [['fight','_tFight'],['run_timer','_tVoting'],['run_timer_1','_tFT'],['reset_var__run_t','_tDebrief'],['nothing_1','_tVLost']]){
  const start=fsm.indexOf(`/*%FSM<STATE "${name}">*/`),state=fsm.slice(start,fsm.indexOf('/*%FSM</STATE>*/',start));
  const raw=state.match(/\/\*%FSM<STATEINIT""">\*\/([\s\S]*?)\/\*%FSM<\/STATEINIT""">\*\//);
  const code=adapt.decode(raw[1]).replace(/if \(!\(\(\(group _this\)[\s\S]*?then \{/,'if (false) then {');
  assert(code.includes('if (false) then {'));
  script+=`call {${code}\nif (isNil "${variable}") then {throw "FSM timer lost: ${variable}";};};\n`;
 }
 script+='diag_log "PURCHASE_SCOPE_OK";';
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-purchase-scope-'));
 try{
  fs.writeFileSync(path.join(dir,'scope.sqf'),script);
  const vm=path.join(root,'tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
  fs.writeFileSync(path.join(dir,'broken.sqf'),script.replaceAll('private _finalPos = [];',''));
  const broken=cp.spawnSync(vm,['-a','--suppress-welcome','--max-runtime','5000','--input-sqf','broken.sqf'],{cwd:dir,encoding:'utf8',timeout:15000,windowsHide:true});
  const brokenOutput=(broken.stdout||'')+(broken.stderr||'');
  assert.match(brokenOutput,/position lost/,'the regression test must detect the original scope failure');
  assert(!brokenOutput.includes('PURCHASE_SCOPE_OK'));
  const result=cp.spawnSync(vm,['-a','--suppress-welcome','--max-runtime','5000','--input-sqf','scope.sqf'],{cwd:dir,encoding:'utf8',timeout:15000,windowsHide:true});
  const output=(result.stdout||'')+(result.stderr||'');
  assert.equal(result.status,0,output);assert(!/\[(ERR|FAT)\]/.test(output),output);assert.match(output,/PURCHASE_SCOPE_OK/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
