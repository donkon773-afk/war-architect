'use strict';
const fs=require('node:fs'),path=require('node:path'),{parseConfig}=require('./validate-mission'),ops=require('../control-center/operations');
function validate(folder){const value=JSON.parse(fs.readFileSync(path.join(folder,'operation.json'),'utf8'));if(value.type==='becti')return require('./validate-becti-operation').validate(folder);if(value.type==='frontlineCampaign')return require('./validate-campaign-operation').validate(folder);if(value.type==='assaultDefense')return require('./validate-ground-operation').validate(folder);const d=ops.validate(value),desc=parseConfig(require('./operation-common/remote-config').parseable(fs.readFileSync(path.join(folder,'description.ext'),'utf8'))),sqm=parseConfig(fs.readFileSync(path.join(folder,'mission.sqm'),'utf8'));
 const registered=desc.classes.CfgFunctions?.classes.NeroOP?.classes.Air;
 if(desc.values.NeroOP_operation!==1||registered?.values.file!=='neroOps')throw Error('Operation function registration missing');
 const required=require('./build-operation').functions;
 for(const fn of required){const file=path.join(folder,'neroOps','fn_'+fn+'.sqf');if(!registered.classes[fn]||!fs.existsSync(file))throw Error('Operation function missing: '+fn);for(const ref of fs.readFileSync(file,'utf8').matchAll(/NeroOP_fnc_([A-Za-z0-9_]+)/g))if(!registered.classes[ref[1]])throw Error('Operation callback unregistered: '+ref[1]);}
 require('./operation-common/remote-config').verifyInheritance(desc,require('../control-center/operations').modPaths(d));
 const remote=desc.classes.CfgRemoteExec?.classes.Functions;
 if(remote?.values.mode!==1||remote.values.jip!==0)throw Error('Operation remote allowlist missing');
 for(const fn of ['airRequest','airActivate'])if(remote.classes['NeroOP_fnc_'+fn]?.values.allowedTargets!==2)throw Error('Operation request must target server: '+fn);
 for(const fn of ['airBoard','airEnd'])if(remote.classes['NeroOP_fnc_'+fn]?.values.allowedTargets!==0)throw Error('Operation client callback missing: '+fn);
 if(Object.keys(remote.classes).some(n=>!([...require('./operation-common/remote-config').native,'NeroOP_fnc_airRequest','NeroOP_fnc_airActivate','NeroOP_fnc_airBoard','NeroOP_fnc_airEnd'].includes(n))))throw Error('Internal operation helper exposed remotely');
 const entities=Object.values(sqm.classes.Mission?.classes.Entities?.classes||{}),units=entities.flatMap(g=>Object.values(g.classes.Entities?.classes||{}));
 const slots=d.playerRole==='pilot'?d.pilotSlots*2:1;
 if(sqm.values.version!==54||!sqm.classes.EditorData||sqm.classes.ScenarioData?.classes.Header?.values.maxPlayers!==slots||desc.classes.Header?.values.maxPlayers!==slots||units.length!==slots)throw Error('Operation multiplayer metadata/slots inconsistent');
 if(units.filter(u=>u.classes.Attributes?.values.isPlayer===1).length!==1||units.some(u=>u.classes.Attributes?.values.isPlayable!==1))throw Error('Operation requires one default player and playable slots');
 if(!sqm.values.addons.includes(require('../control-center/scenario-design').world(d.world).world))throw Error('Operation terrain dependency missing');
 if(!['ace_main','cba_main'].every(a=>sqm.values.addons.includes(a)))throw Error('Operation ACE/CBA dependencies missing');
 const ids=entities.flatMap(g=>[g.values.id,...Object.values(g.classes.Entities.classes).map(u=>u.values.id)]);if(new Set(ids).size!==ids.length)throw Error('Operation duplicate SQM IDs');
 if(/ModuleWLInit_F|BIS_WL_funds/.test(fs.readFileSync(path.join(folder,'mission.sqm'),'utf8')))throw Error('Operation contains Warlords initializer');
 const cfg=desc.classes.CfgNeroOperation;
 if(cfg?.values.type!==d.type||cfg.values.role!==d.playerRole||cfg.values.duration!==d.duration*60||cfg.values.scoreTarget!==d.scoreTarget||cfg.values.altitude!==d.altitude||cfg.values.playerClass!==d.playerClass)throw Error('Operation settings disagree with saved design');
 for(const a of d.sides){const c=cfg.classes[a.side]?.values;if(!c||c.active!==a.active||c.reserve!==a.reserve||JSON.stringify(c.classes)!==JSON.stringify(a.classes)||JSON.stringify(c.entry)!==JSON.stringify(a.entry))throw Error('Operation side settings disagree with saved design');}
 return {validated:true,type:d.type,world:d.world,slots,functions:required.length,active:d.sides.reduce((n,a)=>n+a.active,0),stock:d.sides.reduce((n,a)=>n+a.active+a.reserve,0)};
}
if(require.main===module){try{console.log(JSON.stringify(validate(process.argv[2]),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={validate};
