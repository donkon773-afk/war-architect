(() => {
  if(new URLSearchParams(location.search).get('embedded')!=='1'){
    location.replace('/?tab=setups');return;
  }
  document.body.classList.add('workspace-setups');
  const back=document.querySelector('header a');if(back){back.textContent='К сценарию';back.removeAttribute('target');back.onclick=e=>{e.preventDefault();window.parent.postMessage({source:'nero-side-setups',type:'navigate'},location.origin);};}
  const hint=document.createElement('output');hint.id='settingHelp';hint.className='setups-help';hint.setAttribute('aria-live','polite');document.querySelector('.footer').append(hint);
  NeroHelp.bind(document,{
    setupName:'Имя набора в общей библиотеке. Сохранённый набор можно применить к любой стороне сценария.',
    setupSide:'Предпочитаемая сторона набора. Смена стороны сохраняет весь выбранный состав.',
    setupFaction:'Фракция определяет автоматический состав пехоты. Свой состав можно собирать из любых установленных модов.',
    infantryMode:'Автоматический состав берётся из фракции; собственный список может содержать любые выбранные типы бойцов.',
    fromLaunch:'Скопировать сторону сохранённого сценария в новый набор. Исходный сценарий продолжит хранить свой состав.',
    saveSetup:'Сохранить текущий набор. Ctrl+S выполняет то же действие.'
  });
})();
