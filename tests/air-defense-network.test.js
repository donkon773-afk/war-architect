'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {parseConfig}=require('../tools/validate-mission'),equipment=require('../control-center/campaign-equipment');
test('stationary config uses derived classes, limited local sensors, no mobile patches and preserves ammo stocks',()=>{
 const mods=JSON.parse(fs.readFileSync(path.join(__dirname,'../control-center/data/operations-launch.json'),'utf8')).mods;
 const result=require('../tools/build-air-defense-addon').prepare(mods),cfg=parseConfig(result.config,{rejectDuplicateDeclarations:true}),defs=cfg.classes.CfgNeroAirDefense.classes;
 assert.equal(cfg.classes.CfgNeroAirDefense.values.linkRadius,3000);assert.ok(result.stationaryVariants>10);
 for(const id of ['B_SAM_System_03_F','O_SAM_System_04_F']){const d=defs[id].values,v=cfg.classes.CfgVehicles.classes[d.spawnClass];assert.equal(d.missileRange,5000);assert.equal(v.parent,id);assert.equal(v.classes.Components.classes.SensorsManagerComponent.classes.Components.classes.ActiveRadarSensorComponent.classes.AirTarget.values.maxRange,5500);}
 for(const id of ['O_APC_Tracked_02_AA_F','CUP_O_2S6_RU','rhs_zsu234_aa']){assert.equal(defs[id].values.stationary,0);assert.equal(defs[id].values.spawnClass,id);assert.equal(cfg.classes.CfgVehicles.classes[id],undefined);}
 assert.equal(cfg.classes.CfgMagazines.classes.NeroAD_B_ace_missile_sam_patriot.values.count,undefined);assert.equal(cfg.classes.CfgMagazines.classes.NeroAD_R_ace_missile_sam_patriot.values.count,undefined);
 assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_R_ace_missile_sam_patriot.values.missileLockMaxDistance,50000);
 for(const d of Object.values(defs).filter(d=>d.values.stationary===1 && d.values.category==='AAA' && d.values.gunRange>0 && d.values.magazinePairs.length===0)){assert.equal(d.values.localRange,d.values.gunRange);assert.equal(d.values.missileRange,0);}
 assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_R_ace_missile_sam_patriot.values.timeToLive,180);assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_R_ace_missile_sam_patriot.values.maneuvrability,24);assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_R_ace_missile_sam_patriot.classes.ace_missileguidance.values.enabled,0);assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_R_ace_missile_sam_patriot.values.manualControl,0);
 assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_AheadFragment.values.indirectHit,0);assert.equal(cfg.classes.CfgAmmo.classes.NeroAD_AheadFragment.values.timeToLive,.6);
});
test('defense catalog recognizes gun CIWS and excludes counter-mortar and airborne radar from ground radar role',()=>{
 const c=equipment.catalog();for(const id of ['B_AAA_System_01_F','E22_B_JC_W_AAA_System_01_F'])assert.equal(c.find(x=>x.class===id).category,'AAA');
 assert.equal(c.find(x=>x.class==='b_afougf_lcmr_radar').category,'STATIC');assert.equal(c.find(x=>x.class==='UK3CB_CSAT_F_O_Bell412_Radar').category,'HELICOPTER');
});

test("config parser retains numeric class names and scientific numeric values",()=>{const c=parseConfig("class 1Rnd_Test {a=1e-10;b=1e10;};");assert.equal(c.classes["1Rnd_Test"].values.a,1e-10);assert.equal(c.classes["1Rnd_Test"].values.b,1e10);});

test("generated addon validator rejects the engine-fatal repeated forward class declaration",()=>{assert.throws(()=>parseConfig("class CfgAmmo {class M_Titan_AA_static;class M_Titan_AA_static;};",{rejectDuplicateDeclarations:true}),/Duplicate class declaration/);assert.doesNotThrow(()=>parseConfig("class CfgAmmo {class Parent;class Child:Parent {};};",{rejectDuplicateDeclarations:true}));});

test("derived weapons avoid unresolved nested Player bases and native vehicle turrets and parents remain unmodified",()=>{const mods=JSON.parse(fs.readFileSync(path.join(__dirname,"../control-center/data/operations-launch.json"))).mods;const a=require("../tools/build-air-defense-addon").prepare(mods),cfg=parseConfig(a.config,{rejectDuplicateDeclarations:true});assert.equal(cfg.classes.CfgWeapons.classes.NeroAD_W_missiles_titan_static.classes.Player.parent,"");for(const [name,w]of Object.entries(cfg.classes.CfgWeapons.classes).filter(([n])=>n.startsWith("NeroAD_W_")))for(const mode of Object.values(w.classes))assert.equal(mode.parent,"");for(const [name,v]of Object.entries(cfg.classes.CfgVehicles.classes).filter(([n])=>n.startsWith("NeroAD_V_"))){assert.equal(v.classes.Turrets,undefined);assert.equal(cfg.classes.CfgVehicles.classes[v.parent]._forward,true);}assert(!cfg.classes.CfgPatches.classes.NeroAirDefense.values.requiredAddons.some(x=>x.startsWith("jsrs")));});
