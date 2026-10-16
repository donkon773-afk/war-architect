'use strict';
// Read-only index: libraries retain their own ids, revisions and save contracts.
function list({maps=require('./map-presets').list(),operations=require('./operations').list(),state=require('./core').load(),worlds=require('./scenario-design').worlds()}={}){
  const worldName=id=>worlds.find(w=>w.id===id)?.label||id;
  const rows=maps.map(p=>({key:'map:'+p.id,id:p.id,kind:'map',mode:'warlords',title:p.name,world:p.world,worldLabel:worldName(p.world),detail:(p.mode==='three'?'Три стороны':'Warlords')+' · '+p.sectors+' целей · '+p.bases+' базы',updatedAt:p.updatedAt}));
  for(const p of operations)rows.push({key:'operation:'+p.id,id:p.id,kind:'operation',mode:p.type,title:p.title,world:p.world,worldLabel:worldName(p.world),detail:{airBattle:'Воздушное сражение',assaultDefense:'Штурм и оборона',frontlineCampaign:'Фронт и снабжение'}[p.type]||p.type,updatedAt:p.updatedAt});
  for(const [name,p] of Object.entries(state.presets||{}))rows.push({key:'profile:'+name,id:name,kind:'profile',mode:p.scenario==='antistasi'?'antistasi':'warlords',title:name,world:p.map,worldLabel:worldName(p.map),detail:'Пресет запуска · '+(p.scenario==='antistasi'?'Antistasi':'Warlords')});
  return {items:rows,counts:{maps:maps.length,operations:operations.length,profiles:Object.keys(state.presets||{}).length}};
}
module.exports={list};
