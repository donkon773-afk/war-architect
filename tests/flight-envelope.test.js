'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),{resolve,profiles}=require('../tools/flight-profiles');
test('aircraft families and propulsion stay distinct',()=>{
 for(const p of profiles){assert(p[3]>0&&p[4]>=p[3]);assert(p[6]>=p[3]&&p[6]<=p[4]);}
 assert.equal(resolve('rhsusf_f22').id,'F22');assert.equal(resolve('CUP_B_F35B_USMC').id,'F35');assert.equal(resolve('UK3CB_ARD_B_MIG21').id,'MIG21');assert.equal(resolve('RHS_TU95MS_vvs_old').afterburner,false);assert.equal(resolve('CUP_B_L39ZA').id,'L39ZA');assert.equal(resolve('RHS_T50_vvs_generic').id,'T50');assert.equal(resolve('UnknownAircraft'),null);
});
test('vanilla speed bonuses apply to ordinary/stealth/loadout variants, never RHS or CUP prototypes',()=>{
 for(const [name,max,bonus] of [['B_Plane_CAS_01_dynamicLoadout_F',856,150],['O_Plane_CAS_02_dynamicLoadout_F',1260,200],['I_Plane_Fighter_03_dynamicLoadout_F',1136,200],['B_Plane_Fighter_01_F',2420,300],['B_Plane_Fighter_01_Stealth_F',2420,300],['O_Plane_Fighter_02_F',2740,350],['O_Plane_Fighter_02_Stealth_F',2740,350],['I_Plane_Fighter_04_F',2420,300],['C_Plane_Civil_01_F',585,150]]){const p=resolve(name);assert.equal(p.maximum,max);assert.equal(p.bonus,bonus);assert.equal(p.maximum,p.referenceMaximum+p.bonus);}
 for(const name of ['RHS_A10','rhs_l159_CDF','CUP_B_JAS39_HIL','rhsusf_f22','JS_JC_SU35'])assert.equal(resolve(name).bonus,undefined);
 assert.equal(resolve('B_Plane_CAS_01_dynamicLoadout_F').afterburner,false);
});
test('real SQF pure envelope: fuel, dt, cap, native boost and ground/engine guards',()=>{
 const folder=fs.mkdtempSync(path.join(os.tmpdir(),'nero-flight-'));try{
  for(const f of ['init','step'])fs.copyFileSync(path.join(root,'tools/flight-assets/fn_'+f+'.sqf'),path.join(folder,'fn_'+f+'.sqf'));
  const script='NeroFlight_fnc_step={'+fs.readFileSync(path.join(folder,'fn_step.sqf'),'utf8')+'};\n'+`
private _check={params ["_ok"];if (!_ok) then {throw "flight assertion failed";};};
private _r=[300,300,.1,900,1800,true,1,true,true,.5,.0001] call NeroFlight_fnc_step;
[_r#0>0 && {_r#2>0} && {_r#3>1}] call _check;
private _cruise=[250,250,.1,900,900,false,1,true,true,.5,.0001] call NeroFlight_fnc_step;
[_cruise isEqualTo [0,0,0,1]] call _check;
private _native=[301,300,.1,900,1800,true,1,true,true,.5,.0001] call NeroFlight_fnc_step;
[_native#0==0] call _check;
private _cap=[510,510,.1,900,1800,true,1,true,true,.5,.0001] call NeroFlight_fnc_step;
[_cap#0==0 && {_cap#1>0} && {_cap#1<=.6}] call _check;
{private _input=[300,300,.1,900,1800,true,1,true,true,.5,.0001];_input set [_x#0,_x#1];private _g=_input call NeroFlight_fnc_step;[_g#0==0] call _check;} forEach [[5,false],[6,.5],[7,false],[8,false],[9,0]];
private _a=[300,300,.1,900,1800,true,1,true,true,.5,.0001] call NeroFlight_fnc_step;
private _b=[300,300,.2,900,1800,true,1,true,true,.5,.0001] call NeroFlight_fnc_step;
[abs((_b#2)-2*(_a#2))<.000001] call _check;
diag_log "FLIGHT_TEST_OK";`;
  fs.writeFileSync(path.join(folder,'test.sqf'),script);const vm=path.join(root,'tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
  for(const args of [['--parse-only','--input-sqf','fn_init.sqf','--input-sqf','fn_step.sqf'],['--input-sqf','test.sqf']]){const r=cp.spawnSync(vm,['-a','--suppress-welcome',...args],{cwd:folder,encoding:'utf8',windowsHide:true,timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);if(args[0]!=='--parse-only')assert.match(r.stdout+r.stderr,/FLIGHT_TEST_OK/);}
 }finally{fs.rmSync(folder,{recursive:true,force:true});}
});
