'use strict';
const equipment=require('../control-center/campaign-equipment');
const q=s=>'"'+String(s||'').replaceAll('"','""')+'"';
function config(d){
 const vehicles=new Map(equipment.catalog().map(r=>[r.class,r])),gear=new Map(equipment.gearCatalog().map(r=>[r.class.toLowerCase(),r]));
 return 'class CfgWarArchitectShop {'+d.sides.map(a=>{
  const infantryPrice=Math.max(5,Math.ceil(d.reinforcementCost/a.groupSize));
  const crew=a.classes.find(c=>/crew/i.test(c))||a.classes[0],pilot=a.classes.find(c=>/pilot/i.test(c))||crew;
  const rows=[...a.classes.map(c=>({class:c,table:'CfgVehicles',kind:'INFANTRY',category:'INFANTRY',mod:equipment.infantryCatalog().find(r=>r.class===c)?.mod,price:infantryPrice})),...a.shop.map(r=>{const c=vehicles.get(r.class);return {...r,table:'CfgVehicles',kind:'VEHICLE',category:c.category,mod:c.mod,aiRole:equipment.aiRole(c)};}),...a.gear.map(r=>{const c=gear.get(r.class.toLowerCase());return {...r,table:r.kind==='MAGAZINE'?'CfgMagazines':r.kind==='BACKPACK'?'CfgVehicles':r.kind==='GLASSES'?'CfgGlasses':'CfgWeapons',category:c?.category||'GEAR',mod:c?.mod};})];
  return `class ${a.side} {crewClass=${q(crew)};pilotClass=${q(pilot)};crewPrice=${infantryPrice};class Rows {`+rows.map((r,i)=>`class Item${i} {className=${q(r.class)};table=${q(r.table)};kind=${q(r.kind)};category=${q(r.category)};aiRole=${q(r.aiRole||'')};mod=${q(r.mod||'Arma 3')};price=${r.price};};`).join('')+'};};';
 }).join('')+'};\n';
}
module.exports={config};
