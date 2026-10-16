'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const campaign=require('../control-center/campaign-operations'),equipment=require('../control-center/campaign-equipment'),builder=require('../tools/build-campaign-operation'),validator=require('../tools/validate-campaign-operation');

test('installed binary ACE string tables resolve actual equipment names and reject truncation',()=>{const {readEntry}=require('../tools/read-pbo-entry'),{decode}=require('../tools/read-binary-stringtable'),ace=require('../control-center/operation-mods').catalog().find(m=>m.label==='@ace');assert(ace);const bytes=readEntry(path.join(ace.id,'addons/ace_realisticnames.pbo'),'stringtable.bin'),strings=decode(bytes);assert.equal(strings.str_ace_realisticnames_mrap_01_name,'M-ATV');assert.equal(equipment.catalog().find(c=>c.class==='B_MRAP_01_F').label,'M-ATV');assert.equal(equipment.gearCatalog().find(c=>c.class==='arifle_MX_F').label,'MX');assert.throws(()=>decode(bytes.subarray(0,100)));});

test('duplicate mission cleanup is recoverable and defers while Arma runs',()=>{const archive=require('../control-center/scenario-archive'),dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-scenario-archive-')),dest=path.join(dir,'backup');try{const source=path.join(__dirname,'../dist/operations/NeroAI_AirBattle_Australia_dcbe7e8f8a80.australia.pbo');assert(fs.existsSync(source));const old=path.join(dir,'NeroAI_old.australia.pbo'),latest=path.join(dir,'NeroAI_latest.australia.pbo');fs.copyFileSync(source,old);fs.copyFileSync(source,latest);fs.utimesSync(old,new Date(0),new Date(0));assert.equal(archive.cleanup({folder:dir,archiveRoot:dest,checkRunning:()=>true}).deferred,true);assert(fs.existsSync(old));const result=archive.cleanup({folder:dir,archiveRoot:dest,checkRunning:()=>false});assert.equal(result.archived.length,1);assert(fs.existsSync(latest));assert(!fs.existsSync(old));assert.deepEqual(fs.readFileSync(result.archived[0].archiveFile),fs.readFileSync(source));assert(fs.existsSync(path.join(result.archive,'manifest.json')));}finally{if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-scenario-archive-'))throw Error('Unsafe temp path');fs.rmSync(dir,{recursive:true,force:true});}});
test('installed faction inventory includes both kinds of artillery, UAV and soldier-derived compatible weapons',()=>{
 assert.equal(equipment.gearCatalog().find(g=>g.class==='rhs_weap_svdp').label,'СВДМ');assert.equal(equipment.gearCatalog().find(g=>g.class==='rhs_weap_svds').label,'СВДС');assert.equal(equipment.gearCatalog().find(g=>g.class==='rhs_weap_ak74m').label,'АК-74М');
 const d=campaign.defaults(),catalog=equipment.catalog();for(const a of d.sides){const cats=a.shop.map(r=>catalog.find(c=>c.class===r.class).category);for(const cat of ['PLANE','MLRS','ARTILLERY_STATIC','UAV'])assert.ok(cats.includes(cat),a.side+' '+cat);assert.ok(a.gear.some(r=>r.kind==='WEAPON'));assert.ok(a.gear.some(r=>r.kind==='MAGAZINE'));assert.ok(a.gear.some(r=>r.class=== (a.side==='WEST'?'B_UavTerminal':'O_UavTerminal')));}
 assert.ok(equipment.factions('WEST').length>1);assert.ok(equipment.factions('EAST').length>1);
});
test('server rejects free supplies, duplicate positions, foreign vehicles, fabricated gear and invalid purchase limits',()=>{
 const d=campaign.defaults(),bad=fn=>{const copy=structuredClone(d);fn(copy);assert.throws(()=>campaign.validate(copy));};
 bad(v=>v.sides[0].shop[0].price=0);bad(v=>v.sides[0].shop.push(v.sides[0].shop[0]));const mixed=structuredClone(d);mixed.sides[0].shop[0].class=d.sides[1].shop[0].class;assert.equal(campaign.validate(mixed).sides[0].shop[0].class,d.sides[1].shop[0].class);bad(v=>v.sides[0].gear[0].price=0);bad(v=>v.sides[0].gear[0].class='made_up_class');bad(v=>v.sides[0].gear.push(v.sides[0].gear[0]));bad(v=>v.equipment.pilots=3);bad(v=>v.equipment.cooldown=0);bad(v=>v.equipment.airLimit=13);bad(v=>v.equipment.aiPurchases='true');
});
test('canonical faction restricts infantry, equipment and goods; custom mixed side remains available',()=>{
 const d=campaign.defaults(),a=d.sides[0],f=equipment.factions('WEST').find(f=>f.id==='CUP_B_CDF');assert.ok(f);
 const canonical=equipment.canonical('WEST',f.id),truck=campaign.trucks().find(t=>equipment.catalog().some(c=>c.class===t.class&&c.faction===f.id));assert.ok(truck);
 Object.assign(a,canonical,{faction:f.id,truckClass:truck.class,groupSize:8});assert.equal(campaign.validate(d).sides[0].faction,f.id);
 a.shop.push({class:'JS_JC_FA18E',price:260});assert.throws(()=>campaign.validate(d),/фракци/);a.faction='';assert.equal(campaign.validate(d).sides[0].faction,'');
});
test('prices, settings and faction reach generated mission; tampered price is detected before installation',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-camp-shop-'));try{const d=campaign.defaults();d.sides[0].shop[0].price=173;builder.build(d,dir);assert.equal(validator.validate(dir).functions,require("../tools/build-campaign-operation").functions.length);const file=path.join(dir,'description.ext'),text=fs.readFileSync(file,'utf8');assert.match(text,/NeroOPCampaignShop/);assert.match(text,/import CfgRemoteExec as CfgRemoteExecMod/);fs.writeFileSync(file,text.replace('price=173;','price=174;'));assert.throws(()=>validator.validate(dir),/price/);}finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('full Zeus activates loaded addons early, has free edits, attributes and preserves native mod permissions',()=>{
 const common=path.join(__dirname,'../tools/operation-common'),prep=fs.readFileSync(path.join(common,'fn_zeusPrepare.sqf'),'utf8'),server=fs.readFileSync(path.join(common,'fn_zeusServer.sqf'),'utf8'),client=fs.readFileSync(path.join(common,'fn_zeusClient.sqf'),'utf8');assert.match(prep,/activateAddons.*CfgPatches/);assert.match(server,/addCuratorAddons activatedAddons/);assert.match(server,/removeAllCuratorEditingAreas/);assert.match(server,/removeAllCuratorCameraAreas/);assert.match(server,/"group","synchronize"/);assert.match(client,/%ALL/);assert.match(client,/BIS_fnc_showCuratorAttributes/);
});

test('vanilla remote config does not inherit a nonexistent top-level Functions class',()=>{
 const remote=require('../tools/operation-common/remote-config'),parse=require('../tools/validate-mission').parseConfig;
 const generated=remote.extend('class CfgRemoteExec {class Functions {mode=1;jip=0;};};',[]),cfg=parse(remote.parseable(generated));
 assert.equal(cfg.classes.CfgRemoteExec.parent,'CfgRemoteExecMod');assert.equal(cfg.classes.CfgRemoteExec.classes.Functions.parent,'');remote.verifyInheritance(cfg,[]);
 assert.throws(()=>remote.verifyInheritance(parse(remote.parseable(generated.replace('class Functions {','class Functions:Functions {'))),[]),/inheritance/);
});

test('RHS remote smoke and grenade effects retain their nested Functions base',()=>{
 const remote=require('../tools/operation-common/remote-config'),parse=require('../tools/validate-mission').parseConfig;
 const rhs=require('../control-center/warlords-editor').inventory().mods.find(m=>m.name==='@RHSAFRF');assert.ok(rhs);assert.equal(remote.modFunctionInheritance([rhs.path]),true);
 const generated=remote.extend('class CfgRemoteExec {class Functions {mode=1;jip=0;};};',[rhs.path]),cfg=parse(remote.parseable(generated));
 assert.equal(cfg.classes.CfgRemoteExec.classes.Functions.parent,'Functions');remote.verifyInheritance(cfg,[rhs.path]);
 assert.throws(()=>remote.verifyInheritance(parse(remote.parseable(generated.replace('class Functions:Functions {','class Functions {'))),[rhs.path]),/inheritance/);
});

test('native particle and environment modules permit persistent effects without persistent NeroOP actions',()=>{
 const remote=require('../tools/operation-common/remote-config'),parse=require('../tools/validate-mission').parseConfig;
 const cfg=parse(remote.parseable(remote.extend('class CfgRemoteExec {class Functions {mode=1;jip=0;class NeroOP_fnc_campaignEquipmentAction {allowedTargets=2;};};};',[]))).classes.CfgRemoteExec.classes.Functions;
 for(const fn of ['BIS_fnc_moduleEffectsFire','BIS_fnc_moduleEffectsSmoke','BIS_fnc_moduleEffectsBubbles','BIS_fnc_moduleEffectsPlankton','BIS_fnc_moduleEffectsShells','BIS_fnc_setDate','BIS_fnc_setFog','BIS_fnc_setOvercast','BIS_fnc_moduleSound','BIS_fnc_moduleHideTerrainObjects']){assert.equal(cfg.classes[fn]?.values.allowedTargets,0,fn);assert.equal(cfg.classes[fn]?.values.jip,1,fn);}
 assert.equal(cfg.values.jip,0);assert.equal(cfg.classes.BIS_fnc_debugConsoleExec.values.jip,0);assert.equal(cfg.classes.NeroOP_fnc_campaignEquipmentAction.values.jip,undefined);assert.equal(cfg.classes.BIS_fnc_execVM,undefined);assert.equal(cfg.classes.BIS_fnc_call,undefined);
 const root={classes:{CfgRemoteExec:{parent:'CfgRemoteExecMod',classes:{Functions:cfg}}}};remote.verifyInheritance(root,[]);cfg.classes.BIS_fnc_moduleEffectsSmoke.values.jip=0;assert.throws(()=>remote.verifyInheritance(root,[]),/persistence/);
});
test('new actor actions check server authority, physical supply, contact, crew and independent lifetime tickets',()=>{
 const read=n=>fs.readFileSync(path.join(__dirname,'../tools/campaign-assets/fn_'+n+'.sqf'),'utf8'),buy=read('campaignBuy'),gear=read('campaignGearBuy'),travel=read('campaignTravel'),loop=read('campaignEquipmentLoop');assert.match(read('campaignEquipmentAction'),/remoteExecutedOwner!=owner _unit/);assert.match(buy,/call NeroOP_fnc_campaignStock/);assert.match(gear,/call NeroOP_fnc_campaignStock/);assert.match(buy,/_crew joinSilent _flight/);assert.match(buy,/_count-2/);assert.match(gear,/clearWeaponCargoGlobal/);assert.match(gear,/addWeaponCargoGlobal/);assert.match(travel,/sleep 3/);assert.match(travel,/!call _check/);assert.match(travel,/allUnits findIf/);assert.match(read('campaignPlayerControl'),/remoteControlled/);assert.match(read('campaignPlayerControl'),/bis_fnc_moduleRemoteControl_owner/);assert.match(loop,/campaignService/);assert.doesNotMatch(loop,/setFuel 1|setVehicleAmmo 1/);
 assert.doesNotMatch(read('campaignClient'),/apply\s*\{[^}]*_forEachIndex/);assert.doesNotMatch(read('campaignRoad'),/apply\s*\{[^}]*_forEachIndex/);
 assert.doesNotMatch(read('campaignRoad'),/findIf\s*\{[^}]*_forEachIndex/);
});

test('laser designators are UAV support, SAM are actual missile systems and AI selection stays bounded',()=>{const c=equipment.catalog();assert.equal(c.find(c=>c.class==='B_Static_Designator_01_F').category,'UAV');assert.equal(c.find(c=>c.class==='B_SAM_System_01_F').category,'SAM');const rows=c.map(c=>({class:c.class,price:c.price})),plan=equipment.aiRows(rows);assert(plan.length<=4*new Set(c.map(c=>equipment.aiRole(c))).size);assert(plan.every(i=>i>=0&&i<rows.length));assert(new Set(plan).size===plan.length);});

test('AI shortlist retains bombers, escorts and both helicopter roles beyond the first plane entries',()=>{
 const catalog=equipment.catalog(),ids=['CUP_O_SU34_RU','JS_JC_SU35','RHS_TU95MS_vvs_dubna','RHS_Mi8mt_vdv','RHS_Mi24V_vdv'];
 const expected=['CAS','FIGHTER','BOMBER','TRANSPORT_HELI','ATTACK_HELI'];
 ids.forEach((id,i)=>assert.equal(equipment.aiRole(catalog.find(a=>a.class===id)),expected[i],id));
 const rows=[...Array.from({length:8},()=>({class:'CUP_O_SU34_RU',price:260})),...ids.slice(1).map(id=>({class:id,price:260}))];
 const plan=equipment.aiRows(rows).map(i=>rows[i].class);for(const id of ids.slice(1))assert(plan.includes(id));
 assert.equal(equipment.aiRole({class:'C130H',category:'PLANE',cargo:20}),'TRANSPORT_PLANE');
 assert.equal(equipment.aiRows([{class:'C130H',price:260}]).length,0);
 assert.equal(catalog.find(a=>a.class==='HAFM_Naval_MEKO')?.category,'SHIP');
});

test('installed Tu95 pylons belong to its weapon operator and accept conventional Kh55Sh ammunition',()=>{
 const {readEntry}=require('../tools/read-pbo-entry'),{decodeRap}=require('../tools/read-world-config');
 const rhs=require('../control-center/operation-mods').catalog().find(m=>m.label==='@RHSAFRF');assert(rhs);
 const cfg=decodeRap(readEntry(path.join(rhs.id,'addons/rhs_c_air.pbo'),'config.bin'));
 const plane=cfg.classes.CfgVehicles.classes.RHS_TU95MS_base,components=plane.classes.Components.classes;
 const pylons=components.TransportPylonsComponent.classes.pylons.classes;
 assert.deepEqual(pylons.pylon1.values.turret,[4]);assert.equal(pylons.pylon1.values.attachment,'rhs_mag_kh55sh');
 assert.equal(plane.classes.Turrets.classes.MainTurret.values.isCopilot,1);
 const weapons=decodeRap(readEntry(path.join(rhs.id,'addons/rhs_c_airweapons.pbo'),'config.bin'));
 assert.equal(weapons.classes.CfgAmmo.classes.rhs_ammo_kh55sh.values.RHS_WarheadType,'EXPLOSIVE');
 assert(weapons.classes.CfgWeapons.classes.rhs_weap_kh55sm_Launcher.values.magazines.includes('rhs_mag_kh55sh'));
});

test('individual recruit purchase joins the original squad through a server transaction and keeps save identity',()=>{
 const root=path.join(__dirname,'../tools/campaign-assets'),read=n=>fs.readFileSync(path.join(root,'fn_'+n+'.sqf'),'utf8'),action=read('campaignEquipmentAction'),recruit=read('campaignRecruit'),ui=read('campaignShopUI');
 assert.match(action,/remoteExecutedOwner!=owner _unit/);assert.match(action,/isNil.*NeroOP_fnc_campaignRecruit/);assert.match(recruit,/leader _group!=_unit/);assert.match(recruit,/NeroOP_fnc_campaignWarehouse/);assert.match(recruit,/_staging createUnit/);assert.match(recruit,/joinSilent _group/);assert.doesNotMatch(recruit,/setGroupOwner|deleteWaypoint|selectLeader|compile/);assert.match(ui,/Пехота в отряд/);assert.match(ui,/"RECRUIT",_forEachIndex,_price/);assert.match(read('campaignSave'),/_snapshot=\[5,/);assert.match(read('campaignInit'),/NeroOP_campRecruitCredits=.*_saved#14/);
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-camp-recruits-'));try{const d=campaign.defaults(),r=builder.build(d,dir),desc=require('../tools/validate-mission').parseConfig(require('../tools/operation-common/remote-config').parseable(fs.readFileSync(path.join(dir,'description.ext'),'utf8')));assert.equal(validator.validate(dir).functions,require("../tools/build-campaign-operation").functions.length);assert.ok(desc.classes.CfgFunctions.classes.NeroOP.classes.Campaign.classes.campaignRecruit);assert.equal(desc.classes.CfgRemoteExec.classes.Functions.classes.NeroOP_fnc_campaignRecruit,undefined);const renamed=builder.build({...d,title:d.title+' — новое название'},dir);assert.equal(renamed.missionGroup,r.missionGroup);}finally{fs.rmSync(dir,{recursive:true,force:true});}
});


test('full army presets retain every installed faction vehicle and all unit-derived equipment without the old truncation',()=>{
 const e=equipment;let total=0;for(const side of ['WEST','EAST'])for(const f of e.factions(side)){const p=e.fullArmy(side,f.id);assert(p.classes.length>0);assert.deepEqual(p.shop.map(r=>r.class).sort(),e.catalog().filter(a=>a.side===side&&a.faction===f.id).map(a=>a.class).sort());const expected=e.gearForUnits(f.infantry).filter(g=>!['Throw','Put'].includes(g.class));for(const g of expected)assert(p.gear.some(r=>r.class===g.class&&r.kind===g.kind));e.validateRows(p.shop,side,f.id);e.validateGear(p.gear,side,p.classes,f.id);total++;}assert(total>=150);
});

test('special weapons remain in the generated shop independently of faction while original saved design and identity remain intact',()=>{
 const d=campaign.defaults();d.sides.forEach(a=>a.shop=[]);const before=JSON.stringify(d),dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-special-build-'));try{const r=builder.build(d,dir),desc=require('../tools/validate-mission').parseConfig(require('../tools/operation-common/remote-config').parseable(fs.readFileSync(path.join(dir,'description.ext'),'utf8')));assert.equal(desc.classes.CfgNeroOperation.classes.WEST.classes.Shop.classes.Item0.values.className,'B_FP5_Launcher_F');assert.equal(desc.classes.CfgNeroOperation.classes.EAST.classes.Shop.classes.Item0.values.className,'RHS_TU95MS_vvs_dubna');assert.equal(JSON.stringify(d),before);assert(r.extraMods.some(p=>/@NeroAI_Strategic_[a-f0-9]+$/.test(p)));assert(r.extraMods.some(p=>p.endsWith('@FP-5 -Flamingo-')));assert(r.extraMods.some(p=>p.endsWith('@RHSAFRF')));assert.equal(validator.validate(dir).functions,require("../tools/build-campaign-operation").functions.length);}finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('Flamingo compatibility matches the actual installed launcher and controller exports, retains HE and uses bounded single launches',()=>{
 const {readEntry,indexEntries}=require('../tools/read-pbo-entry'),{decodeRap}=require('../tools/read-world-config'),cfg=require('../tools/validate-mission').parseConfig(fs.readFileSync(path.join(__dirname,'../addons/NeroStrategic/config.cpp'),'utf8'));
 const file='H:/SteamLibrary/steamapps/common/Arma 3/!Workshop/@FP-5 -Flamingo-/addons/kba_fp5_flamingo.pbo',native=decodeRap(readEntry(file,'config.bin'));assert(native.classes.CfgPatches.classes.kba_fp5_flamingo);assert(native.classes.CfgVehicles.classes.B_FP5_Launcher_F);assert(indexEntries(file).some(e=>e.name==='fp5_flamingo.p3d'));assert(readEntry(file,'scripts/fn_initMissileCtrl.sqf').length>10000);
 const verify=require('../tools/verify-strategic-addon').validateConfig,text=fs.readFileSync(path.join(__dirname,'../addons/NeroStrategic/config.cpp'),'utf8');assert.equal(verify(text,native).externalWeaponBase,native.classes.CfgWeapons.classes.weapon_VLSBase.parent);
 const broken=text.replace(/class weapon_VLSBase:MissileLauncher\s*\{class Cruise;\};/,'class weapon_VLSBase;');assert.notEqual(broken,text);assert.throws(()=>verify(broken,native),/внешний режим Cruise/);assert.throws(()=>verify(text.replace('weapon_VLSBase:MissileLauncher','weapon_VLSBase:WrongBase'),native),/наследования/);
 assert.equal(cfg.classes.CfgMagazines.classes.magazine_FP5.values.count,5);assert.equal(cfg.classes.CfgWeapons.classes.weapon_Flamingo_01.classes.Cruise.values.reloadTime,3);assert.equal(cfg.classes.CfgWeapons.classes.weapon_Flamingo_01.classes.Cruise.values.burst,1);assert.equal(cfg.classes.CfgAmmo.classes.Flamingo_CruiseMissile.values.indirectHitRange,50);assert.equal(cfg.classes.CfgAmmo.classes.rhs_ammo_kh55sh.values.RHS_WarheadType,'EXPLOSIVE');assert(cfg.classes.CfgPatches.classes.NeroStrategic.values.requiredAddons.includes('A3_Drones_F'));
 const source=fs.readFileSync(path.join(__dirname,'../addons/NeroStrategic/functions/fn_fpController.sqf'),'utf8');assert.match(source,/#define FP5_CONST_CRUISE_SPEED 277.777778/);assert.match(source,/#define FP5_CONST_DISPERSION_RADIUS 14/);assert(source.indexOf('_newDir=vectorNormalized')<source.indexOf('private _velocity = _newDir'));assert.doesNotMatch(source,/\b(?:compile|execVM)\b/);
});


test('transport transaction blocks march and purchase supervisors until the live party is aboard',()=>{
 const read=n=>fs.readFileSync(path.join(__dirname,'../tools/campaign-assets/fn_'+n+'.sqf'),'utf8');
 for(const n of ['campaignOrder','campaignMobility','campaignEquipmentLoop','campaignBuy'])assert.match(read(n),/campaignTransitGate/);
 assert.match(read('campaignMobility'),/NeroOP_staging/);
 for(const n of ['campaignRide','campaignLift'])assert.match(read(n),/campaignBoardingGate/);
 assert.match(read('campaignRide'),/assignAsCargoIndex/);assert.match(read('campaignRide'),/orderGetIn true/);assert.doesNotMatch(read('campaignRide'),/moveInCargo/);
 assert.match(read('campaignLift'),/Land_HelipadEmpty_F/);assert.match(read('campaignLift'),/landResult/);assert.doesNotMatch(read('campaignLift'),/moveInCargo|land "GET IN"/);
 assert.match(read('campaignEquipmentLoop'),/NeroOP_rideBusy/);assert.match(read('campaignEquipmentLoop'),/campaignRide/);
});
test('cruise radar proxy preserves native plane physics and only weapon damage counts as interception',()=>{
 const cfg=require('../tools/validate-mission').parseConfig(fs.readFileSync(path.join(__dirname,'../addons/NeroStrategic/config.cpp'),'utf8'));
 assert.equal(cfg.classes.CfgVehicles.classes.NeroOP_CruiseTrack_W.parent,'B_UAV_02_F');assert.equal(cfg.classes.CfgVehicles.classes.NeroOP_CruiseTrack_W.values.simulation,undefined);
 const text=fs.readFileSync(path.join(__dirname,'../tools/campaign-assets/fn_campaignCruiseTrack.sqf'),'utf8');assert(text.indexOf('waitUntil')<text.indexOf('private _proxy=createVehicle'));assert.match(text,/NeroOP_weaponHit/);assert.match(text,/projectile preserved/);assert.match(text,/disableCollisionWith _launcher/);
 const source=fs.readFileSync(path.join(__dirname,'../addons/NeroStrategic/config.cpp'),'utf8'),file='H:/SteamLibrary/steamapps/common/Arma 3/!Workshop/@FP-5 -Flamingo-/addons/kba_fp5_flamingo.pbo';
 const native=require('../tools/read-world-config').decodeRap(require('../tools/read-pbo-entry').readEntry(file,'config.bin'));
 assert.throws(()=>require('../tools/verify-strategic-addon').validateConfig(source.replaceAll('B_UAV_02_F','B_UAV_01_F'),native),/fixed-wing/);
});
test('native artillery coordinates reach FP5 while optional correction retains the requested fourteen-meter dispersion',()=>{
 const root=path.join(__dirname,'../addons/NeroStrategic/functions'),hook=fs.readFileSync(path.join(root,'fn_fpArtillery.sqf'),'utf8'),controller=fs.readFileSync(path.join(root,'fn_fpController.sqf'),'utf8'),correction=fs.readFileSync(path.join(root,'fn_fpCorrection.sqf'),'utf8');
 assert.match(hook,/ArtilleryShellFired/);assert.match(hook,/!local _shell/);assert.match(hook,/NeroOP_artyTargetASL/);assert.match(controller,/NeroOP_artyTargetASL/);assert.match(controller,/disableCollisionWith _launcher/);assert.match(correction,/#define FP5_CONST_DISPERSION_RADIUS 14/);
 assert.doesNotMatch(hook,/getArtilleryComputerSettings|compile|execVM/);assert.match(controller,/FP5_var_routeRevision/);
});
