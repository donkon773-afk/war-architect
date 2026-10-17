(() => {
  document.body.classList.add('workspace-operations');
  if(new URLSearchParams(location.search).get('embedded')==='1')document.body.classList.add('operations-embedded');
  window.addEventListener('message',e=>{
    if(e.source!==window.parent||!/^http:\/\/127\.0\.0\.1:[0-9]+$/.test(e.origin)||e.data?.type!=='nero-workspace-state-request')return;
    window.parent.postMessage({source:'nero-operation-state',requestId:e.data.requestId,dirty:typeof dirty!=='undefined'&&dirty,busy:(typeof busy!=='undefined'&&busy)||(typeof saving!=='undefined'&&saving)},e.origin);
  });
  for(const link of document.querySelectorAll('a')){
    link.removeAttribute('target');link.textContent=link.textContent.replace(/\s*↗/g,'');
    const url=new URL(link.href,location.href);
    if(window.parent!==window&&url.hostname==='127.0.0.1'&&Number(url.port)>=18775&&Number(url.port)<=18785)link.remove();
  }
  const becti=document.createElement('a');becti.href='/becti'+(window.parent!==window?'?embedded=1':'');becti.textContent='BECTI';becti.className='button';(document.querySelector('nav')||document.querySelector('header')).append(becti);
  const build=document.getElementById('build');if(build)build.hidden=true;
  const install=document.getElementById('install');if(install)install.textContent='Сохранить и добавить в Arma';
  const launch=document.getElementById('launch');if(launch)launch.textContent='Сохранить и запустить Arma';
  const savebar=document.querySelector('.savebar');
  if(savebar){const hint=document.createElement('output');hint.id='settingHelp';hint.className='operations-help';hint.setAttribute('aria-live','polite');savebar.append(hint);}
  NeroHelp.bind(document,{
    title:'Название операции в библиотеке и в списке миссий Arma.',
    world:'Территория операции. Координаты баз и секторов относятся к выбранной карте.',
    save:'Сохранить операцию без запуска игры. Черновик можно продолжить позже.',
    install:'Одна команда сохранит черновик, соберёт и проверит PBO, затем добавит миссию в Arma.',
    launch:'Одна команда сохранит черновик, подготовит миссию и запустит Arma.',
    playerSide:'Сторона игрока при старте операции.',
    playerRole:'Выберите участие в бою или наблюдение через Зевса.'
  });
  window.addEventListener('keydown',e=>{if(!e.defaultPrevented&&(e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='s'){e.preventDefault();document.getElementById('save')?.click();}});
})();
