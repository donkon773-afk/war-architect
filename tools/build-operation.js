'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),ops=require('../control-center/operations');
const schema=require('../control-center/scenario-design');
const functions=['airInit','airLoop','airSpawn','airArm','airLoss','airRequest','airActivate','airBoard','airAvionics','airHelmet','airClient','airLedger','airOutcome','airPosition','airFinish','airEnd','zeusPrepare','zeusServer','zeusClient','aiGThreshold','aiGForce','aiGforces'];
const q=s=>'"'+String(s).replaceAll('"','""').replace(/[\r\n]/g,' ')+'"';
const arr=a=>'{'+a.map(v=>Array.isArray(v)?arr(v):typeof v==='string'?q(v):v).join(',')+'}';
function build(value,output){if(value?.type==='frontlineCampaign'){delete require.cache[require.resolve('./build-campaign-operation')];return require('./build-campaign-operation').build(value,output);}if(value?.type==='assaultDefense'){delete require.cache[require.resolve('./build-ground-operation')];return require('./build-ground-operation').build(value,output);}const d=ops.validate(value),w=schema.world(d.world),fingerprint=crypto.createHash('sha256').update(JSON.stringify(d)).update(fs.readFileSync(__filename));
 fingerprint.update(fs.readFileSync(path.join(__dirname,'operation-common/remote-config.js')));fingerprint.update(JSON.stringify({native:require('./operation-common/remote-config').native,inheritsFunctions:require('./operation-common/remote-config').modFunctionInheritance(ops.modPaths(d))}));
 for(const fn of functions)fingerprint.update(fs.readFileSync(path.join(__dirname,(fn.startsWith('zeus')||fn.startsWith('aiG'))?'operation-common':'operation-assets','fn_'+fn+'.sqf')));
 const digest=fingerprint.digest('hex').slice(0,12);
 const name='NeroAI_AirBattle_'+w.id.replace(/[^A-Za-z0-9_]/g,'_')+'_'+digest,world=w.world;
 const out=output||path.join(__dirname,'..','dist','operations',name+'.'+world);fs.mkdirSync(path.join(out,'neroOps'),{recursive:true});
 const rows=[];let id=10;
 if(d.playerRole==='pilot')for(const side of ['WEST','EAST'])for(let i=0;i<d.pilotSlots;i++){
  const a=d.sides.find(a=>a.side===side),unitId=id++,groupId=id++,isPlayer=side===d.playerSide&&i===0;
  rows.push(`class Item${rows.length} { dataType="Group"; side=${q(side==='WEST'?'West':'East')}; id=${groupId}; class Attributes {}; class Entities {items=1; class Item0 {dataType="Object"; side=${q(side==='WEST'?'West':'East')}; id=${unitId}; type=${q(side==='WEST'?'B_Pilot_F':'O_Pilot_F')}; flags=7; class PositionInfo {position[]={${a.entry[0]+i*3},0,${a.entry[1]}};}; class Attributes {isPlayable=1; ${isPlayer?'isPlayer=1;':''} init="this setVariable [""NeroOP_lobbySlot"",true,true];";description=${q((side==='WEST'?'Синие':'Красные')+' — пилот '+(i+1))};};};};};`);
 }
 else rows.push(`class Item0 {dataType="Group";side="Civilian";id=10;class Attributes {};class Entities {items=1;class Item0 {dataType="Object";side="Civilian";id=11;type="C_man_1";flags=7;class PositionInfo {position[]={${d.sides[0].entry[0]},0,${d.sides[0].entry[1]}};};class Attributes {isPlayer=1;isPlayable=1;description="Наблюдатель / Zeus";};};};};`);
 const maxPlayers=rows.length,addons=['A3_Characters_F',world,'ace_main','cba_main'];
 fs.writeFileSync(path.join(out,'mission.sqm'),`version=54; binarizationWanted=0; sourceName=${q(name)}; randomSeed=654381; addons[]=${arr(addons)}; class EditorData {moveGridStep=1; angleGridStep=0.2617994; scaleGridStep=1; autoGroupingDist=10; class ItemIDProvider {nextID=1000;};}; class ScenarioData {author="NeroAI";gameType="TDM";respawn=3;respawnDelay=12;class Header {gameType="TDM";minPlayers=1;maxPlayers=${maxPlayers};};}; class Mission {class Intel {briefingName=${q(d.title)};year=2035;month=6;day=24;hour=${d.hour};};class Entities {items=${maxPlayers};${rows.join('\n')}};};\n`);
 const sideCfg=d.sides.map((a,i)=>`class ${a.side} {index=${i}; classes[]=${arr(a.classes)}; active=${a.active}; reserve=${a.reserve}; entry[]=${arr(a.entry)}; skill=${a.skill};};`).join('\n');
 fs.writeFileSync(path.join(out,'description.ext'),`author="NeroAI";onLoadName=${q(d.title)};briefingName=${q(d.title)};overviewText="Воздушное сражение: ограниченные резервы, счёт и время. Самолёты начинают в воздухе.";class Header {gameType="TDM";minPlayers=1;maxPlayers=${maxPlayers};};respawn=3;respawnDelay=12;respawnOnStart=-1;disabledAI=0;joinUnassigned=1;enableDebugConsole=2;NeroOP_operation=1;NeroWL_observer=0;class CfgNeroOperation {type="airBattle";role=${q(d.playerRole)};playerSide=${q(d.playerSide)};playerClass=${q(d.playerClass)};duration=${d.duration*60};scoreTarget=${d.scoreTarget};altitude=${d.altitude};reinforcementDelay=${d.reinforcementDelay};zone[]=${arr(d.zone.position)};zoneRadius=${d.zone.radius};hour=${d.hour};overcast=${d.overcast};autoAirLoadout=${d.autoAirLoadout?1:0};${sideCfg}};
 class CfgFunctions {class NeroOP {class Air {file="neroOps";${functions.map(f=>'class '+f+' {'+(f==='zeusPrepare'?'preInit=1;':f==='aiGforces'?'postInit=1;':'')+'};').join('')}};};};
 class CfgRemoteExec {class Functions {mode=1;jip=0;class NeroOP_fnc_airRequest {allowedTargets=2;};class NeroOP_fnc_airActivate {allowedTargets=2;};class NeroOP_fnc_airBoard {allowedTargets=0;};class NeroOP_fnc_airEnd {allowedTargets=0;};};};
 class CfgDebriefing {class AirWest {title="Победа синих";subtitle="Воздушное сражение завершено";description="Результаты и потери записаны в журнал операции.";};class AirEast {title="Победа красных";subtitle="Воздушное сражение завершено";description="Результаты и потери записаны в журнал операции.";};class AirDraw {title="Ничья";subtitle="Время операции истекло";description="Стороны завершили операцию с равным результатом.";};class AirError {title="Операция не запущена";description="Недоступен класс самолёта или не удалось создать экипаж. Смотрите журнал Arma.";};};corpseManagerMode=1;corpseLimit=16;corpseRemovalMinTime=90;wreckManagerMode=1;wreckLimit=12;wreckRemovalMinTime=90;\n`);
 const remoteConfig=require('./operation-common/remote-config');fs.writeFileSync(path.join(out,'description.ext'),remoteConfig.extend(fs.readFileSync(path.join(out,'description.ext'),'utf8'),ops.modPaths(d)));
 for(const fn of functions)fs.copyFileSync(path.join(__dirname,(fn.startsWith('zeus')||fn.startsWith('aiG'))?'operation-common':'operation-assets','fn_'+fn+'.sqf'),path.join(out,'neroOps','fn_'+fn+'.sqf'));
 fs.writeFileSync(path.join(out,'initServer.sqf'),'[] spawn NeroOP_fnc_zeusServer;\n[] spawn NeroOP_fnc_airInit;\n');
 fs.writeFileSync(path.join(out,'initPlayerLocal.sqf'),'[] spawn NeroOP_fnc_zeusClient;\n[] spawn NeroOP_fnc_airClient;\n');
 fs.writeFileSync(path.join(out,'onPlayerRespawn.sqf'),'[] spawn {waitUntil {sleep 0.2; alive player}; [player] remoteExecCall ["NeroOP_fnc_airRequest",2];};\n');
 fs.writeFileSync(path.join(out,'operation.json'),JSON.stringify(d,null,2));
 // Fixed timestamps make repeated packaging identical. Configuration and runtime
 // source changes produce a different filename instead of replacing an active PBO.
 const stamp=new Date('2026-01-01T00:00:00Z');
 for(const entry of fs.readdirSync(out,{withFileTypes:true}))if(entry.isFile())fs.utimesSync(path.join(out,entry.name),stamp,stamp);
 for(const file of fs.readdirSync(path.join(out,'neroOps')))fs.utimesSync(path.join(out,'neroOps',file),stamp,stamp);
 return {output:out,name,world,title:d.title,extraMods:ops.modPaths(d),slots:maxPlayers,digest};
}
if(require.main===module){const d=process.argv[2]?JSON.parse(fs.readFileSync(process.argv[2],'utf8')):ops.defaults();console.log(JSON.stringify(build(d)));}
module.exports={build,functions};
