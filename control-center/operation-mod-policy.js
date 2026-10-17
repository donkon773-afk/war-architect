(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.NeroModPolicy=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
 'use strict';
 // Shared display/build policy; requirements are mandatory and cannot be disabled by extraMods.
 function requirements(design,mods){
  const campaign=['frontlineCampaign','becti'].includes(design.type),realistic=campaign&&design.devMode?.realisticMissiles;
  const rules=[
   {key:'ace',label:'ACE',name:'@ace',patch:'ace_main',files:['ace_main.pbo',...(campaign?['ace_missileguidance.pbo','ace_missile_sam.pbo']:[])],reason:campaign?'Механики ACE, наведение ракет и Patriot':'Механики ACE'},
   {key:'cba',label:'CBA A3',name:'@CBA_A3',patch:'cba_main',files:['cba_main.pbo'],reason:'Зависимость ACE и обработчиков модов'}
  ];
  if(campaign)rules.push(
   {key:'fp5',label:'FP-5 Flamingo',name:'@FP-5 -Flamingo-',patch:'kba_fp5_flamingo',files:['kba_fp5_flamingo.pbo'],reason:'Физическая ракета и модель радиолокационной цели'},
   {key:'rhsafrf',label:'RHS AFRF',name:'@RHSAFRF',patch:'rhs_c_airweapons',files:['rhs_c_airweapons.pbo'],reason:'Вооружение RHS и совместимость NeroAI Strategic'}
  );
  if(realistic)rules.push(
   {key:'tt',label:'Blastcore Murr Edition (TT Version)',name:'@Blastcore Murr Edition(TT Version)',patch:'TT_added_bombs',files:['TT_added_bombs.pbo'],reason:'Х-47М2, Х-101/555, JASSM, «Калибр» и «Оникс»'},
   {key:'rhsusaf',label:'RHS USAF',name:'@RHSUSAF',files:['rhsusf_c_heavyweapons.pbo'],reason:'ATACMS и его кассетные боеприпасы'},
   {key:'fmc',label:'FMC PACK',name:'@FMC PACK',files:['OFP_ATACMS.pbo'],reason:'ATACMS M57 и пусковая M270'},
   {key:'3cb',label:'3CB Factions',name:'@3CB Factions',files:['uk3cb_factions_vehicles_scud.pbo'],reason:'Scud и его пусковые'}
  );
  if(design.type==='becti'){
   rules.push({key:'rhsgref',label:'RHS GREF',name:'@RHSGREF',files:['rhsgref_main.pbo'],reason:'Нейтральные гарнизоны исходной BECTI'});
   if(!realistic)rules.push({key:'rhsusaf',label:'RHS USAF',name:'@RHSUSAF',files:['rhsusf_main.pbo'],reason:'Штатные вспомогательные системы BECTI'});
  }
  const rows=rules.map(r=>{const m=mods.find(m=>(m.label||m.name).toLowerCase()===r.name.toLowerCase())||mods.find(m=>r.patch&&(m.patches||[]).some(p=>p.toLowerCase()===r.patch.toLowerCase()));return {...r,id:m?.id||m?.path||null,installed:!!m};});
  if(campaign)rows.push(
   {key:'strategic',label:'NeroAI Strategic',generated:true,reason:'Совместимость спецоружия; собирается автоматически'},
   {key:'ad',label:'NeroAI AirDefense',generated:true,reason:'РЛС, сетевое наведение и режим Patriot; собирается автоматически'}
  );
  if(realistic)rows.push({key:'missiles',label:'NeroAI Missile Profiles',generated:true,reason:'Полёт Х-47М2 и ракетные профили; собирается автоматически'});
  return rows;
 }
 return {requirements};
});
