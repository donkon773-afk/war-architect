'use strict';
/* Explicit faction catalogs + curated national/specialist sets. Never replaces user sets. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),names=require('../control-center/faction-names');
const sideNames={0:'east',1:'west',2:'green'};
const forbidden=/protagonist|_vr_|_vr$|juggernaut|story_|competitor|rangemaster|survivor|unarmed/i;
function camouflage(a){
  const id=a.class.toLowerCase(),uniform=String(a.config?.uniformClass||'').toLowerCase();
  if(/winter|snow|_arctic|_arb_/.test(id))return 'winter';
  if(/ddpm|desert|_dsrt|_des(?:_|$)|_d\d*(?:_|$)|_2cd_|tropen/.test(id)||/ddpm|desert|tropen/.test(uniform))return 'desert';
  if(/woodland|_wood(?:_|$)|_wd(?:_|$)|_wdl(?:_|$)|_w(?:_|$)|_2cw_|_dpm(?:_|$)|fleck|_m81|_green(?:_|$)|_g(?:_|$)/.test(id)||/_dpm(?:_|$)|fleck|_m81/.test(uniform))return 'woodland';
  if((a.config?.hiddenSelectionsTextures||[]).some(t=>/camo.*_des_|turretd_|mount_d_/i.test(t)))return 'desert';
  if(/_des(?:_|$)|_d$/.test(a.faction.toLowerCase()))return 'desert';
  if(/_wd$/.test(a.faction.toLowerCase()))return 'woodland';
  return 'shared';
}
function isTracked(a){return /tank/i.test(a.config?.simulation||'')||(a.ancestors||[]).some(n=>/^(Tank|Tank_F|TankX|Tracked_APC_F)$/i.test(n));}
function native(a,faction){
  if(a.faction.toLowerCase()!==faction.toLowerCase()||forbidden.test(a.class))return false;
  const prefixes={BLU_F:/^B_/,OPF_F:/^O_/,IND_F:/^I_/,BLU_G_F:/^B_G_/,OPF_G_F:/^O_G_/,IND_G_F:/^I_G_/};
  return !prefixes[faction]||prefixes[faction].test(a.class);
}
function uuid(key){const b=crypto.createHash('sha256').update('neroai-faction-presets-v1:'+key).digest().subarray(0,16);b[6]=(b[6]&15)|80;b[8]=(b[8]&63)|128;const s=b.toString('hex');return `${s.slice(0,8)}-${s.slice(8,12)}-${s.slice(12,16)}-${s.slice(16,20)}-${s.slice(20)}`;}
function generate(snapshot){
  const assets=snapshot.assets.filter(a=>a.configPresent&&a.config.scope===2&&[0,1,2].includes(a.side)),byId=new Map(assets.map(a=>[a.class.toLowerCase(),a]));
  const presets=[],issues=[];
  function add(key,name,faction,side,selected,metadata={}){
    let inf=selected.filter(a=>a.kind==='INFANTRY');const vehicles=selected.filter(a=>a.kind!=='INFANTRY');
    const combat=inf.filter(a=>!/(pilot|crew|officer|diver|gunnerarty|asstgunner|gunnergmg|gunnerhmg)/i.test(a.class));
    if(combat.length)inf=combat;
    if(!inf.length){issues.push({key,reason:'no_infantry'});return;}
    const unique=rows=>[...new Set(rows.map(a=>a.class))];
    if(inf.length>256||vehicles.length>512)throw Error('Preset exceeds editor limits: '+key);
    const weapons=[...new Set(inf.flatMap(a=>a.config.weapons||[]).filter(w=>!['Throw','Put'].includes(w)))].sort();
    presets.push({key,id:uuid(key),name:name.slice(0,80),setup:{side:sideNames[side],faction,assets:unique(vehicles),infantry:unique(inf),infantryCosts:{}},metadata:{type:'faction-catalog',era:'Ассортимент установленной фракции; не штат конкретного года',...metadata,weaponPolicy:'Штатное вооружение выбранных классов пехоты',weapons,mods:[...new Set(selected.map(a=>a.mod))].sort(),counts:{infantry:unique(inf).length,assets:unique(vehicles).length}}});
  }
  const pairs=[...new Map(assets.filter(a=>a.kind==='INFANTRY').map(a=>[a.side+':'+a.faction,[a.side,a.faction]])).values()].sort((a,b)=>a[1].localeCompare(b[1]));
  for(const [side,faction] of pairs){
    const selected=assets.filter(a=>a.side===side&&native(a,faction));
    const hasCombat=selected.some(a=>a.kind==='INFANTRY'&&!/pilot|crew|officer/i.test(a.class));
    const label=names.factionLabel(faction),suffix=hasCombat?'каталог фракции':'обеспечение';
    add(`${side}:${faction}:base`,`${label} · ${suffix}`,faction,side,selected,{coverage:'native-faction',combatReady:hasCombat});
    for(const camo of ['woodland','desert','winter']){
      if(!selected.some(a=>a.kind==='INFANTRY'&&camouflage(a)===camo))continue;
      const rows=selected.filter(a=>[camo,'shared'].includes(camouflage(a)));
      if(rows.length===selected.length)continue;
      add(`${side}:${faction}:${camo}`,`${label} · ${{woodland:'лес',desert:'пустыня',winter:'зима'}[camo]}`,faction,side,rows,{coverage:'native-faction',camouflage:camo,sharedCamouflage:true,notes:['Общие классы без отдельной расцветки сохранены; камуфляж не создаётся скриптом.']});
    }
  }
  // UK: coherent CUP infantry; national 3CB vehicles are allowed despite BLU_F metadata.
  for(const camo of ['woodland','desert'])for(const era of ['modern','harrier']){
    const infSuffix=era==='modern'?'_MTP':camo==='desert'?'_DDPM':'_DPM';
    const infantry=assets.filter(a=>a.faction==='CUP_B_GB'&&a.kind==='INFANTRY'&&a.class.endsWith(infSuffix)&&!forbidden.test(a.class));
    const equipment=assets.filter(a=>a.side===1&&a.kind!=='INFANTRY'&&(
      a.faction==='CUP_B_GB'&&!/MCV80|2C[DSW]_BAF|MH47E|AH1_DL|TowingTractor|MTVR|M134_A/i.test(a.class)||
      /^UK3CB_BAF_(MAN_|LandRover_.*(Repair|Refuel|Reammo|Ammo)|Apache_AH1$)/i.test(a.class)
    )&&[camo,'shared'].includes(camouflage(a))&&!(/F35/i.test(a.class)&&era==='harrier')&&!(/GR9/i.test(a.class)&&era==='modern'));
    add(`uk:${era}:${camo}`,`Великобритания · ${era==='modern'?'MTP / F-35B':'DPM / Harrier GR9'} · ${camo==='desert'?'пустыня':'лес'}`,'CUP_B_GB',1,[...infantry,...equipment],{type:'curated-national',camouflage:camo,era:era==='modern'?'Игровая современная сборка CUP/3CB':'Исторический вариант с Harrier; не штат конкретного года',attachments:['Британская техника 3CB BAF'],notes:['Chieftain в проверенном каталоге отсутствует.','Общие авиационные и служебные окраски сохраняются.']});
  }
  const marsoc=assets.filter(a=>a.faction==='rhs_faction_socom'&&/^rhsusf_socom_marsoc_/i.test(a.class));
  const socomNative=assets.filter(a=>a.faction==='rhs_faction_socom'&&a.kind!=='INFANTRY'&&a.kind!=='SHIP');
  const socomAir=socomNative.filter(a=>a.kind==='HELICOPTER');
  for(const camo of ['woodland','desert']){
    const s=camo==='desert'?'d':'wd',cup=camo==='desert'?'Desert':'Woodland';
    const ids=[`CUP_B_M1128_MGS_${cup}`,`rhsusf_stryker_m1134_${s}`,`rhsusf_stryker_m1126_m2_${s}`,`rhsusf_stryker_m1126_mk19_${s}`,`rhsusf_stryker_m1127_m2_${s}`,`rhsusf_stryker_m1132_m2_np_${s}`,`CUP_B_M1133_MEV_${cup}`,`CUP_B_M1129_MC_MK19_${cup}`];
    const support=ids.map(id=>{const a=byId.get(id.toLowerCase());if(!a)throw Error('Required mobile asset unavailable: '+id);return a;});
    const light=socomNative.filter(a=>!['CAR','APC','TANK'].includes(a.kind)||!isTracked(a));
    // The RHS SOCOM GMV fleet has desert paint only. In woodland use actual US woodland donors.
    const nativeGround=light.filter(a=>a.kind!=='HELICOPTER'&&[camo,'shared'].includes(camouflage(a)));
    const donors=camo==='woodland'?assets.filter(a=>a.side===1&&a.faction==='rhs_faction_usarmy_wd'&&a.kind==='CAR'&&/m1165|m1151|m1167|m998|m1078|m1083/i.test(a.class)&&camouflage(a)==='woodland'&&!isTracked(a)):[];
    add(`us:socom-mobile:${camo}`,`США · SOCOM + Stryker MGS · ${camo==='desert'?'пустыня':'лес'}`,'rhs_faction_socom',1,[...marsoc,...nativeGround,...donors,...socomAir,...support],{type:'curated-mobile',camouflage:camo,groundPolicy:'wheeled-only',era:'Сценарная группа с M1128 эпохи до вывода MGS',attachments:['Армейская колёсная поддержка США: Stryker, машины обеспечения'],notes:['Пехота только MARSOC RHS, штатная форма M81; лес/пустыня здесь относится к технике.','Stryker не объявлен штатной машиной SOCOM.','M1128 — огневая поддержка; основное специализированное ПТ-средство — M1134.','Нет танков, Bradley, M113, Warrior, LAV чужих стран или Rooikat/Badger.']});
  }
  const pureSocom=assets.filter(a=>a.faction==='rhs_faction_socom'&&(!['CAR','APC','TANK'].includes(a.kind)||!isTracked(a))&&!forbidden.test(a.class));
  add('us:socom-light','США · SOCOM · лёгкая группа без Stryker','rhs_faction_socom',1,pureSocom,{type:'curated-special',groundPolicy:'wheeled-only',attachments:[],camouflage:'native',notes:['Только классы фракции SOCOM RHS.']});
  for(const [key,faction,pattern,title] of [
    ['usmc-force-recon','CUP_B_USMC',/^CUP_B_FR_/,'США · USMC Force Recon'],
    ['ru-spetsnaz','CUP_O_RU',/^CUP_O_RUS_SpecOps/,'Россия · спецназ CUP'],
    ['ua-sso','b_afousf',/.*/,'Украина · ССО UFP']
  ]){
    const infantry=assets.filter(a=>a.faction===faction&&a.kind==='INFANTRY'&&pattern.test(a.class)&&!forbidden.test(a.class));
    if(!infantry.length){issues.push({key,reason:'specialist_classes_not_found'});continue;}
    const side=infantry[0].side;
    const limited=key==='ru-spetsnaz'?/UAZ|Tigr|GAZ_Vodnik|Mi8|Kornet|KORD|AGS|2b14/i:key==='usmc-force-recon'?/HMMWV|M1151|M1165|M1167|M2Static|MK19|TOW|M252|MH6|UH1|MH60/i:/.*/;
    const vehicles=assets.filter(a=>a.side===side&&a.faction===faction&&a.kind!=='INFANTRY'&&limited.test(a.class)&&(['CAR','APC'].includes(a.kind)?!isTracked(a):['HELICOPTER','SHIP','STATIC'].includes(a.kind)));
    add(`special:${key}`,`${title} · лёгкая группа`,faction,side,[...infantry,...vehicles],{type:'curated-special',groundPolicy:'wheeled-only',attachments:key==='ua-sso'?[]:['Ограниченная поддержка собственной национальной фракции']});
  }
  for(const p of presets){
    if(p.metadata.groundPolicy==='wheeled-only')for(const id of p.setup.assets){const a=byId.get(id.toLowerCase());if(['CAR','APC','TANK'].includes(a.kind)&&isTracked(a))throw Error('Tracked asset in mobile preset: '+id);}
  }
  const coverage=pairs.map(([side,faction])=>({side:sideNames[side],faction,presets:presets.filter(p=>p.setup.side===sideNames[side]&&p.setup.faction===faction).map(p=>p.id)}));
  return {version:1,generatedAt:new Date().toISOString(),configCheckedAt:snapshot.checkedAt,evidence:snapshot.evidence,presets,coverage,issues};
}
function install(pack,dir,validate){
  fs.mkdirSync(dir,{recursive:true});const files=fs.readdirSync(dir).filter(f=>/^[0-9a-f-]{36}\.json$/.test(f));
  const existing=files.map(f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'))),byId=new Map(existing.map(r=>[r.id,r]));
  const pending=pack.presets.filter(p=>!byId.has(p.id));if(existing.length+pending.length>200)throw Error('Library would exceed 200 sets; nothing installed.');
  for(const p of pending){validate(p.setup);if(existing.some(r=>r.setup.side===p.setup.side&&r.name.toLowerCase()===p.name.toLowerCase()))throw Error('Existing user name collision: '+p.name);}
  const created=[],preserved=[];
  for(const p of pack.presets){const file=path.join(dir,p.id+'.json');if(fs.existsSync(file)){preserved.push(p.id);continue;}const now=new Date().toISOString(),record={version:1,id:p.id,name:p.name,setup:p.setup,revision:1,createdAt:now,updatedAt:now};const fd=fs.openSync(file,'wx');try{fs.writeFileSync(fd,JSON.stringify(record,null,2));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}const back=JSON.parse(fs.readFileSync(file,'utf8'));if(JSON.stringify(back)!==JSON.stringify(record))throw Error('Readback mismatch: '+p.id);created.push(p.id);}
  return {created,preserved};
}
if(require.main===module){
  const snapshot=JSON.parse(fs.readFileSync(path.join(root,'dist/faction-preset-config.json'),'utf8')),pack=generate(snapshot),editor=require('../control-center/warlords-editor'),contract=require('../control-center/side-setups');
  for(const p of pack.presets)contract.validate(p.setup);
  const out=path.join(root,'control-center/data/faction-presets');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'builtin.json'),JSON.stringify(pack,null,2));
  const equipment=Object.fromEntries(snapshot.assets.filter(a=>a.kind==='INFANTRY').map(a=>[a.class,{weapons:a.config.weapons||[],magazines:a.config.magazines||[],uniform:a.config.uniformClass||null,linkedItems:a.config.linkedItems||[],backpack:a.config.backpack||null,source:a.configSource}]));
  fs.writeFileSync(path.join(out,'infantry-equipment.json'),JSON.stringify({checkedAt:snapshot.checkedAt,evidence:snapshot.evidence,classes:equipment},null,2));
  const installed=process.argv.includes('--install')?install(pack,path.join(root,'control-center/data/side-setups'),contract.validate):null;
  console.log(JSON.stringify({presets:pack.presets.length,factions:pack.coverage.length,uncovered:pack.coverage.filter(c=>!c.presets.length),issues:pack.issues,installed:installed&&{created:installed.created.length,preserved:installed.preserved.length}}));
}
module.exports={generate,install,camouflage,isTracked,native,uuid};
