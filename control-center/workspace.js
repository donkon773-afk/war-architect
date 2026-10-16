/* Unified shell. Scenario controls are moved, not copied: the editor's live
 * elements retain their handlers and are resolved through its scoped lookup. */
(() => {
  document.body.classList.add('workspace-shell');
  const originalTabs=showAppTab, originalRender=render, originalSummary=updateSummary;
  const originalSave=save, originalApply=apply, originalLaunch=by('launch').onclick;
  let editor=null, pendingEditor=null, busy=false, activeTab='launch';
  const extraPanels={setups:'setupsPanel',operations:'operationsPanel',devmode:'devmodePanel',missions:'missionsPanel'};
  const focusMap=document.createElement('button');focusMap.type='button';focusMap.className='map-focus-toggle';focusMap.textContent='Развернуть карту';focusMap.setAttribute('aria-pressed','false');
  focusMap.onclick=()=>{const focused=document.body.classList.toggle('map-focus');focusMap.textContent=focused?'Обычный вид':'Развернуть карту';focusMap.setAttribute('aria-pressed',String(focused));};
  document.querySelector('.designer-intro').append(focusMap);
  const overview=by('setup-overview');overview.prepend(by('designScenarioHost'));
  for(const [id,text] of [['aiLLM','LLM-командиры'],['aiVanilla','Штатный ИИ Arma'],['aiTactical','Тактический ИИ NeroAI']]){
    const input=by(id),label=input.closest('label');input.dataset.help=label.textContent.trim();label.querySelector('span').textContent=text;
  }
  const overviewName=document.querySelector('[data-setup="overview"] strong');if(overviewName)overviewName.textContent='Общие параметры';
  function displayTab(tab){
    activeTab=tab;
    if(tab!=='maps'){document.body.classList.remove('map-focus');focusMap.textContent='Развернуть карту';focusMap.setAttribute('aria-pressed','false');}
    originalTabs(tab);
    for(const [key,id] of Object.entries(extraPanels))by(id).hidden=key!==tab;
    for(const key of Object.keys(extraPanels))by(key+'Tab').setAttribute('aria-selected',String(key===tab));
    document.body.dataset.workspaceTab=tab;
    if(tab==='missions')NeroMissionLibrary.refresh();
    if(tab==='setups' && by('setupsFrame').getAttribute('src')==='about:blank')by('setupsFrame').src='/setups?embedded=1';
    if(tab==='operations' && by('operationsFrame').getAttribute('src')==='about:blank')openOperations();
    if(tab==='maps' && state){if(!by('useDesign').checked){by('useDesign').checked=true;dirty=true;}updateSummary();}
  }
  showAppTab=displayTab;
  by('setupsTab').onclick=()=>displayTab('setups');
  by('operationsTab').onclick=()=>displayTab('operations');
  by('devmodeTab').onclick=()=>displayTab('devmode');
  by('missionsTab').onclick=()=>displayTab('missions');
  by('openSetups').onclick=()=>displayTab('setups');
  by('operationsLink').onclick=e=>{e.preventDefault();displayTab('operations');};
  let operationsLoading=false;
  async function openOperations(routeOverride,id){
    if(operationsLoading)return;operationsLoading=true;const note=by('operationsPanel').querySelector('p');note.textContent='Открываем конструктор операций…';
    try{const result=await api('/api/operations-panel',{});const requested=routeOverride||new URLSearchParams(location.search).get('operation');const route=['ground','campaign'].includes(requested)?requested:'operations';by('operationsFrame').src=result.origin+'/'+route+'?embedded=1'+(id?'&id='+encodeURIComponent(id):'');note.textContent='Воздушные операции, штурм и кампания — внутри одного центра.';return true;}
    catch(e){note.textContent=e.message+' Нажмите вкладку «Операции», чтобы повторить.';return false;}
    finally{operationsLoading=false;}
  }
  async function canReplaceOperation(){
    const frame=by('operationsFrame'),src=frame.getAttribute('src');if(src==='about:blank')return true;
    const origin=new URL(src).origin,requestId=crypto.randomUUID();
    const status=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>{window.removeEventListener('message',listen);reject(Error('Редактор операции ещё загружается. Повторите открытие через несколько секунд.'));},2000);function listen(e){if(e.source!==frame.contentWindow||e.origin!==origin||e.data?.source!=='nero-operation-state'||e.data.requestId!==requestId)return;clearTimeout(timer);window.removeEventListener('message',listen);resolve(e.data);}window.addEventListener('message',listen);frame.contentWindow.postMessage({type:'nero-workspace-state-request',requestId},origin);});
    if(status.busy)throw Error('Дождитесь завершения сохранения или сборки операции.');
    return !status.dirty||confirm('В операции есть несохранённые изменения. Открыть другой сценарий без их сохранения?');
  }
  window.NeroWorkspace={openMission:async p=>{
    if(p.kind==='profile')return applyPreset(p.id);
    if(busy)return;
    if(p.kind==='operation'){
      if(!await canReplaceOperation())return;
      if(!await openOperations({airBattle:'operations',assaultDefense:'ground',frontlineCampaign:'campaign'}[p.mode],p.id))throw Error('Не удалось открыть редактор операции. Повторите попытку.');displayTab('operations');return;
    }
    if((dirty||designerDirty)&&!confirm('Открыть сценарий «'+p.title+'» вместо несохранённых настроек и карты?'))return;
    busy=true;document.querySelector('main').inert=true;
    try{const e=await editorReady();if(await e.openPreset(p.id)){by('useDesign').checked=true;acceptEditor();dirty=true;displayTab('maps');updateSummary();message('Открыт сценарий «'+p.title+'». «Сохранить всё» сохранит выбранную карту и настройки запуска.');}}
    finally{busy=false;document.querySelector('main').inert=false;}
  }};
  function mountPanel(id,host){
    const node=editor.element(id);
    if(!node || node.ownerDocument===document)return;
    for(const el of [node,...node.querySelectorAll('[id]')])if(el.id){el.dataset.editorId=el.id;el.id='editor-'+el.id;}
    for(const label of node.querySelectorAll('label[for]'))label.htmlFor='editor-'+label.htmlFor;
    node.hidden=false;
    by(host).append(node);
    node.addEventListener('change',()=>{editor.changed();dirty=true;updateSummary();});
  }
  function acceptEditor(){
    editor=by('designerFrame').contentWindow.NeroEditor;
    if(!editor)return;
    mountPanel('panel-scenario','designScenarioHost');
    mountPanel('panel-resources','designResourcesHost');
    mountPanel('panel-start','designStartHost');
    mountPanel('panel-llm','designLLMHost');
    const duplicate=by('editor-greenFaction');if(duplicate)duplicate.closest('label').hidden=true;
    // The parent catalog is the sole visible army/infantry editor.
    const snapshot=editor.snapshot();
    if(snapshot.army){const wasDirty=dirty;putArmy(snapshot.army);dirty=wasDirty;}
    by('map').value=snapshot.world;
    designSummaryKey='';updateSummary();
    pendingEditor?.resolve(editor);pendingEditor=null;
    const lockACE=()=>{const input=document.getElementById('ace');if(input){const required=document.getElementById('scenario')?.value==='warlords';input.disabled=required;if(required)input.checked=true;input.setAttribute('aria-description',required?'Обязательный мод механик. Подключается всегда.':'Настройка ACE.');}};const previousRender=render;render=function(...args){const result=previousRender.apply(this,args);lockACE();return result;};document.getElementById('scenario')?.addEventListener('change',lockACE);lockACE();
  NeroHelp.bind(document,helpText);
  }
  openDesignerFrame=function(){
    const frame=by('designerFrame');if(!frame||!state)return;
    if(frame.getAttribute('src')==='about:blank')frame.src='/designer?embedded=1&workspace=1&world='+encodeURIComponent(by('map').value);
  };
  function editorReady(){
    if(editor)return Promise.resolve(editor);
    openDesignerFrame();
    if(!pendingEditor){
      let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});
      const timer=setTimeout(()=>{pendingEditor=null;reject(Error('Редактор не загрузился. Сохранение остановлено; изменения остаются на странице.'));},20000);
      pendingEditor={promise,resolve:value=>{clearTimeout(timer);resolve(value);}};
    }
    return pendingEditor.promise;
  }
  updateSummary=function(){
    originalSummary();
    const designed=by('scenario').value==='warlords'&&by('useDesign').checked;
    document.body.classList.toggle('designed-scenario',designed);
    for(const id of ['designScenarioHost','designResourcesHost','designStartHost','designLLMHost'])by(id).hidden=!designed;
    const startCP=by('BIS_WLStartCP');if(startCP){startCP.parentElement.hidden=designed;startCP.parentElement.dataset.scenarioDuplicate='1';}
    if(designed&&editor){const d=editor.snapshot();by('summaryPlayer').textContent=d.playerRole==='observer'?'Наблюдатель · бой между ботами':'Игрок — командир';by('summaryArmy').textContent=by('commanders').value+' командиров на сторону · техника: '+['west','east','green'].map(p=>armySelected[p].size).join(' / ');}
    by('dirtyStatus').textContent=dirty||designerDirty?'Есть изменения':'Сохранено';
    by('dirtyStatus').classList.toggle('pending',dirty||designerDirty);
  };
  updateDesignSummary=async()=>{};
  render=function(next){originalRender(next);if(next.selected.scenario==='warlords'&&(next.selected.useDesign||activeTab==='maps')){if(activeTab==='maps'){by('useDesign').checked=true;const requested=new URLSearchParams(location.search).get('world');if(next.maps.some(w=>w.id===requested))by('map').value=requested;}openDesignerFrame();updateSummary();}};
  applyPreset=async function(name){
    const preset=state.presets?.[name];if(!preset||busy)return;
    if((dirty||designerDirty)&&!confirm('Применить пресет «'+name+'» вместо несохранённых настроек сценария и карты?'))return;
    busy=true;document.querySelector('main').inert=true;
    try{
      if(preset.scenario==='warlords'&&preset.useDesign){const e=await editorReady();await e.changeWorld(preset.map,{discard:true});}
      originalApply(preset);
      if(editor&&preset.scenario==='warlords'&&preset.useDesign){editor.setArmy(composeArmy());acceptEditor();}
      viewedPreset=name;by('preset').value=name;dirty=true;renderPresets();updateDesignerLink();displayTab('launch');showSetup('overview');updateSummary();
      message('Пресет «'+name+'» открыт. «Сохранить всё» сохранит карту, армии и запуск вместе.');
    }catch(error){message(error.message,true);}finally{busy=false;document.querySelector('main').inert=false;}
  };
  async function saveAll(name){
    if(busy)throw Error('Сохранение уже выполняется. Дождитесь завершения.');
    busy=true;by('save').disabled=true;document.querySelector('main').inert=true;
    try{
      if(by('scenario').value==='warlords'&&by('useDesign').checked){
        const e=await editorReady();
        const d=await e.saveForPlay(composeArmy());
        by('map').value=d.world;designerDirty=false;
      }else if(editor&&designerDirty&&by('scenario').value==='warlords'){await editor.saveDraft();designerDirty=false;}
      await originalSave(name);
      designSummaryKey='';updateSummary();
      message('✓ Сценарий сохранён: карта, армии и настройки запуска. При запуске миссия будет собрана и добавлена в Arma.');
    }catch(error){dirty=true;updateSummary();throw error;}
    finally{busy=false;by('save').disabled=false;document.querySelector('main').inert=false;}
  }
  save=saveAll;
  by('save').onclick=()=>saveAll().catch(e=>message('Не сохранено: '+e.message,true));
  by('launch').onclick=async()=>{try{await saveAll();await originalLaunch();}catch(e){message('Запуск отменён: '+e.message,true);}};
  by('map').addEventListener('change',async()=>{
    if(!editor)return;
    try{const ok=await editor.changeWorld(by('map').value);if(!ok)by('map').value=editor.snapshot().world;else acceptEditor();}
    catch(e){by('map').value=editor.snapshot().world;message(e.message,true);}
    finally{updateSummary();}
  });
  by('useDesign').addEventListener('change',()=>{if(by('useDesign').checked)openDesignerFrame();updateSummary();});
  const originalPutArmy=putArmy;
  putArmy=function(army){originalPutArmy(army);if(editor&&by('useDesign').checked)editor.setArmy(composeArmy());};
  for(const id of ['armyBox','infantryBox'])for(const event of ['change','click'])by(id).addEventListener(event,()=>queueMicrotask(()=>{if(editor&&by('useDesign').checked)editor.setArmy(composeArmy());}));
  window.addEventListener('message',async e=>{
    if(e.origin!==location.origin || e.source!==by('designerFrame').contentWindow || e.data?.source!=='nero-designer')return;
    const d=e.data;
    if(d.type==='workspace-ready'||d.type==='opened')acceptEditor();
    if(d.type==='dirty'||d.type==='saved'){designerDirty=!!d.dirty;updateSummary();}
    if(d.type==='navigate'){displayTab(d.tab||'launch');if(d.page)showSetup(d.page);}
    if(d.type==='help')NeroHelp.show(d.text);
    if(d.type==='save-all')by('save').click();
    if(d.type==='use-preset'){
      if(busy)return;busy=true;document.querySelector('main').inert=true;let opened=false;
      try{const ready=await editorReady();opened=await ready.openPreset(d.id);if(opened){acceptEditor();by('useDesign').checked=true;}}
      catch(error){message(error.message,true);}
      finally{busy=false;document.querySelector('main').inert=false;}
      if(opened)try{await saveAll();}catch(error){message(error.message,true);}
    }
  });
  window.addEventListener('message',e=>{if(e.origin===location.origin&&e.data?.source==='nero-side-setups'&&e.data.type==='navigate')displayTab('launch');});
  window.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='s'&&activeTab!=='setups'){e.preventDefault();by('save').click();}});
  const helpText={
    map:'Выберите территорию. При смене карты редактор предложит сохранить несохранённые правки.',
    useDesign:'Использовать базы, сектора, армии и ресурсы открытого сценария. Кнопка «Сохранить всё» сохранит и карту, и запуск.',
    profile:'Постоянный профиль Arma: имя, настройки управления и пользовательские параметры игры.',
    commanders:'Количество самостоятельных командиров на каждую сторону. Каждый командир управляет собственным отрядом.',
    title:'Название вашей миссии в списке Arma и библиотеке сценариев.',
    mode:'Два противника в Warlords или собственный режим с тремя воюющими сторонами.',
    greenRole:'В режиме Warlords зелёные защищают города. В режиме трёх сторон могут захватывать сектора.',
    playerRole:'Командир участвует в бою. Наблюдатель получает Зевса и наблюдает сражение ботов.',
    playerSide:'Сторона игрока при входе в миссию. В Warlords доступны синие и красные.',
    maxNPCs:'Общий бюджет новых бойцов и экипажей сценария. Большие значения увеличивают нагрузку на процессор.',
    maxVehicles:'Общий бюджет техники сценария; учитывает стартовые машины и новые покупки.',
    startCP:'Стартовые очки покупки каждого командира. Для сценария карты это единственное поле стартовых CP.',
    income:'Доход одного удерживаемого сектора в CP за минуту. Множитель дохода в правилах применяется отдельно.',
    lethalZones:'Ограничивает пребывание за пределами разрешённых целей. Отключите для свободного манёвра.',
    radius:'Радиус зоны сектора в метрах. На карте показан цветным кругом.',
    infantry:'Число защитников сектора. Экипажи техники считаются отдельно.',
    vehicles:'Сколько машин добавить в гарнизон выбранного сектора.',
    pointX:'Координата X в метрах Arma. Точку также можно перетащить мышью.',
    pointY:'Координата Y в метрах Arma. Верх карты соответствует большему Y.',
    gEnabled:'Подключить модель к гарнизонам, которые сейчас атакуются. Основной ИИ выбирается в разделе сценария.',
    gLimit:'Предел одновременно управляемых моделью гарнизонных групп. Снижайте при медленных ответах модели.',
    BIS_WLCPMultiplier:'Множитель дохода CP от сектора: применяется к базовому доходу, заданному в ресурсах сценария.',
    BIS_WLMaxSubordinates:'Лимит бойцов одного отряда, помимо его командира. Влияет на пехотные закупки.',
    NeroWL_Air:'Максимум авиации стороны. Значение 0 отключает её закупку и использование.',
    save:'Сохраняет карту, её пресет и весь запуск одной командой. Сочетание клавиш: Ctrl+S.',
    launch:'Сначала сохраняет все правки, затем собирает миссию, обновляет мод и запускает Arma.',
    ace:'В Warlords ACE подключается обязательно вместе с CBA. Медицинские и прочие параметры настраиваются в игре через CBA.',
    dev:'Разрешить отладочную консоль и Зевса в создаваемой миссии.'
  };
  NeroHelp.bind(document,helpText);
  displayTab(['launch','maps','presets','setups','operations','devmode','missions'].includes(new URLSearchParams(location.search).get('tab'))?new URLSearchParams(location.search).get('tab'):'missions');
})();
