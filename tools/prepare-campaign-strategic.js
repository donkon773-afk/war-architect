'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function prepare(){const root=path.resolve(__dirname,'..'),source=path.join(root,'addons/NeroStrategic'),files=['config.cpp',...fs.readdirSync(path.join(source,'functions')).map(n=>'functions/'+n)],hash=crypto.createHash('sha256');for(const f of files)hash.update(f).update(fs.readFileSync(path.join(source,f)));const digest=hash.digest('hex').slice(0,12),mod=path.join(root,'dist/strategic-candidates','@NeroAI_Strategic_'+digest);return {source,mod,pbo:path.join(mod,'addons/NeroStrategic.pbo'),prefix:'NeroStrategic',hash:digest};}
module.exports={prepare};
