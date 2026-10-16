'use strict';
// Read installed configs only. Keep the existing vehicle inventory untouched.
const fs=require('node:fs'),path=require('node:path');
const {readEntry,indexEntries}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
const root=path.resolve(__dirname,'..');
function scan(){
 const launch=JSON.parse(fs.readFileSync(path.join(__dirname,'warlords-launch.json'),'utf8').replace(/^\uFEFF/,''));
 const original=JSON.parse(fs.readFileSync(path.join(root,'dist/mod-assets.json'),'utf8'));
 const tables=Object.fromEntries(['CfgVehicles','CfgWeapons','CfgMagazines','CfgGlasses','CfgFactionClasses'].map(k=>[k,new Map()])),errors=[];
 const native=['Dta','Addons',...['Curator','Heli','Kart','Mark','Jets','Argo','Orange','Tacops','Tank','Enoch','AoW','Expansion'].map(n=>n+'/addons')];
 const sources=[...native.map(n=>({name:'Arma 3',path:'',dir:path.join(launch.armaRoot,n)})),...original.mods.map(m=>({name:m.name,path:m.path,dir:path.join(m.path,'addons')}))];
 for(const src of sources){if(!fs.existsSync(src.dir))continue;for(const name of fs.readdirSync(src.dir).filter(n=>/\.pbo$/i.test(n))){
  try{const file=path.join(src.dir,name);for(const entry of indexEntries(file).filter(e=>/(^|[\\/])config\.bin$/i.test(e.name))){const c=decodeRap(readEntry(file,entry.name));
   for(const [table,map]of Object.entries(tables))for(const [id,node]of Object.entries(Object.entries(c.classes).find(([id])=>id.toLowerCase()===table.toLowerCase())?.[1]?.classes||{})){
    const values=Object.fromEntries(Object.entries(node.values).map(([k,v])=>[k.toLowerCase(),v])),key=id.toLowerCase(),old=map.get(key),provider=old&&!Object.hasOwn(values,'scope')&&!Object.hasOwn(values,'displayname')?old:src;
    map.set(key,{id:values.scope===2?id:old?.id||id,parent:node.parent&&node.parent.toLowerCase()!==key?node.parent:old?.parent||'',values:{...old?.values,...values},classes:{...old?.classes,...node.classes},mod:provider.mod||provider.name,modPath:provider.modPath??provider.path});
   }}
  }catch(e){if(!/Entry missing|Not a RAP config/.test(e.message))errors.push({mod:src.name,pbo:name,error:e.message});}
 }}
 const val=(table,c,k,seen=new Set())=>{if(!c||seen.has(c.id.toLowerCase()))return undefined;seen.add(c.id.toLowerCase());return c.values[k.toLowerCase()]??val(table,tables[table].get(c.parent.toLowerCase()),k,seen);};
 if(process.argv.includes('--diagnose'))for(const [table,id]of [['CfgWeapons','CUP_arifle_AKM'],['CfgWeapons','CUP_launch_Javelin']]){let c=tables[table].get(id.toLowerCase());const chain=[],seen=new Set();while(c&&!seen.has(c.id)){seen.add(c.id);chain.push({id:c.id,parent:c.parent,scope:c.values.scope,type:c.values.type,isBackpack:c.values.isBackpack,simulation:c.values.simulation});c=tables[table].get(c.parent.toLowerCase());}console.log(JSON.stringify({id,chain,missing:c?null:chain.at(-1)?.parent}));}
 const ancestor=(table,c,pattern,seen=new Set())=>{if(!c||seen.has(c.id.toLowerCase()))return false;seen.add(c.id.toLowerCase());return pattern.test(c.id)||pattern.test(c.parent)||ancestor(table,tables[table].get(c.parent.toLowerCase()),pattern,seen);};
 const infantry=new Map(original.assets.filter(a=>a.kind==='INFANTRY').map(a=>[a.class,a]));for(const c of tables.CfgVehicles.values())if(val('CfgVehicles',c,'scope')===2&&[0,1].includes(val('CfgVehicles',c,'side'))&&ancestor('CfgVehicles',c,/^(Man|CAManBase)$/i))infantry.set(c.id,{class:c.id,label:String(val('CfgVehicles',c,'displayName')||c.id),kind:'INFANTRY',side:val('CfgVehicles',c,'side'),faction:String(val('CfgVehicles',c,'faction')||''),mod:c.mod,modPath:c.modPath});
 const referenced=new Set();for(const id of infantry.keys()){const c=tables.CfgVehicles.get(id.toLowerCase());for(const key of ['weapons','magazines','linkedItems'])for(const item of val('CfgVehicles',c,key)||[])referenced.add(String(item).toLowerCase());referenced.add(String(val('CfgVehicles',c,'uniformClass')).toLowerCase());referenced.add(String(val('CfgVehicles',c,'backpack')).toLowerCase());}
 const gear=[],units={},vehicles={},assets=[];
 for(const c of tables.CfgWeapons.values())if(val('CfgWeapons',c,'scope')===2||val('CfgWeapons',c,'scope')===1&&referenced.has(c.id.toLowerCase())){
  const type=val('CfgWeapons',c,'type')??(ancestor('CfgWeapons',c,/^(Rifle|RifleCore)$/i)?1:ancestor('CfgWeapons',c,/^(Pistol|PistolCore)$/i)?2:ancestor('CfgWeapons',c,/^(Launcher|LauncherCore)$/i)?4:undefined);if(![1,2,4,4096,131072].includes(type))continue;
  const kind=[1,2,4].includes(type)?'WEAPON':'ITEM',category=type===4?'LAUNCHER':type===2?'PISTOL':type!==1?'GEAR':ancestor('CfgWeapons',c,/sniper|srifle|svd|svds|m107|m82|m2010|m24|m40|l96|awm|t5000|mosin/i)?'SNIPER':ancestor('CfgWeapons',c,/machinegun|lmg|mmg|m240|m249|pkm|pkp|m60|minimi|mg3|mg42|l7a2|l110|ukm|rpk/i)?'MACHINEGUN':ancestor('CfgWeapons',c,/smg/i)?'SMG':(val('CfgWeapons',c,'modes')||[]).some(m=>/auto|burst/i.test(m))?'AUTOMATIC':'RIFLE',price=type===4?35:type===1?18:type===2?8:/UavTerminal/i.test(c.id)?25:10;
  const mags=new Set(val('CfgWeapons',c,'magazines')||[]);for(const muzzle of Object.values(c.classes))for(const id of muzzle.values?.magazines||[])mags.add(id);
  gear.push({class:c.id,kind,category,label:String(val('CfgWeapons',c,'displayName')||c.id),price,mod:c.mod,modPath:c.modPath,magazines:[...mags]});
 }
 for(const c of tables.CfgMagazines.values())if([1,2].includes(val('CfgMagazines',c,'scope'))&&Number(val('CfgMagazines',c,'count'))>0)gear.push({class:c.id,kind:'MAGAZINE',category:/shell|155mm|120mm|105mm|82mm|mortar|arty|artillery|mlrs|230mm|122mm|125mm|30mm|40mm|20mm/i.test(c.id)?'SHELL':/rocket|missile|atgm|titan|nlaw|rpg|strela|stinger|jav/i.test(c.id)?'ROCKET':/grenade|mine|satchel|charge|ied/i.test(c.id)?'EXPLOSIVE':'SMALL_AMMO',label:String(val('CfgMagazines',c,'displayName')||c.id),price:/rocket|missile|atgm|titan/i.test(c.id)?12:2,mod:c.mod,modPath:c.modPath});
 for(const c of tables.CfgGlasses.values())if(val('CfgGlasses',c,'scope')===2)gear.push({class:c.id,kind:'GLASSES',label:String(val('CfgGlasses',c,'displayName')||c.id),price:4,mod:c.mod,modPath:c.modPath});
 for(const c of tables.CfgVehicles.values()){
  if((val('CfgVehicles',c,'isBackpack')===1||ancestor('CfgVehicles',c,/^(Bag_Base|B_AssaultPack_Base|B_Kitbag_Base|B_Carryall_Base|B_Bergen_Base)$/i))&&(val('CfgVehicles',c,'scope')===2||val('CfgVehicles',c,'scope')===1&&referenced.has(c.id.toLowerCase())))gear.push({class:c.id,kind:'BACKPACK',label:String(val('CfgVehicles',c,'displayName')||c.id),price:12,mod:c.mod,modPath:c.modPath});
  vehicles[c.id]={artillery:Number(val('CfgVehicles',c,'artilleryScanner'))===1,faction:String(val('CfgVehicles',c,'faction')||'')};
  const side=val('CfgVehicles',c,'side'),scope=val('CfgVehicles',c,'scope');if(scope===2&&[0,1,2,3].includes(side)&&!infantry.has(c.id)){const kind=ancestor('CfgVehicles',c,/^Plane$/i)?'PLANE':ancestor('CfgVehicles',c,/^Helicopter$/i)?'HELICOPTER':ancestor('CfgVehicles',c,/^Ship$/i)?'SHIP':ancestor('CfgVehicles',c,/^StaticWeapon$/i)?'STATIC':ancestor('CfgVehicles',c,/^Tank$/i)?'TANK':ancestor('CfgVehicles',c,/^Car$/i)?(Number(val('CfgVehicles',c,'transportSoldier'))>=4?'APC':'CAR'):'';if(kind)assets.push({class:c.id,label:String(val('CfgVehicles',c,'displayName')||c.id),side,kind,cargo:Number(val('CfgVehicles',c,'transportSoldier'))||0,isUav:val('CfgVehicles',c,'isUav')===1,faction:vehicles[c.id].faction,mod:c.mod,modPath:c.modPath});}
  const a=infantry.get(c.id);if(!a)continue;
  units[c.id]={faction:a.faction,items:[...(val('CfgVehicles',c,'weapons')||[]),...(val('CfgVehicles',c,'magazines')||[]),...(val('CfgVehicles',c,'linkedItems')||[]),val('CfgVehicles',c,'uniformClass'),val('CfgVehicles',c,'backpack')].filter(id=>typeof id==='string'&&id)};
 }
 const factions=Object.fromEntries([...tables.CfgFactionClasses.values()].map(c=>[c.id,String(val('CfgFactionClasses',c,'displayName')||c.id)]));
 const result={version:1,evidence:'installed_config_not_engine',scannedAt:new Date().toISOString(),gear,units,vehicles,assets,infantry:[...infantry.values()],factions,errors};
 fs.writeFileSync(path.join(root,'dist/campaign-inventory.json'),JSON.stringify(result));console.log(JSON.stringify({gear:gear.length,units:Object.keys(units).length,artillery:Object.values(vehicles).filter(a=>a.artillery).length,errors:errors.length}));return result;
}
if(require.main===module)scan();module.exports={scan};
