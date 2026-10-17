'use strict';
// Reproducible fetch of the reviewed upstream. No branch-head upgrades during builds.
const fs=require('fs'),cp=require('child_process'),b=require('../control-center/becti');
function fetch(){if(!fs.existsSync(b.source)){cp.execFileSync('git',['clone','--no-checkout',b.upstream.url+'.git',b.source],{windowsHide:true,timeout:120000,stdio:'pipe'});cp.execFileSync('git',['-C',b.source,'checkout','--detach',b.upstream.revision],{windowsHide:true,timeout:30000,stdio:'pipe'});}const rev=cp.execFileSync('git',['-C',b.source,'rev-parse','HEAD'],{encoding:'utf8',windowsHide:true}).trim();if(rev!==b.upstream.revision)throw Error('BECTI upstream differs from the pinned revision.');return {revision:rev,source:b.source};}
if(require.main===module)console.log(JSON.stringify(fetch()));module.exports={fetch};
