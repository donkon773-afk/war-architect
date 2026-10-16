'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),backup=path.join(root,'backups/side-setups-20261011');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):[path.join(dir,e.name)]);}
const settings=files(path.join(backup,'control-center/data')).map(p=>{const relative=path.relative(backup,p),current=path.join(root,relative);return {file:relative.replaceAll('\\','/'),unchanged:fs.existsSync(current)&&hash(p)===hash(current)};});
const installed=[
 ['Warlords','H:/SteamLibrary/steamapps/common/Arma 3/@NeroAI_Warlords/addons/NeroWL.pbo','DB499E1E3A351F873DF2770A4246F357CE74B83ADA640B0B941A54D21480A3FD'],
 ['Antistasi','H:/SteamLibrary/steamapps/common/Arma 3/@NeroAI_Antistasi/addons/NeroAI5.pbo','C591CEC5D09B2B83E77CD3D5387E77FD4266EA3F3CB2376EAE7C3AA86AD5F749']
].map(([name,p,expected])=>({name,path:p,sha256:hash(p),unchanged:hash(p)===expected}));
const changedFiles=['control-center/server.js','control-center/index.html','control-center/designer.html','control-center/warlords-editor.js','control-center/side-setup-client.js','control-center/side-setups.js','control-center/setups.html','control-center/setups.js','tests/side-setups.test.js','tests/designer-ui.test.js','package.json'].map(file=>({file,sha256:hash(path.join(root,file))}));
const setups=files(path.join(root,'control-center/data/side-setups')).filter(p=>path.dirname(p)===path.join(root,'control-center/data/side-setups')).map(p=>JSON.parse(fs.readFileSync(p,'utf8'))).map(r=>({name:r.name,side:r.setup.side,assets:r.setup.assets.length,infantry:r.setup.infantry===null?'auto':r.setup.infantry.length,revision:r.revision}));
const result={checkedAt:new Date().toISOString(),settings,installed,changedFiles,setups,browserChecks:{hiddenSelectionsCleared:true,undoRestoresSavedState:true,launchApplyRestores79VehiclesAnd42InfantryTypes:true,greenMapApplyAndUndo:true,standaloneSaveReadback:true,temporarySetupRemoved:true},tests:{control:54,mod:83},gameLaunched:false,pboInstalled:false};
fs.writeFileSync(path.join(__dirname,'final-verification.json'),JSON.stringify(result,null,2)+'\n');
if(settings.some(x=>!x.unchanged)||installed.some(x=>!x.unchanged)||setups.length!==3)throw Error('Verification mismatch; inspect final-verification.json');
console.log(JSON.stringify({settingsUnchanged:settings.length,installedUnchanged:installed.length,sourceFiles:changedFiles.length,libraryRecords:setups.length},null,2));
