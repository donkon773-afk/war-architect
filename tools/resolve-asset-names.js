"use strict";
const fs=require('node:fs'),path=require('node:path'),{readEntry,indexEntries}=require('./read-pbo-entry');
const root=path.resolve(__dirname,'..');
function text(s){return s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,'$1').replace(/<[^>]*>/g,'').replace(/&#x([\da-f]+);/gi,(_,n)=>String.fromCodePoint(parseInt(n,16))).replace(/&#(\d+);/g,(_,n)=>String.fromCodePoint(+n)).replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&').replace(/\s+/g,' ').trim();}
function scan(){
 const catalog=JSON.parse(fs.readFileSync(path.join(root,'dist/mod-assets.json'),'utf8')),strings={};let tables=0;
 const game=JSON.parse(fs.readFileSync(path.join(root,'tools/warlords-launch.json'),'utf8').replace(/^\uFEFF/,'')).armaRoot;
 const dirs=['Dta','Addons',...['Curator','Heli','Kart','Mark','Jets','Argo','Orange','Tacops','Tank','Enoch','AoW','Expansion'].map(n=>n+'/addons')].map(n=>path.join(game,n)).concat(catalog.mods.map(m=>path.join(m.path,'addons')));
 for(const dir of dirs){if(!fs.existsSync(dir))continue;for(const f of fs.readdirSync(dir).filter(f=>/\.pbo$/i.test(f))){
  let xml;try{const file=path.join(dir,f);const entries=indexEntries(file);for(const e of entries.filter(e=>/(^|[\\/])stringtable\.bin$/i.test(e.name))){try{Object.assign(strings,require('./read-binary-stringtable').decode(readEntry(file,e.name)));tables++;}catch{}}xml=entries.filter(e=>/(^|[\\/])stringtable\.xml$/i.test(e.name)).map(e=>readEntry(file,e.name).toString('utf8')).join('\n');}catch{continue;}
  tables++;for(const key of xml.matchAll(/<Key\b[^>]*\bID\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)<\/Key>/gi)){
   const body=key[2],value=body.match(/<Russian\b[^>]*>([\s\S]*?)<\/Russian>/i)?.[1]||body.match(/<English\b[^>]*>([\s\S]*?)<\/English>/i)?.[1]||body.match(/<Original\b[^>]*>([\s\S]*?)<\/Original>/i)?.[1];
   if(value&&text(value)&&!text(value).startsWith('$'))strings[key[1].toLowerCase()]=text(value);
  }
 }}
 const result={scannedAt:new Date().toISOString(),tables,strings};fs.writeFileSync(path.join(root,'dist/asset-names.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({tables,strings:Object.keys(strings).length}));return result;
}
if(require.main===module)scan();module.exports={scan,text};
