(() => {
 let attempts=0;const ready=setInterval(()=>{
  if(++attempts>100){clearInterval(ready);return;}
  if(typeof bootstrap==='undefined'||!bootstrap||typeof draft==='undefined'||!draft)return;
  clearInterval(ready);
  window.NeroOP_renderMods=()=>{
   if(!bootstrap.mods)return;
   let root=document.getElementById('extraMods');
   if(!root){let panel=document.querySelector('[data-required-mod-panel]');if(!panel){panel=document.createElement('details');panel.dataset.requiredModPanel='';const title=document.createElement('summary');title.textContent='Обязательные и дополнительные моды';panel.append(title);document.querySelector('[data-page="main"] .card').append(panel);}root=panel.querySelector('.required-mod-content');if(!root){root=document.createElement('div');root.className='required-mod-content';panel.append(root);}}
   root.replaceChildren();const rows=NeroModPolicy.requirements(draft,bootstrap.mods),required=new Set(rows.filter(r=>r.id).map(r=>r.id));
   for(const a of draft.sides||[]){for(const id of [...(a.classes||[]),a.truckClass,...(a.shop||[]).map(r=>r.class)]){const c=[...(bootstrap.catalog||[]),...(bootstrap.equipmentCatalog||[]),...(bootstrap.trucks||[])].find(c=>c.class===id);if(c?.modPath)required.add(c.modPath);}for(const g of a.gear||[]){const c=bootstrap.gearCatalog?.find(c=>c.class===g.class&&c.kind===g.kind);if(c?.modPath)required.add(c.modPath);}}
   const title=document.createElement('label'),locked=document.createElement('input');locked.type='checkbox';locked.checked=true;locked.disabled=true;locked.setAttribute('aria-label','Обязательные моды подключать всегда');title.className='check';title.append(locked,document.createTextNode('Обязательные моды — подключать всегда'));root.append(title);
   const note=document.createElement('p');note.className='small';note.textContent='Сборщик автоматически добавляет зависимости выбранных механик. Если обязательного мода или его файлов нет, сборка и запуск останавливаются с объяснением.';root.append(note);
   const row=(name,checked,disabled,reason,onchange)=>{const l=document.createElement('label'),c=document.createElement('input');l.className='check';c.type='checkbox';c.checked=checked;c.disabled=disabled;c.setAttribute('aria-label',name);if(onchange)c.onchange=onchange;const text=document.createElement('span');text.textContent=name;const help=document.createElement('small');help.style.display='block';help.textContent=reason;l.append(c,text);text.append(help);root.append(l);return c;};
   for(const r of rows)row(r.label+(r.generated?' · собирается автоматически':r.id?' · обязательно':' · не установлен'),!!r.id||!!r.generated,true,r.reason);
   const coreIDs=new Set(rows.map(r=>r.id).filter(Boolean));for(const m of bootstrap.mods.filter(m=>required.has(m.id)&&!coreIDs.has(m.id)))row(m.label+' · состав / обязательно',true,true,'Используется выбранным составом войск.');
   const optional=bootstrap.mods.filter(m=>!required.has(m.id));const selected=new Set(draft.extraMods||[]);
   const all=row('Включить все дополнительные моды',optional.length>0&&optional.every(m=>selected.has(m.id)),optional.length===0,'Обязательные моды сохраняются при снятии этой отметки.',()=>{const keep=(draft.extraMods||[]).filter(id=>required.has(id));draft.extraMods=all.checked?[...new Set([...keep,...optional.map(m=>m.id)])]:keep;mark();window.NeroOP_renderMods();});all.indeterminate=optional.some(m=>selected.has(m.id))&&!all.checked;
   for(const m of optional){const c=row(m.label,selected.has(m.id),false,'Дополнительный мод.',()=>{draft.extraMods=c.checked?[...new Set([...(draft.extraMods||[]),m.id])]:(draft.extraMods||[]).filter(id=>id!==m.id);mark();});}
  };
  if(typeof fill==='function'){const before=fill;fill=function(...args){const result=before.apply(this,args);window.NeroOP_renderMods();return result;};}
  if(typeof renderAdvanced==='function'){const before=renderAdvanced;renderAdvanced=function(...args){const result=before.apply(this,args);window.NeroOP_renderMods();return result;};}
  document.addEventListener('change',e=>{if(e.target.dataset.experiment)window.NeroOP_renderMods();});
  window.NeroOP_renderMods();
 },100);
})();
