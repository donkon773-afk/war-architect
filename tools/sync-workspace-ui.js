'use strict';
// Embed maintained UI modules into existing standalone documents. The running
// panel already serves these documents dynamically; no service restart needed.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../control-center');
function block(html,name,text,tag){const start=`<!-- ${name}:start -->`,end=`<!-- ${name}:end -->`,value=`${start}\n<${tag}>\n${text}\n</${tag}>\n${end}`;if(html.includes(start))return html.replace(new RegExp(start+'[\\s\\S]*?'+end),()=>value);return html.replace(tag==='style'?'</style>':/<\/body>|<\/html>/,m=>tag==='style'?m+'\n'+value:value+'\n'+m);}
for(const [file,module] of [['index.html','workspace.js'],['designer.html','editor-workspace.js'],['setups.html','setups-workspace.js'],['operations.html','operations-workspace.js'],['ground-operations.html','operations-workspace.js'],['campaign-operations.html','operations-workspace.js']]){
 let html=fs.readFileSync(path.join(root,file),'utf8');
 html=block(html,'military-ui',fs.readFileSync(path.join(root,'military.css'),'utf8'),'style');
 html=block(html,'context-help',fs.readFileSync(path.join(root,'context-help.js'),'utf8'),'script');
 if(module){
   const dev=file==='index.html'?'const NeroDevCatalog='+JSON.stringify(require('../control-center/dev-mode').catalog)+';\n'+fs.readFileSync(path.join(root,'dev-workspace.js'),'utf8')+'\n':'';
   const library=file==='index.html'?fs.readFileSync(path.join(root,'library-workspace.js'),'utf8')+'\n':'';
   const requiredMods=file.includes('operations.html')?fs.readFileSync(path.join(root,'operation-mod-policy.js'),'utf8')+'\n'+fs.readFileSync(path.join(root,'required-mods-workspace.js'),'utf8')+'\n':'';
   html=block(html,'workspace-module',dev+library+requiredMods+(file==='campaign-operations.html'?'const NeroCampaignExperiments='+JSON.stringify(require('../control-center/campaign-experiments').entries)+';\n'+fs.readFileSync(path.join(root,'campaign-dev-workspace.js'),'utf8')+'\n':'')+fs.readFileSync(path.join(root,module),'utf8'),'script');
 }
 fs.writeFileSync(path.join(root,file),html);
}
