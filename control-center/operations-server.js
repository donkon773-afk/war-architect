'use strict';
// Operations have a dedicated store; this service never writes game/LLM profiles.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ops=require('./operations'),maps=require('./scenario-design'),background=require('./map-background');
function createServer({store=ops,builder=require('./operation-build')}={}){
 const token=crypto.randomBytes(24).toString('hex');let busy=false;
 const send=(res,status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));};
 const server=http.createServer(async(req,res)=>{try{
  if(!['127.0.0.1','::1'].includes(req.socket.remoteAddress)||req.headers.host!==`127.0.0.1:${server.address().port}`)return send(res,403,{error:'Только локальное окно NeroAI.'});
  const url=new URL(req.url,'http://127.0.0.1');
  if(req.method==='GET'&&['/','/operations'].includes(url.pathname)){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"frame-ancestors 'self' http://127.0.0.1:*"});return res.end(fs.readFileSync(path.join(__dirname,'operations.html'),'utf8').replace('__SESSION_TOKEN__',token).replace('__OPERATIONS_FEATURES__','campaign-strategic-v6'));}
  if(req.method==='GET'&&url.pathname==='/ground'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"frame-ancestors 'self' http://127.0.0.1:*"});return res.end(fs.readFileSync(path.join(__dirname,'ground-operations.html'),'utf8').replace('__SESSION_TOKEN__',token).replace('__OPERATIONS_FEATURES__','campaign-strategic-v6'));}
  if(req.method==='GET'&&url.pathname==='/campaign'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"frame-ancestors 'self' http://127.0.0.1:*"});return res.end(fs.readFileSync(path.join(__dirname,'campaign-operations.html'),'utf8').replace('__SESSION_TOKEN__',token).replace('__OPERATIONS_FEATURES__','campaign-strategic-v6'));}
  if(req.method==='GET'&&url.pathname==='/health')return send(res,200,{application:'NeroAI Operations',features:'campaign-strategic-v6',workspaceEmbed:true,pid:process.pid,port:server.address().port,busy});
  if(req.method==='GET'&&url.pathname==='/operations.css'){res.writeHead(200,{'Content-Type':'text/css; charset=utf-8','Cache-Control':'no-store'});return res.end(fs.readFileSync(path.join(__dirname,'operations.html'),'utf8').match(/<style>([\s\S]*?)<\/style>/)[1]);}
  if(req.method==='GET'&&url.pathname==='/operation-mods-ui.js'){res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8','Cache-Control':'no-store'});return res.end(fs.readFileSync(path.join(__dirname,'operation-mods-ui.js')));}
  if(req.method==='GET'&&url.pathname==='/operations-ui.js'){res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8','Cache-Control':'no-store'});return res.end(fs.readFileSync(path.join(__dirname,'operations-ui.js')));}
  if(req.method==='GET'&&url.pathname==='/ground-operations-ui.js'){res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8','Cache-Control':'no-store'});return res.end(fs.readFileSync(path.join(__dirname,'ground-operations-ui.js')));}
  if(req.method==='GET'&&url.pathname==='/campaign-operations-ui.js'){res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8','Cache-Control':'no-store'});return res.end(fs.readFileSync(path.join(__dirname,'campaign-operations-ui.js')));}
  if(req.method==='GET'&&url.pathname.startsWith('/map-background/')){const match=url.pathname.match(/^\/map-background\/([^/]+)\.jpg$/);if(!match)return send(res,404,{error:'Карта не найдена.'});const w=maps.world(decodeURIComponent(match[1])),file=background.file(w);if(!file||!fs.existsSync(file))return send(res,404,{error:'Фон карты недоступен.'});res.writeHead(200,{'Content-Type':'image/jpeg','Cache-Control':'public,max-age=3600'});return fs.createReadStream(file).pipe(res);}
  if(req.headers['x-nero-session']!==token||req.headers.origin&&req.headers.origin!==`http://127.0.0.1:${server.address().port}`)return send(res,403,{error:'Сессия окна устарела. Обновите страницу.'});
  if(req.method==='GET'&&url.pathname==='/api/operations-bootstrap')return send(res,200,{worlds:maps.worlds().filter(w=>w.size>=18000).map(w=>({id:w.id,label:w.label,size:w.size})),catalog:ops.catalog(),mods:require("./operation-mods").catalog(),defaults:ops.defaults(),operations:store.list(),setups:require('./side-setups').list()});
  if(req.method==='GET'&&url.pathname==='/api/ground-bootstrap'){const ground=require('./ground-operations');return send(res,200,{worlds:maps.worlds().filter(w=>w.size>=5000).map(w=>({id:w.id,label:w.label,size:w.size,locations:w.locations})),catalog:ground.catalog(),mods:require("./operation-mods").catalog(),defaults:ground.defaults(),operations:store.list(),setups:require('./side-setups').list()});}
  if(req.method==='GET'&&url.pathname==='/api/ground-defaults')return send(res,200,require('./ground-operations').defaults(url.searchParams.get('world')||'Australia'));
  if(req.method==='GET'&&url.pathname==='/api/campaign-bootstrap'){const campaign=require('./campaign-operations'),equipment=require('./campaign-equipment');return send(res,200,{worlds:maps.worlds().filter(w=>w.size>=2500).map(w=>({id:w.id,label:w.label,size:w.size})),catalog:campaign.catalog(),trucks:campaign.trucks(),equipmentCatalog:equipment.catalog(),gearCatalog:equipment.gearCatalog(),factions:{WEST:equipment.factions('WEST'),EAST:equipment.factions('EAST')},gearByUnit:Object.fromEntries(Object.entries(JSON.parse(fs.readFileSync(path.join(__dirname,'../dist/campaign-inventory.json'),'utf8')).units).map(([id,u])=>[id,u.items])),gameplayParameters:require('./campaign-gameplay').parameters,presets:require('./campaign-presets').list(),mods:require('./operation-mods').catalog(),defaults:campaign.defaults(),operations:store.list(),setups:require('./side-setups').list()});}
  if(req.method==='GET'&&url.pathname==='/api/campaign-faction')return send(res,200,require('./campaign-equipment')[url.searchParams.get('full')==='1'?'fullArmy':'canonical'](url.searchParams.get('side'),url.searchParams.get('faction')));
  if(req.method==='GET'&&url.pathname==='/api/campaign-defaults')return send(res,200,require('./campaign-operations').defaults(url.searchParams.get('world')||'Australia'));
  if(req.method==='GET'&&url.pathname==='/api/operations')return send(res,200,{operations:store.list()});
  if(req.method==='GET'&&url.pathname==='/api/operation')return send(res,200,store.get(url.searchParams.get('id')));
  if(req.method==='GET'&&url.pathname==='/api/operation-defaults')return send(res,200,ops.defaults(url.searchParams.get('world')||'Australia'));
  if(req.method==='GET'&&url.pathname==='/api/side-setup')return send(res,200,require('./side-setups').get(url.searchParams.get('id')));
  if(req.method!=='POST')return send(res,404,{error:'Не найдено.'});
  let body='';for await(const chunk of req){body+=chunk;if(Buffer.byteLength(body)>8*1024*1024)throw Error('Операция слишком большая.');}const data=JSON.parse(body||'{}');
  if(url.pathname==='/api/operation')return send(res,200,store.save(data));
  if(['/api/operation-build','/api/operation-install','/api/operation-launch'].includes(url.pathname)){
   if(busy)throw Error('Дождитесь завершения текущей сборки.');const record=store.get(data.id);if(record.revision!==data.revision)throw Error('Сохранённая операция изменилась. Откройте её заново перед сборкой.');
   busy=true;try{let result=await builder.build(record.design);if(url.pathname!=='/api/operation-build')result=builder.install(result);if(url.pathname==='/api/operation-launch')result={...result,...await builder.launch(result)};return send(res,200,result);}finally{busy=false;}
  }
  return send(res,404,{error:'Не найдено.'});
 }catch(e){send(res,400,{error:e.message});}});
 return server;
}
if(require.main===module){const port=Number(process.env.NEROAI_OPERATIONS_PORT||18786);if(!Number.isInteger(port)||port<18786||port>18799)throw Error('Operations port must be 18786–18799');const server=createServer();server.listen(port,'127.0.0.1',()=>{require('./durable').write(path.join(__dirname,port===18786?'data/operations-session.json':'data/operations-session-'+port+'.json'),{application:'NeroAI Operations',pid:process.pid,port,startedAt:new Date().toISOString()});console.log('NeroAI Operations: http://127.0.0.1:'+port+'/operations');});}
module.exports={createServer};
