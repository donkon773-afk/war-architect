/* Same-origin editor integration: the shell mounts each settings element once. */
(() => {
  const integrated=new URLSearchParams(location.search).get('workspace')==='1'&&embedded;
  if(!embedded){location.replace('/?tab=maps&world='+encodeURIComponent(new URLSearchParams(location.search).get('world')||''));return;}
  if(!integrated)return;
  document.body.classList.add('workspace-editor');
  const element=id=>document.getElementById(id)||window.parent.document.getElementById('editor-'+id);
  async function changeWorld(id,{discard=false}={}){
    if(design?.world===id&&!discard)return true;
    if(dirty&&!discard&&!confirm('В карте есть несохранённые изменения. Переключить карту без их сохранения?'))return false;
    await load(id);await refreshPresets();return true;
  }
  async function saveForPlay(army){
    if(canon(design.army)!==canon(army))putArmySetup(structuredClone(army));
    if(by('mapPresetName').value.trim())await saveAsNewPreset();
    if(dirty)await saveCurrent();
    else if(editing.kind==='design'&&!design.savedAt)await saveCurrent();
    if(editing.kind==='preset'){
      let applied=await api('/api/design?world='+encodeURIComponent(design.world));
      if(canon(applied)!==canon(collectDesign())){await api('/api/map-preset-apply',{id:editing.id});applied=await api('/api/design?world='+encodeURIComponent(design.world));}
      if(canon(applied)!==canon(collectDesign()))throw Error('Карта не совпала с сохранённым пресетом. Запуск остановлен.');
      design.savedAt=applied.savedAt;editing.inGame=true;
      await refreshPresets();
    }
    return structuredClone(collectDesign());
  }
  window.NeroEditor={element,snapshot:()=>structuredClone(collectDesign()),changed:()=>{if(design)markDirty();},saveDraft:saveCurrent,
    setArmy:army=>{if(canon(design.army)!==canon(army))putArmySetup(structuredClone(army));},
    changeWorld,saveForPlay,openPreset:async id=>{await openPresetById(id);return editing.id===id;}};
  const originalRestore=restoreHistory;
  restoreHistory=function(redo){originalRestore(redo);notifyParent({type:'opened',world:design.world});};
  by('openSetups').onclick=()=>notifyParent({type:'navigate',tab:'setups'});
  by('save').onclick=()=>notifyParent({type:'save-all'});
  by('useOpenPreset').onclick=()=>notifyParent({type:'save-all'});
  useInGame=async p=>notifyParent({type:'use-preset',id:p.id});
  by('world').hidden=true;by('save').hidden=true;by('useOpenPreset').hidden=true;by('openSetups').hidden=true;
  const settings=document.createElement('button');settings.type='button';settings.textContent='Параметры сценария';settings.onclick=()=>notifyParent({type:'navigate',tab:'launch',page:'overview'});document.querySelector('header').append(settings);
  for(const tab of ['scenario','resources','start','llm','armies'])document.querySelector('[data-tab="'+tab+'"]').hidden=true;
  showTab('points');
  const toolbar=document.querySelector('.map-controls');document.body.insertBefore(toolbar,document.querySelector('main'));
  const fit=document.createElement('button');fit.type='button';fit.id='fitPoints';fit.textContent='К точкам';fit.dataset.help='Показать все базы и сектора крупным планом. Shift+F.';
  function fitPoints(){
    const points=design.bases.concat(design.sectors,design.spawns);if(!points.length)return by('fit').click();
    const xs=points.map(p=>p.position[0]),ys=points.map(p=>currentWorld().size-p.position[1]);
    const span=Math.min(currentWorld().size*1.2,Math.max(400,Math.max(Math.max(...xs)-Math.min(...xs),Math.max(...ys)-Math.min(...ys))*1.3));
    view=[(Math.min(...xs)+Math.max(...xs)-span)/2,(Math.min(...ys)+Math.max(...ys)-span)/2,span,span];paint();
  }
  fit.onclick=fitPoints;toolbar.insertBefore(fit,by('panTool'));
  const inspector=document.createElement('button');inspector.type='button';inspector.textContent='Панель точек';inspector.setAttribute('aria-expanded','true');inspector.onclick=()=>{const hidden=document.body.classList.toggle('inspector-collapsed');inspector.setAttribute('aria-expanded',String(!hidden));};toolbar.append(inspector);
  function nearest(pos){
    let result=null,best=Infinity;const scale=by('map').getScreenCTM()?.a||1;
    for(const type of ['bases','sectors','spawns'])for(const p of design[type]){
      const distance=Math.hypot(p.position[0]-pos[0],p.position[1]-pos[1]);
      if(distance<=Math.max(p.radius,18/scale)&&distance<best){best=distance;result={point:p,type};}
    }
    return result;
  }
  let space=false,frame=0;
  const repaint=()=>{if(!frame)frame=requestAnimationFrame(()=>{frame=0;paint();});};
  by('map').onwheel=e=>{
    if(!design)return;e.preventDefault();
    const span=Math.min(currentWorld().size*2,Math.max(80,view[2]*(e.deltaY>0?1.15:1/1.15))),factor=span/view[2];
    const pos=xy(e),y=currentWorld().size-pos[1];
    view=[pos[0]-(pos[0]-view[0])*factor,y-(y-view[1])*factor,span,span];repaint();
  };
  by('map').onpointerdown=e=>{
    if(!design||![0,1].includes(e.button))return;
    const hit=!space&&e.button===0&&by('tool').value==='select'?nearest(xy(e)):null;
    if(hit)choose(hit.point,hit.type);
    down={x:e.clientX,y:e.clientY,view:[...view],scale:by('map').getScreenCTM().a,
      point:hit?.point,origin:hit?[...hit.point.position]:null,pan:space||e.button===1};
    by('map').setPointerCapture(e.pointerId);e.preventDefault();
  };
  by('map').onpointermove=e=>{
    if(!design)return;
    const pos=xy(e).map(Math.round);by('mapCoordinates').textContent='X '+pos[0]+' · Y '+pos[1]+' м';
    if(!down||Math.hypot(e.clientX-down.x,e.clientY-down.y)<=5)return;
    down.moved=true;
    if(down.point){
      down.point.position=[down.origin[0]+(e.clientX-down.x)/down.scale,down.origin[1]-(e.clientY-down.y)/down.scale].map(v=>Math.round(Math.min(currentWorld().size,Math.max(0,v))));
      by('pointX').value=down.point.position[0];by('pointY').value=down.point.position[1];
    }else{view[0]=down.view[0]-(e.clientX-down.x)/down.scale;view[1]=down.view[1]-(e.clientY-down.y)/down.scale;}
    repaint();
  };
  by('map').onpointerup=e=>{
    if(!down)return;const action=down;down=null;
    if(action.point){if(action.moved){markDirty();list();paint();}return;}
    if(action.moved||action.pan)return;
    const pos=xy(e).map(Math.round),size=currentWorld().size,type=by('tool').value;
    if(pos.some(v=>v<0||v>size))return;
    if(type==='select'){const hit=nearest(pos);if(hit)choose(hit.point,hit.type);return;}
    const side=by('side').value;
    if(type==='bases')design.bases=design.bases.filter(p=>p.side!==side);
    const point={id:crypto.randomUUID(),name:by('name').value||({bases:'База',sectors:'Сектор',spawns:'Спавн'})[type],side,position:pos,radius:+by('radius').value,infantry:+by('infantry').value,vehicles:+by('vehicles').value,vehicleClasses:[...by('vehicleClasses').selectedOptions].map(o=>o.value)};
    design[type].push(point);choose(point,type);markDirty();list();paint();
    if(!e.shiftKey){by('tool').value='select';by('tool').onchange();}
  };
  function cancelDrag(){if(down?.point){down.point.position=down.origin;by('pointX').value=down.origin[0];by('pointY').value=down.origin[1];paint();}down=null;}
  by('map').onpointercancel=cancelDrag;
  window.addEventListener('blur',()=>{space=false;cancelDrag();});
  window.addEventListener('keyup',e=>{if(e.code==='Space')space=false;});
  window.addEventListener('keydown',e=>{
    if(['INPUT','TEXTAREA','SELECT'].includes(e.target.tagName))return;
    if(e.code==='Space'){space=true;e.preventDefault();}
    if(e.key==='Escape'){cancelDrag();by('tool').value='select';by('tool').onchange();}
    if(e.key==='Delete'&&selected){e.preventDefault();by('remove').click();}
    if(e.shiftKey&&e.key.toLowerCase()==='f'){e.preventDefault();fitPoints();}
  });
  NeroHelp.bind(document,{},text=>notifyParent({type:'help',text}));
  const ready=setInterval(()=>{if(!design)return;clearInterval(ready);notifyParent({type:'workspace-ready',world:design.world});},100);
})();
