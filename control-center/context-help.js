/* Click opens an inline explanation; hover/focus also update the status strip. */
const NeroHelp=(()=>{
  let output=null,sequence=0;
  function show(text){if(output)output(text||'Наведите на знак ? или выберите настройку — подсказка появится здесь.');}
  function bind(doc,texts={},sink){
    if(sink)output=sink;
    else if(doc.getElementById('settingHelp'))output=text=>doc.getElementById('settingHelp').textContent=text;
    function annotate(){
      for(const label of doc.querySelectorAll('label')){
        if(label.dataset.helpBound)continue;
        const field=label.htmlFor?doc.getElementById(label.htmlFor):label.querySelector('input,select,textarea');
        if(!field?.id || field.type==='search')continue;
        label.dataset.helpBound='1';
        const id=field.dataset.editorId||field.id;
        const caption=label.cloneNode(true);for(const el of caption.querySelectorAll('input,select,textarea,button,.context-help-inline'))el.remove();
        const title=caption.textContent.trim().replace(/\s+/g,' ')||field.getAttribute('aria-label')||id;
        const help=texts[id]||field.dataset.help||field.getAttribute('title')||('«'+title+'». Изменения применятся после сохранения сценария.');
        field.dataset.help=help;field.removeAttribute('title');
        const button=doc.createElement('button');button.type='button';button.className='help-trigger';button.textContent='?';
        button.setAttribute('aria-label','Подсказка: '+title);button.dataset.help=help;
        const panel=doc.createElement('span');panel.className='context-help-inline';panel.id='context-help-'+(++sequence);panel.hidden=true;panel.setAttribute('role','note');
        button.setAttribute('aria-controls',panel.id);button.setAttribute('aria-expanded','false');
        button.onclick=e=>{e.preventDefault();e.stopPropagation();const open=panel.hidden;
          for(const other of doc.querySelectorAll('.context-help-inline'))other.hidden=true;
          for(const other of doc.querySelectorAll('.help-trigger[aria-expanded="true"]'))other.setAttribute('aria-expanded','false');
          panel.textContent=button.dataset.help;panel.hidden=!open;button.setAttribute('aria-expanded',String(open));show(button.dataset.help);
          if(open)panel.scrollIntoView({block:'nearest',behavior:'smooth'});
        };
        panel.onclick=e=>{e.preventDefault();e.stopPropagation();};
        if(field.parentElement===label&&!['checkbox','radio'].includes(field.type))label.insertBefore(button,field);else label.append(button);
        label.append(panel);
      }
      for(const el of doc.querySelectorAll('button[title],input[title],select[title]')){el.dataset.help=el.getAttribute('title');el.removeAttribute('title');}
      for(const [id,text] of Object.entries(texts)){
        const el=doc.getElementById(id)||doc.getElementById('editor-'+id);if(!el)continue;el.dataset.help=text;
        const label=el.closest('label')||doc.querySelector('label[for="'+el.id+'"]');const trigger=label?.querySelector('.help-trigger');if(trigger)trigger.dataset.help=text;
      }
    }
    annotate();
    if(!doc.documentElement.dataset.helpListening){
      doc.documentElement.dataset.helpListening='1';
      doc.addEventListener('keydown',e=>{if(e.key!=='Escape')return;for(const panel of doc.querySelectorAll('.context-help-inline'))panel.hidden=true;for(const trigger of doc.querySelectorAll('.help-trigger[aria-expanded="true"]'))trigger.setAttribute('aria-expanded','false');});
      for(const name of ['focusin','pointerover'])doc.addEventListener(name,e=>{const el=e.target.closest?.('[data-help]');if(el)show(el.dataset.help);});
      let queued=false;
      new MutationObserver(()=>{if(queued)return;queued=true;queueMicrotask(()=>{queued=false;annotate();});}).observe(doc.body,{childList:true,subtree:true});
    }
    show();
  }
  return {bind,show};
})();
