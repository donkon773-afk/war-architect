'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),becti=require('../control-center/becti'),equipment=require('../control-center/campaign-equipment');
const q=s=>'"'+String(s).replaceAll('"','""')+'"',arr=a=>'['+a.map(v=>Array.isArray(v)?arr(v):typeof v==='string'?q(v):v).join(',')+']';
const root=path.resolve(__dirname,'..');
const functions=['campaignSensors','campaignAirDefense','campaignPlayerControl','campaignIFF','campaignCountermeasure','campaignCMChance','campaignCruiseTrack','campaignADGate','campaignADFuse','campaignADMagazine','campaignADAhead','campaignMissileCompatible','campaignMissileGate','campaignMissileEngage'];
const aiFunctions={bectiAIState:'ai-state',bectiAIPolicy:'ai-policy',bectiAIContacts:'ai-contacts',bectiAIObjective:'ai-objective',bectiAISetRole:'ai-set-role',bectiAIRequest:'ai-request',bectiAISpawn:'ai-spawn',bectiAIRoad:'ai-road',bectiAIRepair:'ai-repair',bectiAIAir:'ai-air',bectiAIAttack:'ai-attack',bectiAIPhaseLabel:'ai-phase-label'};
function servicePosition(d,w,land){
 const base=d.sectors.find(s=>s.id===d.sides[0].base).position;
 for(const radius of [600,900,1200,1800,2400,3600])for(let angle=0;angle<360;angle+=22.5){const p=[Math.round(base[0]+Math.sin(angle*Math.PI/180)*radius),Math.round(base[1]+Math.cos(angle*Math.PI/180)*radius)];if(land.contains(w,p,80)&&d.sectors.every(s=>Math.hypot(p[0]-s.position[0],p[1]-s.position[1])>s.radius+150))return p;}
 throw Error('Нет отдельного участка суши для служебной зоны BECTI вдали от баз и секторов.');
}
function patch(out,file,from,to){const target=path.join(out,file),text=fs.readFileSync(target,'utf8').replace(/\r\n/g,'\n');if(!text.includes(from))throw Error('BECTI adapter anchor differs: '+file);fs.writeFileSync(target,text.replace(from,to));}
function build(value,output){
 require('./fetch-becti').fetch();const d=becti.validate(value),w=require('../control-center/scenario-design').world(d.world),land=require('../control-center/campaign-land');
 if(d.sectors.some(s=>!land.contains(w,s.position,s.radius)))throw Error('Перенесите базы и точки BECTI на основной участок суши.');
 const hash=crypto.createHash('sha256').update(JSON.stringify(d)).update(fs.readFileSync(__filename)).update(fs.readFileSync(path.join(__dirname,'becti-assets/runtime.sqf')));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-assets/player-spawn.sqf')));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-assets/map-marker-titling.sqf')));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-assets/hq-placement.sqf')));
 for(const f of ['shop-location.sqf','shop-purchase.sqf','shop-order.sqf','shop-ui.sqf','client.sqf','commander-request.sqf','hub.sqf','hub.hpp','create-native.sqf','ai-bootstrap.sqf','initialize-group.sqf','factory-queue.sqf','zeus-init.sqf','zeus-request.sqf'])hash.update(fs.readFileSync(path.join(__dirname,'becti-assets',f)));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-assets/zeus-prepare.sqf')));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-doctrine-config.js')));
 for(const f of Object.values(aiFunctions))hash.update(fs.readFileSync(path.join(__dirname,'becti-assets',f+'.sqf')));
 for(const f of ['campaignHeap','campaignRoadJoin'])hash.update(fs.readFileSync(path.join(__dirname,'campaign-assets','fn_'+f+'.sqf')));
 hash.update(fs.readFileSync(path.join(__dirname,'becti-shop-config.js'))).update(fs.readFileSync(path.join(__dirname,'campaign-assets/campaign-shop.hpp')));
 for(const fn of functions)hash.update(fs.readFileSync(path.join(__dirname,'campaign-assets','fn_'+fn+'.sqf')));
 const digest=hash.digest('hex').slice(0,12),name='WarArchitect_BECTI_'+w.id.replace(/[^A-Za-z0-9_]/g,'_')+'_'+digest,out=output||path.join(root,'dist/operations',name+'.'+w.world);
 fs.mkdirSync(out,{recursive:true});
 fs.cpSync(becti.source,out,{recursive:true,filter:p=>!p.split(path.sep).includes('.git')&&!/\.oldBackup$|\.py$|debug_object\.sqf$/.test(p)});
 const cat=new Map(equipment.catalog().map(r=>[r.class,r]));
 // Native BECTI catalog/factories and squad planner all consume the SAME selected army.
 for(const a of d.sides){
  const nativeSide=a.side==='WEST'?'West':'East',rows=[...a.classes.map(id=>({class:id,price:Math.max(5,Math.ceil(d.reinforcementCost/a.groupSize)),factory:0})),...a.shop.map(r=>({...r,factory:cat.get(r.class).kind==='AIR'?3:['TANK','APC'].includes(cat.get(r.class).category)?2:cat.get(r.class).category==='SHIP'?6:1}))];
  fs.writeFileSync(path.join(out,'Common/Config/Units/Units_'+nativeSide+'.sqf'),`private _side=_this;[_side,${q(nativeSide)},${arr(rows.map(r=>r.class))},${arr(rows.map(()=>''))},${arr(rows.map(()=>''))},${arr(rows.map(r=>r.price))},${arr(rows.map(r=>r.factory===0?5:20))},${arr(rows.map(()=>0))},${arr(rows.map(r=>r.factory))},${arr(rows.map(()=>''))}] call compile preprocessFileLineNumbers "Common\\Config\\Units\\Set_Units.sqf";\n`);
  // Native commander purchases these aliases even when the army catalog is replaced.
  // Keep their behaviour, but use the edited side's actual truck instead of hardcoded RHS.
  const salvagers=['CTI_Salvager_'+nativeSide,'CTI_Salvager_Independent_'+nativeSide];
  fs.appendFileSync(path.join(out,'Common/Config/Units/Units_'+nativeSide+'.sqf'),`[_side,${q(nativeSide)},${arr(salvagers)},["",""],["Salvage Truck","Salvage Truck"],[CTI_VEHICLES_SALVAGER_PRICE,CTI_VEHICLES_SALVAGER_PRICE],[25,25],[0,0],[CTI_FACTORY_REPAIR,CTI_FACTORY_REPAIR],${arr([[a.truckClass,'salvager'],[a.truckClass,'salvager-independent']])}] call compile preprocessFileLineNumbers "Common\\Config\\Units\\Set_Units.sqf";\n`);
  const vars={Commander:a.classes[0],Worker:a.classes.find(id=>/engineer|repair/i.test(id))||a.classes[0],Soldier:a.classes[0],Crew:a.classes.find(id=>/crew/i.test(id))||a.classes[0],Pilot:a.classes.find(id=>/pilot/i.test(id))||a.classes[0],Diver:a.classes[0]};
  const factories=['Barracks','Light','Heavy','Air','Repair','Ammo','Naval','Town'];
  fs.writeFileSync(path.join(out,'Common/Config/Factories/Factory_'+nativeSide+'.sqf'),`private _side=_this;\n`+Object.entries(vars).map(([k,v])=>`missionNamespace setVariable [format ["CTI_%1_${k}",_side],${q(v)}];`).join('\n')+'\n'+factories.map((f,i)=>`missionNamespace setVariable [format ["CTI_%1_%2Units",_side,CTI_${f.toUpperCase()==='TOWN'?'FTOWN':f.toUpperCase()}],${arr(rows.filter(r=>r.factory===(i===7?0:i)).map(r=>r.class))}];`).join('\n')+`\nmissionNamespace setVariable [format ["CTI_%1_Vehicles_Startup",_side],[[${q(a.truckClass)},[]]]];\n`);
  fs.writeFileSync(path.join(out,'Common/Config/Gear/Gear_'+nativeSide+'.sqf'),`[${q(nativeSide)},${arr(a.gear.map(r=>r.class))},${arr(a.gear.map(()=>0))},${arr(a.gear.map(r=>r.price))}] call compile preprocessFileLineNumbers "Common\\Config\\Gear\\Gear_Config_Set.sqf";\n[${q(nativeSide)},[]] call compile preprocessFileLineNumbers "Common\\Config\\Gear\\Gear_Template_Set.sqf";\n`);
  const roles=require('./becti-doctrine-config').roles(a,cat);
  // Pools are alternatives, quantities are bounded by the edited squad size, not catalog length.
  const pools=roles.map(r=>r[1].map(v=>[v[0],1]));
  fs.writeFileSync(path.join(out,'Common/Config/Squads/Squad_'+nativeSide+'.sqf'),`private _side=_this;\n`+['INFANTRY','LIGHT','HEAVY','AIR'].map(c=>`missionNamespace setVariable [format ["CTI_SQUADS_%1_CATEGORY_${c}",_side],${arr(roles.filter(r=>r[3]===c).map(r=>[r[0],1]))}];missionNamespace setVariable [format ["CTI_SQUADS_%1_KIND_${c}",_side],${arr(roles.filter(r=>r[3]===c).map(r=>r[0]))}];`).join('\n')+`\nmissionNamespace setVariable [format ["CTI_SQUADS_%1_TOWN_DEFENSE",_side],["Infantry"]];\n[_side,${arr(roles.map(r=>r[0]))},${arr(roles.map(r=>r[0]))},${arr(pools)},${'['+roles.map(r=>'CTI_'+r[2].toUpperCase()).join(',')+']'},${arr(roles.map(()=>500))},${arr(roles.map(r=>r[0]))},${arr(roles.map(()=>[]))}] call compile preprocessFileLineNumbers "Common\\Config\\Squads\\Squads_Set.sqf";\n`);
  const firstAir=roles.find(r=>r[3]==='AIR');if(firstAir)fs.appendFileSync(path.join(out,'Common/Config/Squads/Squad_'+nativeSide+'.sqf'),`missionNamespace setVariable [format ["CTI_SQUAD_%1_AirAttack",_side],missionNamespace getVariable format ["CTI_SQUAD_%1_${firstAir[0]}",_side]];\n`);
  patch(out,'Common/Config/Base/Base_'+nativeSide+'.sqf',nativeSide==='West'?'"rhsusf_stryker_m1126_m2_d"':'"rhs_btr80_msv"',q(a.shop.find(r=>cat.get(r.class).category==='APC')?.class||a.truckClass));
  // Garrison templates must use the same edited roster as the factories.
  const soldierRoles={SOLDIER:null,SOLDIER_AA:/_aa|antiair/i,SOLDIER_AR:/_ar|autorifle|machinegun/i,SOLDIER_AT:/_at|javelin/i,SOLDIER_CREW:/crew/i,SOLDIER_LAT:/_lat|maaws|riflemanat/i,SOLDIER_HAT:/_at|javelin/i,SOLDIER_ENGINEER:/engineer|repair/i,SOLDIER_GL:/_gl|grenadier/i,SOLDIER_MEDIC:/medic/i,SOLDIER_PILOT:/helipilot|pilot/i,SOLDIER_JETPILOT:/jetpilot|fighter_pilot/i,SOLDIER_SQUADLEADER:/_sl|_tl|leader/i,SOLDIER_SNIPER:/sniper|marksman/i,SOLDIER_TEAMLEADER:/_tl|leader/i};
  const townVars=Object.fromEntries(Object.entries(soldierRoles).map(([role,re])=>[role,[a.classes.find(id=>re?.test(id))||a.classes[0],1]]));
  const infantryMix={SOLDIERS_MG:['SOLDIER_AR'],SOLDIERS_AT_LIGHT:['SOLDIER_LAT','SOLDIER_AT'],SOLDIERS_AT_MEDIUM:['SOLDIER_AT','SOLDIER_HAT'],SOLDIERS_AT_HEAVY:['SOLDIER_HAT'],SOLDIERS_SPECOPS:['SOLDIER'],SOLDIERS_ENGINEER:['SOLDIER_ENGINEER'],SOLDIERS_SNIPERS:['SOLDIER_SNIPER']};for(const [role,keys]of Object.entries(infantryMix))townVars[role]=keys.map(k=>townVars[k]);
  const available=categories=>a.shop.filter(r=>categories.includes(cat.get(r.class).category)).map(r=>[r.class,1]);
  const light=available(['CAR']),apc=available(['APC']),tanks=available(['TANK']),aa=available(['AAA','SAM']);
  Object.assign(townVars,{MOTORIZED_MG:light,MOTORIZED_GL:light[0]||[],MOTORIZED_AT:light[0]||[],VEHICLE_AA:aa,VEHICLE_APC:apc,VEHICLE_ARMORED_LIGHT:tanks,VEHICLE_MOTORIZED:light,VEHICLES_LIGHT:light,VEHICLES_AA_LIGHT:aa,VEHICLES_MEDIUM:[...apc,...tanks],VEHICLES_HEAVY:tanks});
  fs.writeFileSync(path.join(out,'Common/Config/Towns/Towns_'+nativeSide+'.sqf'),Object.entries(townVars).filter(([,v])=>v.length>0).map(([key,v])=>`missionNamespace setVariable [${q(a.side+'_'+key)},${arr(v)}];`).join('\n'));
 }
 // Preserve BECTI's FSMs and economy; replace random base placement with editor positions.
 const bases=d.sides.map(a=>d.sectors.find(s=>s.id===a.base).position);
 const serverFile=path.join(out,'Server/Init/Init_Server.sqf'),server=fs.readFileSync(serverFile,'utf8'),start=server.indexOf('_locations= CENTER_POS nearroads'),end=server.indexOf('HELO_STARTUP=[];',start);
 if(start<0||end<0)throw Error('BECTI base placement contract changed.');
 fs.writeFileSync(serverFile,server.slice(0,start)+`waitUntil {CTI_InitTowns};\n_westLocation=${arr(bases[0])};_eastLocation=${arr(bases[1])};\ndiag_log "[WarArchitect BECTI] Editor base positions applied";\n`+server.slice(end));
 // Upstream spawns two competing registration loops, repeatedly re-groups and kills
 // lobby AI. Initialise first-life readiness directly and register each slot once.
 let aiInit=fs.readFileSync(serverFile,'utf8').replace(/\r\n/g,'\n');const aiStart=aiInit.indexOf('\t0 spawn {\n\t\twaitUntil {CTI_Init_Server};');
 const aiEnd=aiInit.indexOf('\n\t_logic setVariable ["cti_teams", _teams, true];',aiStart);
 if(aiStart<0||aiEnd<0)throw Error('BECTI AI slot registration contract changed.');
 aiInit=aiInit.slice(0,aiStart)+aiInit.slice(aiEnd);
 aiInit=aiInit.replace('} forEach [[west, CTI_WEST, _westLocation], [east, CTI_EAST, _eastLocation]];','} forEach [[west, CTI_WEST, _westLocation], [east, CTI_EAST, _eastLocation]];\n[] execVM "warArchitect\\aiBootstrap.sqf";');
 fs.writeFileSync(serverFile,aiInit);
 fs.copyFileSync(path.join(__dirname,'becti-assets/initialize-group.sqf'),path.join(out,'Server/Functions/Server_InitializeGroup.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/factory-queue.sqf'),path.join(out,'Server/Functions/Server_StartFactoryQueue.sqf'));
 patch(out,'Server/Functions/Server_OnClientPurchase.sqf','_var = missionNamespace getVariable _classname;\n_required_time = _var select CTI_UNIT_TIME;',`_var = missionNamespace getVariable [_classname,[]];
if (count _var<=CTI_UNIT_TIME || {!((_var#CTI_UNIT_TIME) isEqualType 0)}) exitWith {diag_log format ["[WA BECTI QUEUE] REJECT missing metadata class=%1 side=%2",_classname,_side];};
private _required_time = _var select CTI_UNIT_TIME;`);
 patch(out,'Server/Functions/Server_HandleAIPurchase.sqf','_var_classname = missionNamespace getVariable _req_classname;',`_var_classname = missionNamespace getVariable [_req_classname,[]];
if (count _var_classname<=CTI_UNIT_SCRIPT) exitWith {diag_log format ["[WA BECTI QUEUE] REJECT obsolete class=%1",_req_classname];[_req_seed,_req_classname,_req_target,_factory] call CTI_SE_FNC_OnClientPurchaseComplete;};`);
 patch(out,'Server/Init/Init_Server.sqf','_hq setVariable ["cti_gc_noremove", true];','[_hq,_startPos,_side,"creation"] call compile preprocessFileLineNumbers "warArchitect\\hqPlacement.sqf";\n\t_hq setVariable ["cti_gc_noremove", true];');
 patch(out,'Addons/Strat_mode/Functions/PERS_Load.sqf','_hq setposATL (((_load select 0 ) select 0)select 0);','[_hq,(((_load select 0) select 0) select 0),_side,"save load"] call compile preprocessFileLineNumbers "warArchitect\\hqPlacement.sqf";');
 patch(out,'Common/Init/Init_Locations.sqf','if (MIN_TOWNS==0)', 'if (true)');
 patch(out,'Server/Functions/Server_AI_PurchaseSquad.sqf','_need = round(3 + random 2);',`if (count _pool==0) exitWith {};\n_need = if (_pool findIf {!((_x#0) isKindOf "Man")}<0) then {((if (_side==west) then {${d.sides[0].groupSize}} else {${d.sides[1].groupSize}})-({alive _x} count units _group)) max 0} else {1};`);
 const aiEnabled='getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "coordinatedAI")==1';
 patch(out,'Server/Functions/Server_AI_PurchaseSquad.sqf','private ["_can_use",',`if (${aiEnabled}) exitWith {_this call NeroOP_fnc_bectiAIRequest;};\nprivate ["_can_use",`);
 const aiPurchase=path.join(out,'Server/Functions/Server_HandleAIPurchase.sqf');fs.writeFileSync(aiPurchase,`if (${aiEnabled} && {count _this>5} && {count (missionNamespace getVariable [_this#1,[]])>7} && {((missionNamespace getVariable (_this#1))#7) isEqualType ""}) exitWith {_this call NeroOP_fnc_bectiAISpawn;};\n`+fs.readFileSync(aiPurchase,'utf8'));
 patch(out,'Server/Functions/FSM/Functions_FSM_UpdateCommander.sqf','CTI_FSM_UpdateCommander_SetAIRole = {',`CTI_FSM_UpdateCommander_SetAIRole = {\n if (${aiEnabled}) exitWith {_this call NeroOP_fnc_bectiAISetRole;};`);
 patch(out,'Server/Functions/FSM/Functions_FSM_UpdateAI.sqf','_assigned_target=[leader _group,_pos_town] call CTI_CO_FNC_GetClosestEntity;',`_assigned_target=if (${aiEnabled}) then {[_group,_side] call NeroOP_fnc_bectiAIObjective} else {[leader _group,_pos_town] call CTI_CO_FNC_GetClosestEntity};`);
 patch(out,'Server/Functions/FSM/Functions_FSM_UpdateAI.sqf','_assigned_target = [leader _group, _side] call CTI_CO_FNC_GetClosestEnemyTown;',`_assigned_target=if (${aiEnabled}) then {[_group,_side] call NeroOP_fnc_bectiAIObjective} else {[leader _group,_side] call CTI_CO_FNC_GetClosestEnemyTown};`);
 patch(out,'Server/Functions/FSM/Functions_FSM_UpdateAI.sqf','CTI_FSM_UpdateAI_Order_TakeTown = {',`CTI_FSM_UpdateAI_Order_TakeTown = {\n if (${aiEnabled} && {(_this#5) in [CTI_ORDER_TAKETOWN_AUTO,CTI_ORDER_TAKEHOLDTOWN_AUTO]}) exitWith {_this call NeroOP_fnc_bectiAIAttack;};`);
 patch(out,'Server/FSM/update_ai.fsm','if !(alive assignedVehicle leader _group) then {','if (isNull (_group getVariable [""WA_BECTI_vehicle"",objNull]) && {!(alive assignedVehicle leader _group)}) then {');
 patch(out,'Server/FSM/update_ai.fsm','if (time - _members_lastposcheck > 220) then {','if (_group getVariable [""WA_BECTI_directorSeed"",-1]<0 && {time - _members_lastposcheck > 220}) then {');
 patch(out,'Server/FSM/update_ai.fsm',"//todo remote purchase for some kinds (air / mbt)",`if (getNumber(missionConfigFile >> ""CfgNeroOperation"" >> ""DevMode"" >> ""coordinatedAI"")==1 && {(_group getVariable [""cti_order"",-1]) in [CTI_ORDER_TAKETOWNS,CTI_ORDER_TAKEHOLDTOWNS,CTI_ORDER_TAKETOWN_AUTO,CTI_ORDER_TAKEHOLDTOWN_AUTO]}) then {_purchase=false;}; // purchases owned by attack preparation`);
 // Gear class names can be SQF commands (Binocular). Keep metadata under a safe
 // prefix in every native reader, preserving the actual item IDs and prices.
 for(const file of ['Common/Config/Gear/Gear_Config_Set.sqf','Common/Config/Gear/Gear_Template_Set.sqf','Common/Functions/Common_GetGearItemCost.sqf','Client/Functions/UI/Functions_UI_GearMenu.sqf','Client/Events/Events_UI_GearMenu.sqf','Client/Init/Init_Persistent_Gear.sqf']){
  const target=path.join(out,file),original=fs.readFileSync(target,'utf8');
  const text=original.replace(/missionNamespace getVariable (_item|_x)\b/g,(_,v)=>'missionNamespace getVariable ("WA_BECTI_Gear_" + '+v+')').replaceAll('missionNamespace getVariable [_x,[0,0]]','missionNamespace getVariable ["WA_BECTI_Gear_" + _x,[0,0]]').replaceAll('missionNamespace setVariable [_item,','missionNamespace setVariable ["WA_BECTI_Gear_" + _item,');
  if(text===original)throw Error('BECTI gear metadata contract changed: '+file);fs.writeFileSync(target,text);
 }
 patch(out,'Client/Functions/UI/Functions_UI_GearMenu.sqf','_templates = +(missionNamespace getVariable "cti_gear_list_templates");','_templates = +(missionNamespace getVariable ["cti_gear_list_templates",[]]);');
 patch(out,'Client/Init/Init_Client.sqf','CTI_Init_Client = true;','CTI_Init_Client = true;\ndiag_log "[WarArchitect BECTI] client ready: initialization completed";');
 patch(out,'Client/Init/Init_Client.sqf','(player getVariable "CTI_SERVER_ANWSER") call CTI_CL_FNC_JoinRequestAnswer;','(player getVariable "CTI_SERVER_ANWSER") call CTI_CL_FNC_JoinRequestAnswer;\n\tdiag_log "[WarArchitect BECTI] client server approval received";');
 patch(out,'Client/Init/Init_Client.sqf','CTI_InitClient = true;','CTI_InitClient = true;\ndiag_log "[WarArchitect BECTI] client gear initialized";');
 patch(out,'Client/Init/Init_Client.sqf','player setPos ([getMarkerPos format["CTI_%1Respawn", CTI_P_SideJoined], 3, 15] call CTI_CO_FNC_GetRandomPosition);','[player,getMarkerPos format["CTI_%1Respawn", CTI_P_SideJoined],"preplace"] call compile preprocessFileLineNumbers "warArchitect\\playerSpawn.sqf";');
 // The editor emits no legacy tutorial room. A missing marker resolves to [0,0,0]
 // and the upstream tutorial teleports/holds the player in the ocean forever.
 const tutorialFile=path.join(out,'Addons/Strat_mode/Functions/TUTORIAL_run.sqf');let tutorial=fs.readFileSync(tutorialFile,'utf8');
 const roomStart=tutorial.indexOf('_oh = player addAction'),roomEnd=tutorial.indexOf('player removeAction _oh;',roomStart);
 if(roomStart<0||roomEnd<0)throw Error('BECTI tutorial entry contract changed.');
 tutorial=tutorial.slice(0,roomStart)+'missionNamespace setVariable ["TUTO_COMPLETE",true];\ndiag_log "[WarArchitect BECTI] editor mission: entering battle without legacy tutorial room";\n'+tutorial.slice(roomEnd+'player removeAction _oh;'.length);
 const placeStart=tutorial.indexOf('_spawn_at = [_spawn_at, 8, 30]'),placeEnd=tutorial.indexOf('sleep 2;',placeStart);
 if(placeStart<0||placeEnd<0)throw Error('BECTI tutorial base placement contract changed.');
 tutorial=tutorial.slice(0,placeStart)+'[player,_spawn_at,"base entry"] call compile preprocessFileLineNumbers "warArchitect\\playerSpawn.sqf";\n\t'+tutorial.slice(placeEnd);fs.writeFileSync(tutorialFile,tutorial);
 const tutorialSetup=path.join(out,'Addons/Strat_mode/Functions/TUTORIAL_init_client.sqf');fs.writeFileSync(tutorialSetup,'if !("CTI_TUTORIAL" in allMapMarkers) exitWith {};\n'+fs.readFileSync(tutorialSetup,'utf8'));
 patch(out,'Client/Functions/UI/Functions_UI_RespawnMenu.sqf','//removes unclosed ppEffects','if (vehicle player == player && {surfaceIsWater getPosATL player} && {(getPosASL player)#2 < 0.5}) then {[player,objNull,"respawn recovery"] call compile preprocessFileLineNumbers "warArchitect\\playerSpawn.sqf";};\n\t//removes unclosed ppEffects');
 patch(out,'Addons/Strat_mode/Tablet/Events_UI_TabletMain.sqf','getAssignedCuratorUnit ADMIN_ZEUS','getAssignedCuratorUnit (missionNamespace getVariable ["ADMIN_ZEUS",objNull])');
 patch(out,'Addons/Strat_mode/PATROL_AI/PAI_Init.sqf','["SERVER", "Server_Addeditable",[ADMIN_ZEUS,(_patrol select 1)]] call CTI_CO_FNC_NetSend;','if (!isNil "ADMIN_ZEUS" && {!isNull ADMIN_ZEUS}) then {["SERVER", "Server_Addeditable",[ADMIN_ZEUS,(_patrol select 1)]] call CTI_CO_FNC_NetSend;};');
 // Existence of CTI_InitTowns is not readiness: it starts false. The victory
 // FSM must wait for every town's numeric value, which is assigned by scripts.
 const readyFile=path.join(out,'Server/Init/Init_Server.sqf');let ready=fs.readFileSync(readyFile,'utf8');
 const oldReady="waitUntil {!isNil 'CTI_InitTowns'};";if(!ready.includes(oldReady))throw Error('BECTI town readiness contract changed.');
 ready=ready.replaceAll(oldReady,'waitUntil {sleep 0.05; CTI_InitTowns && {CTI_Towns findIf {isNil {_x getVariable "cti_town_value"}} < 0}};');fs.writeFileSync(readyFile,ready);
 // All authored towns are inside the map-wide CENTER_POS marker; links remain BECTI-native.
 const service=servicePosition(d,w,land);
 let id=1;const entities=[];const pos=p=>`class PositionInfo {position[]={${p[0]},0,${p[1]}};};`;
 for(const [n,p] of [['CTI_WEST',bases[0]],['CTI_EAST',bases[1]],['CTI_GUER',bases[0]]])entities.push(`dataType="Logic";${pos(p)}name=${q(n)};type="Logic";id=${id++};`);
 // Eden's engine loader requires Attributes on the GROUP as well as each unit.
 // Without it, even a one-slot mission remains in mission selection with no SQF error.
 for(const a of d.sides){const p=bases[d.sides.indexOf(a)],side=a.side==='WEST'?'West':'East';for(let n=0;n<Math.max(a.active,d.playerSlots,d.bectiParameters.CTI_AI_TEAMS_NB);n++)entities.push(`dataType="Group";side=${q(side)};id=${id++};class Attributes {};class Entities {items=1;class Item0 {dataType="Object";side=${q(side)};type=${q(a.classes[n%a.classes.length])};id=${id++};flags=7;${pos([p[0]+n*3,p[1]])}class Attributes {isPlayable=1;${a.side===d.playerSide&&n===0?'isPlayer=1;':''}skill=${a.skill};description=${q(a.side+' — '+(n+1))};};};};`);
  entities.push(`dataType="Group";side=${q(side)};id=${id++};class Attributes {};class Entities {items=1;class Item0 {dataType="Object";side=${q(side)};type=${q(a.classes[0])};id=${id++};${pos([service[0]+25+20*d.sides.indexOf(a),service[1]])}class Attributes {name=${q('CTI_'+a.side+'_DEFAULT_GROUP')};init=${q('this allowDamage false;this disableAI "ALL";if (isServer) then {this hideObjectGlobal true;this enableSimulationGlobal false;};(group this) setVariable ["cti_server_group",str side group this];')};};};};`);
 }
 let town=0;for(const s of d.sectors.filter(s=>s.kind!=='base'))entities.push(`dataType="Logic";${pos(s.position)}name=${q('Town'+town++)};type="Logic";id=${id++};init=${q('[this,'+q(s.name)+','+({WEST:'west',EAST:'east',NONE:'resistance'}[s.owner])+','+s.bectiValue+'] execVM "Common\\Init\\Init_Location.sqf";')};`);
 for(const [n,p,r] of [['CENTER_POS',[w.size/2,w.size/2],w.size],['CTI_WestRespawn',bases[0],10],['CTI_EastRespawn',bases[1],10],['Prison',service,10],['HELO_START_0',bases[0],10],['HELO_START_1',bases[1],10]])entities.push(`dataType="Marker";position[]={${p[0]},0,${p[1]}};name=${q(n)};markerType="ELLIPSE";type="Empty";a=${r};b=${r};id=${id++};`);
 const maxPlayers=d.sides.reduce((n,a)=>n+Math.max(a.active,d.playerSlots,d.bectiParameters.CTI_AI_TEAMS_NB),0);
 fs.writeFileSync(path.join(out,'mission.sqm'),`version=54;binarizationWanted=0;randomSeed=873458;sourceName=${q(name)};addons[]={"A3_Characters_F","A3_Modules_F",${q(w.world)}};class EditorData {class ItemIDProvider {nextID=${id};};};class ScenarioData {author="War Architect / BECTI authors";gameType="CTI";respawn=3;respawnDelay=10;disabledAI=0;class Header {gameType="CTI";minPlayers=1;maxPlayers=${maxPlayers};};};class Mission {class Intel {briefingName=${q(d.title)};year=2035;month=6;day=24;hour=${d.hour};};class Entities {items=${entities.length};${entities.map((v,i)=>'class Item'+i+' {'+v+'};').join('\n')}};};\n`);
 let game=fs.readFileSync(path.join(out,'Rsc/Game.hpp'),'utf8');game=game.replace(/(onLoadMission|onLoadName|briefingName)\s*=\s*"[^"]*";/g,(_,k)=>k+'='+q(d.title)+';').replace(/gameType\s*=\s*CTI;/,'gameType="CTI";').replace(/maxPlayers\s*=\s*\d+;/,'maxPlayers='+maxPlayers+';');fs.writeFileSync(path.join(out,'Rsc/Game.hpp'),game);
 const paramsFile=path.join(out,'Rsc/Parameters.hpp');let params=fs.readFileSync(paramsFile,'utf8');for(const [k,v] of Object.entries(d.bectiParameters))params=params.replace(new RegExp('(class\\s+'+k+'\\s*\\{[\\s\\S]*?default\\s*=\\s*)-?\\d+(?:\\.\\d+)?'),(_,head)=>head+v);fs.writeFileSync(paramsFile,params);
 const island={altis:2,stratis:1,tanoa:3,malden:4,enoch:6}[w.world.toLowerCase()]||0;patch(out,'init.sqf','ISLAND = 2;',`ISLAND = ${island};`);
 patch(out,'Common/Functions/Common_CreateVehicle.sqf','_vehicle setVelocity [75 * (sin _direction), 75 * (cos _direction), 0];','_vehicle setPosATL [(getPosATL _vehicle)#0,(getPosATL _vehicle)#1,1400];_vehicle setVelocity [180 * (sin _direction),180 * (cos _direction),0];_vehicle flyInHeight 1400;');
 patch(out,'Common/Functions/Common_CreateVehicle.sqf','_vehicle = if ( isNull _created) then {createVehicle [_type,','private _waClass=getText(configFile >> "CfgNeroAirDefense" >> _type >> "spawnClass");if (_waClass=="") then {_waClass=_type;};\n_vehicle = if ( isNull _created) then {createVehicle [_waClass,');
 // Keep canonical AI unit equipment instead of overwriting every class with one RHS rifleman kit.
 patch(out,'Common/Functions/Common_EquipUnit.sqf','private ["_gear", "_item", "_unit"];',`private _waSide=side group (_this#0);if ((_this#1) isEqualTo (missionNamespace getVariable [format ["CTI_AI_%1_DEFAULT_GEAR_AI",_waSide],[]]) || {(_this#1) isEqualTo (missionNamespace getVariable [format ["CTI_AI_%1_DEFAULT_GEAR",_waSide],[]])}) exitWith {};\nprivate ["_gear", "_item", "_unit"];`);
 fs.mkdirSync(path.join(out,'warArchitect'),{recursive:true});fs.mkdirSync(path.join(out,'neroOps'),{recursive:true});
 for(const [fn,file] of Object.entries(aiFunctions))fs.copyFileSync(path.join(__dirname,'becti-assets',file+'.sqf'),path.join(out,'neroOps','fn_'+fn+'.sqf'));
 for(const fn of ['campaignHeap','campaignRoadJoin'])fs.copyFileSync(path.join(__dirname,'campaign-assets','fn_'+fn+'.sqf'),path.join(out,'neroOps','fn_'+fn+'.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/runtime.sqf'),path.join(out,'warArchitect/runtime.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/player-spawn.sqf'),path.join(out,'warArchitect/playerSpawn.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/map-marker-titling.sqf'),path.join(out,'Addons/MapMarkersTitling.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/hq-placement.sqf'),path.join(out,'warArchitect/hqPlacement.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/create-native.sqf'),path.join(out,'warArchitect/createNative.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/ai-bootstrap.sqf'),path.join(out,'warArchitect/aiBootstrap.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/zeus-init.sqf'),path.join(out,'warArchitect/zeusInit.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/zeus-request.sqf'),path.join(out,'neroOps/fn_bectiZeus.sqf'));
 fs.copyFileSync(path.join(__dirname,'becti-assets/zeus-prepare.sqf'),path.join(out,'neroOps/fn_zeusPrepare.sqf'));
 patch(out,'Addons/Strat_mode/init.sqf','(configSourceAddonList (configFile >> "CfgVehicles" >> typeof (_this select 1)))','([configSourceAddonList (configFile >> "CfgVehicles" >> typeof (_this select 1))] call WA_BECTI_filterCuratorAddons)');
 patch(out,'Client/Events/Events_UI_MapCommandMenu.sqf','_order = (_x getVariable "cti_order") call CTI_CL_FNC_GetOrderLabel;','_order = _x getVariable ["cti_order",-1];\n\t\t\tif (!(_order isEqualType 0)) then {_order=-1;};\n\t\t\tprivate _waOrderLabel=_order call CTI_CL_FNC_GetOrderLabel;');
 patch(out,'Client/Events/Events_UI_MapCommandMenu.sqf','lnbAddRow [_unitName, _order]','lnbAddRow [_unitName, _waOrderLabel]');
 patch(out,'Client/Events/Events_UI_MapCommandMenu.sqf','private _waOrderLabel=_order call CTI_CL_FNC_GetOrderLabel;','private _waOrderLabel=_order call CTI_CL_FNC_GetOrderLabel;private _waPhase=[_x] call NeroOP_fnc_bectiAIPhaseLabel;if (_waPhase!="") then {_waOrderLabel=_waOrderLabel+" · "+_waPhase;};');
 patch(out,'Client/GUI/GUI_MapCommandingMenu.sqf','if (lnbValue [220002, [_forEachIndex+1, 1]] != _order) then {','if (lnbValue [220002, [_forEachIndex+1, 1]] != _order || {_x getVariable ["WA_BECTI_uiPhase",""]!=_x getVariable ["WA_BECTI_phase",""]}) then {\n\t\t\t_x setVariable ["WA_BECTI_uiPhase",_x getVariable ["WA_BECTI_phase",""]];');
 patch(out,'Client/GUI/GUI_MapCommandingMenu.sqf','(_order) call CTI_CL_FNC_GetOrderLabel','((_order) call CTI_CL_FNC_GetOrderLabel)+" · "+([_x] call NeroOP_fnc_bectiAIPhaseLabel)');
 // Legacy PV assignment has no sender identity. Route the button through the
 // authenticated function instead of exposing an unvalidated curator grant.
 patch(out,'Addons/Strat_mode/init.sqf','_this  assignCurator ADMIN_ZEUS;','diag_log "[WA BECTI ZEUS] legacy assignment disabled; use authenticated request";');
 patch(out,'Rsc/Dialogs.hpp',"['SERVER', 'Server_Assign_Zeus', player] call CTI_CO_FNC_NetSend;",'[] spawn WA_BECTI_openZeus;');
 for(const [source,target] of [['shop-location.sqf','warArchitect/shopLocation.sqf'],['shop-purchase.sqf','warArchitect/shopPurchase.sqf'],['shop-order.sqf','neroOps/fn_bectiOrder.sqf'],['shop-ui.sqf','neroOps/fn_bectiShopUI.sqf'],['client.sqf','warArchitect/client.sqf']])fs.copyFileSync(path.join(__dirname,'becti-assets',source),path.join(out,target));
 for(const [source,target] of [['commander-request.sqf','neroOps/fn_bectiCommander.sqf'],['hub.sqf','neroOps/fn_bectiHub.sqf'],['hub.hpp','warArchitect/hub.hpp']])fs.copyFileSync(path.join(__dirname,'becti-assets',source),path.join(out,target));
 let shopUI=fs.readFileSync(path.join(__dirname,'campaign-assets/campaign-shop.hpp'),'utf8').replaceAll('NeroOPCampaignShop','WarArchitectBectiShop').replaceAll('NeroOP_fnc_campaignShopUI','NeroOP_fnc_bectiShopUI').replaceAll('.12,.27,.42,1','.22,.27,.18,1').replaceAll('.18,.4,.65,1','.35,.42,.25,1').replaceAll('.1,.28,.46,1','.25,.32,.19,1').replaceAll('.025,.04,.065,.97','.035,.045,.03,.97').replaceAll('.04,.065,.1,.96','.055,.065,.045,.96').replace('y="safeZoneY+.28*safeZoneH";w=".42*safeZoneW";h=".35*safeZoneH"','y="safeZoneY+.32*safeZoneH";w=".42*safeZoneW";h=".31*safeZoneH"');
 shopUI='class WarArchitectShopEdit: RscEdit {sizeEx=".02*safeZoneH";};\n'+shopUI.replace('class Category:NeroOPShopCombo',`class Search:WarArchitectShopEdit {idc=88161;x="safeZoneX+.14*safeZoneW";y="safeZoneY+.27*safeZoneH";w=".42*safeZoneW";h=".035*safeZoneH";text="";tooltip="Поиск по названию, классу или моду (RHS, CUP…)";onKeyUp="['REFRESH'] call NeroOP_fnc_bectiShopUI;";};\n class Crew:NeroOPShopButton {idc=88162;x="safeZoneX+.4*safeZoneW";y="safeZoneY+.78*safeZoneH";w=".16*safeZoneW";h=".045*safeZoneH";text="Техника: с экипажем";onButtonClick="['CREW'] call NeroOP_fnc_bectiShopUI;";};\n class Category:NeroOPShopCombo`);
 fs.writeFileSync(path.join(out,'warArchitect/shop.hpp'),shopUI);
 fs.appendFileSync(path.join(out,'description.ext'),'\n#include "warArchitect\\shop.hpp"\n#include "warArchitect\\hub.hpp"\n'+require('./becti-shop-config').config(d));
 const useFactory=path.join(out,'Client/Actions/Action_UseNearestFactory.sqf');fs.writeFileSync(useFactory,'if (hasInterface) exitWith {["OPEN"] call NeroOP_fnc_bectiShopUI;};\n'+fs.readFileSync(useFactory,'utf8'));
 for(const file of ['Client/Actions/Action_PurchaseMenu.sqf','Client/Actions/Action_GearMenu.sqf'])fs.writeFileSync(path.join(out,file),'if (hasInterface) then {["OPEN"] call NeroOP_fnc_bectiShopUI;};\n');
 const interactFile=path.join(out,'Addons/Strat_mode/Tablet/Events_UI_Interact.sqf');fs.writeFileSync(interactFile,fs.readFileSync(interactFile,'utf8').replaceAll('createDialog "CTI_RscGearMenu";','["OPEN"] call NeroOP_fnc_bectiShopUI;').replace('0 call CTI_COM_SET_CLIENT;','[] spawn WA_BECTI_takeCommand;').replace('createdialog "CTI_RscTablet_main";','["OPEN"] call NeroOP_fnc_bectiHub;'));
 const tabletEvents=path.join(out,'Addons/Strat_mode/Tablet/Events_UI_TabletMain.sqf');fs.writeFileSync(tabletEvents,fs.readFileSync(tabletEvents,'utf8').replaceAll('createDialog "CTI_RscGearMenu";','["OPEN"] call NeroOP_fnc_bectiShopUI;').replaceAll('createDialog "CTI_RscTabletPurchaseMenu";','["OPEN"] call NeroOP_fnc_bectiShopUI;'));
 for(const file of ['Rsc/Dialogs.hpp','Addons/Strat_mode/res.hpp']){const p=path.join(out,file);fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/createDialog\s+(['"])CTI_RscTablet_main\1/gi,"createDialog 'WarArchitectBectiHub'"));}
 for(const fn of functions)fs.copyFileSync(path.join(__dirname,'campaign-assets','fn_'+fn+'.sqf'),path.join(out,'neroOps','fn_'+fn+'.sqf'));
 fs.writeFileSync(path.join(out,'neroOps/fn_campaignEquipmentAction.sqf'),'params ["_u","_mode"];if (isServer && {isPlayer _u} && {alive _u} && {_mode=="CM"} && {!isRemoteExecuted || {remoteExecutedOwner==owner _u}}) then {private _v=vehicle _u;if (_v isKindOf "Air" && {driver _v==_u || {gunner _v==_u}}) then {[_v] call NeroOP_fnc_campaignCountermeasure;};};');
 const register=[...functions,'campaignEquipmentAction','bectiShopUI','bectiOrder','bectiCommander','bectiHub','bectiZeus','zeusPrepare',...Object.keys(aiFunctions),'campaignHeap','campaignRoadJoin'];fs.appendFileSync(path.join(out,'description.ext'),'\nclass CfgNeroOperation {type="becti";spawnWest[]={'+bases[0].join(',')+'};spawnEast[]={'+bases[1].join(',')+'};class DevMode {'+Object.entries(d.devMode).map(([k,v])=>k+'='+Number(v)+';').join('')+'};};class CfgFunctions {class NeroOP {tag="NeroOP";class BECTI {file="neroOps";'+register.map(f=>'class '+f+' {'+(f==='zeusPrepare'?'preInit=1;':'')+'};').join('')+'};};};\n');
 fs.appendFileSync(path.join(out,'description.ext'),'\nclass CfgWarArchitectDoctrine {aaClasses[]={'+[...cat.values()].filter(r=>['AAA','SAM','RADAR'].includes(r.category)).map(r=>q(r.class)).join(',')+'};'+d.sides.map(a=>'class '+a.side+' {groupSize='+a.groupSize+';};').join('')+'};\n');
 patch(out,'Common/Functions/Common_CreateVehicle.sqf','_//vehicle setAmmoOnPylon','//vehicle setAmmoOnPylon');
 // The upstream has its own RPC protocol. Do not replace its remote policy with the campaign allowlist.
 fs.appendFileSync(path.join(out,'init.sqf'),'\n[] execVM "warArchitect\\runtime.sqf";\n[] execVM "warArchitect\\client.sqf";\n[] execVM "warArchitect\\zeusInit.sqf";\n');
 const mods=require('../control-center/operations').modPaths(d),strategic=require('./prepare-campaign-strategic').prepare(),ad=require('./build-air-defense-addon').prepare(mods,d.devMode),missiles=d.devMode.realisticMissiles?require('./build-missile-profiles-addon').prepare(mods):null;
 const addons=[strategic,ad,...(missiles?[missiles]:[])].map(a=>({...a,config:undefined}));
 const manifest={upstream:becti.upstream,adapterVersion:3,engineTested:false,features:{nativeEconomy:true,nativeFactories:true,warArchitectShop:true,shopCart:true,explicitCommanderAction:true,hostAdminZeus:true,firstLifeAIRegistration:true,nativeFactoryQueueRecovery:true,separateServiceArea:true,safeHQRestore:true,editedArmies:true,editedTowns:true,editedBases:true,missileProfiles:!!missiles,radarNetwork:d.devMode.radarNetwork,coordinatedAI:d.devMode.coordinatedAI,combinedArmsDoctrine:true,physicalCrewReadiness:true,roadFirstApproach:true,roleSpecificAviation:true,engineerRepair:true,manualOrderCancellation:true},limitations:['BECTI uses its native town adjacency and capture rules; campaign links and convoy rules are not applied.','Player requisitions use the War Architect cart and native BECTI currency; native factories/economy remain active for AI. Equipment is delivered to a nearby crate.','Native BECTI prices are global by class; use equal prices for classes shared by both sides.','Native BECTI persistence is separate from Frontline/Supply persistence.','Player cart infantry currently uses ground delivery; Frontline physical airborne delivery is not yet ported to this BECTI requisition backend.']};
 fs.writeFileSync(path.join(out,'war-architect-becti.json'),JSON.stringify(manifest,null,2));fs.writeFileSync(path.join(out,'operation.json'),JSON.stringify(d,null,2));
 fs.writeFileSync(path.join(out,'WAR_ARCHITECT_CREDITS.md'),`# War Architect BECTI adaptation\nBased on ${becti.upstream.url} at ${becti.upstream.revision}.\nAuthors: ${becti.upstream.authors}. Original attribution and LICENCE preserved.\nBECTI derivative: CC BY-NC-SA 4.0; noncommercial, share alike.\nChanges: generated map, authored bases/towns, army factories and equipment, parameter defaults, shared missile/air-defense compatibility, bounded AI safety.\n`);
 const fixedTime=new Date('2026-01-01T00:00:00Z');const stamp=dir=>{for(const f of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,f.name);if(f.isDirectory())stamp(p);else if(f.isFile())fs.utimesSync(p,fixedTime,fixedTime);}};stamp(out);
 return {output:out,name,world:w.world,title:d.title,slots:d.sides.reduce((n,a)=>n+Math.max(a.active,d.playerSlots,d.bectiParameters.CTI_AI_TEAMS_NB),0),digest,extraMods:[...mods.filter(p=>!p.endsWith('@NeroAI_Strategic')),...addons.map(a=>a.mod)],addonArtifacts:addons,warnings:manifest.limitations};
}
module.exports={build,functions,aiFunctions};
