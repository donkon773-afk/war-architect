/* Loaded before workspace.js so all preset/save paths use these wrappers. */
(() => {
  const entries=NeroDevCatalog.filter(e=>e.stage==='experimental');
  const tab=document.createElement('button');tab.id='devmodeTab';tab.type='button';tab.textContent='DevMode';tab.setAttribute('aria-selected','false');
  document.querySelector('.app-tabs').append(tab);
  const panel=document.createElement('section');panel.id='devmodePanel';panel.hidden=true;panel.className='card devmode-panel';
  panel.innerHTML='<div class="eyebrow">Испытательный полигон</div><h2>DevMode</h2><p>Новые механики и обновления для проверки в бою. После проверки они будут переноситься в основные настройки сценария.</p><label class="check"><input type="checkbox" id="devModeEnabled"> Включить экспериментальные обновления</label><p id="devModeStatus" role="status"></p><div id="devModeFeatures" class="devmode-features"></div><p class="devmode-note">Сохраняется вместе со сценарием и пресетами запуска кнопкой «Сохранить всё». Применяется при следующем запуске миссии. Отладочная консоль и Зевс включаются отдельно в настройках сценария.</p><p>В старых пресетах текущие механики остаются включёнными. Исправления ошибок покупки, спавна и захвата действуют независимо от DevMode.</p>';
  document.querySelector('main').append(panel);
  for(const entry of entries){
    const card=document.createElement('label');card.className='devmode-feature';
    const input=document.createElement('input');input.type='checkbox';input.id='experiment-'+entry.id;
    const text=document.createElement('span'),title=document.createElement('strong'),description=document.createElement('span'),badge=document.createElement('small');
    title.textContent=entry.title;description.textContent=entry.description;badge.textContent='На испытании';text.append(title,badge,description);card.append(input,text);by('devModeFeatures').append(card);
  }
  function refresh(){
    const supported=by('scenario').value==='warlords';
    by('devModeEnabled').disabled=!supported;
    for(const e of entries)by('experiment-'+e.id).disabled=!supported||!by('devModeEnabled').checked;
    const count=entries.filter(e=>by('experiment-'+e.id).checked).length;
    by('devModeStatus').textContent=!supported?'Пока доступно для Warlords и сценариев редактора. Для Antistasi выбор сохраняется, но не применяется.':by('devModeEnabled').checked?'При следующем запуске включено обновлений: '+count+' из '+entries.length+'.':'Экспериментальные обновления отключены. Ваш выбор сохранён для повторного включения.';
  }
  const originalSelection=selection,originalApply=apply;
  selection=function(){const s=originalSelection();s.devMode={enabled:by('devModeEnabled').checked,features:{...savedFeatures,...Object.fromEntries(entries.map(e=>[e.id,by('experiment-'+e.id).checked]))}};return s;};
  let savedFeatures={};
  apply=function(s){
    savedFeatures={...s.devMode?.features};
    by('devModeEnabled').checked=s.devMode?.enabled??true;
    for(const e of entries)by('experiment-'+e.id).checked=savedFeatures[e.id]??e.default;
    originalApply(s);refresh();
  };
  panel.addEventListener('change',refresh);by('scenario').addEventListener('change',refresh);
})();
