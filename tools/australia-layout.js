"use strict";
// Existing bases/first sectors: Australia Port mission. Added towns: Names in
// the installed Australia FIXED config, decoded read-only 2026-10-05.
const places=[
  // 7.10: bases on the airfields (open grass beside the apron, off the runway):
  // Darwin ILS 16428,34117 / Sydney ILS 35316,12380 from the installed world config.
  ["Darwin BLUFOR",[16950,0,33700],2,true],
  ["South OPFOR",[35130,0,12110],1,true],
  ["Darwin Port",[15677.396,6.0816197,33143.914],0,false],
  ["Alice Springs",[22119.721,16.947033,25610.58],0,false],
  ["Cairns",[32171.018,5.2507868,29826.059],0,false],
  ["Brisbane",[38162.809,4.2315545,19878.422],0,false],
  ["Adelaide",[24947.229,7.4310384,12915.924],0,true],
  ["Victoria",[31069.203,4.5013757,10640.909],0,true],
  ["Perth",[5445,0,18695],0,false],
  ["Willcania",[31302,0,16764],0,false],
  ["Toowoomba",[30955,0,19997],0,false],
  ["Coober Pedy",[22300,0,19289],0,false],
  ["Pine Gap",[19764,0,24355],0,false],
].map(([name,position,side,runway],i)=>({id:i+2,kind:i<2?"Base":"Sector",name,position,side,runway,size:i<2?300:name==="Perth"?400:250,funds:i<2?10:30}));
const edges=[[2,4],[4,5],[5,6],[6,7],[7,3],[5,8],[8,9],[9,3],
  [5,14],[14,13],[13,8],[13,10],[10,14],[13,11],[11,12],[12,7],[11,9]];
module.exports={places,edges};
