'use strict';
// Content-addressed addons are immutable. A running game can hold their PBO open.
async function ensure(addon,{exists=require('node:fs').existsSync,verify,pack}){
 if(exists(addon.pbo)){
  await verify(addon);
  return {reused:true};
 }
 await pack(addon);await verify(addon);return {reused:false};
}
module.exports={ensure};
