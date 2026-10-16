'use strict';
// km/h TAS. Cruise figures are scenario reference speeds, not universal AFM limits.
// Exact family identification precedes generic inheritance/fictional fallbacks.
const profiles=[
 ['F22','F-22A',/f.?22/i,900,2120,true,1590],
 ['F35','F-35B',/f.?35/i,1000,1700,true,1000],
 ['T50','T-50 / Su-57',/t50|t_50|su.?57/i,900,2120,true,1350],
 ['SU35','Su-35S',/su.?35/i,900,2390,true,900],
 ['MIG29','MiG-29',/mig.?29|l_18/i,900,2400,true,900],
 ['MIG21','MiG-21',/mig.?21/i,900,2175,true,900],
 ['F18','F/A-18E/F',/fa18|fa_18|f.?18/i,900,1700,true,900],
 ['F16','F-16C/D',/f16|f_16/i,900,2120,true,900],
 ['F4','F-4E',/\bf4e|f_4e|f4e_/i,920,2370,true,920],
 ['M2000','Mirage 2000',/m2000|mirage.?2000/i,900,2340,true,900],
 ['J10','J-10A',/j10|j_10/i,900,2120,true,900],
 ['SU34','Su-34',/su.?34/i,900,1900,true,900],
 ['SU25','Su-25',/su.?25/i,750,950,false,750],
 ['TU95','Tu-95MS',/tu.?95/i,735,830,false,735],
 ['A10','A-10A/C',/a10|a_10|plane_cas_01/i,560,706,false,560],
 ['AV8','AV-8B / Harrier',/av8|av_8|gr9|harrier/i,830,1080,false,830],
 ['A7','A-7H',/^a7|corsair/i,850,1100,false,850],
 ['L159','L-159',/l159|l_159|plane_fighter_03/i,700,935,false,700],
 ['L39ZA','L-39ZA',/l39za|l_39za/i,550,700,false,550],
 ['L39','L-39C/M1',/l39|l_39/i,600,750,false,600],
 ['GRIPEN','JAS 39',/jas39|gripen|plane_fighter_04/i,900,2120,true,900],
 ['C130H','C-130H',/c130h/i,540,590,false,540],
 ['C130','C-130J / EC-130',/c130|c_130/i,620,670,false,620],
 ['P8','P-8A Poseidon',/p8poseidon/i,815,907,false,815],
 ['A29','A-29 Super Tucano',/a29|a_29/i,520,590,false,520],
 ['T28','T-28',/t28|t_28/i,370,557,false,370],
 ['AN2','An-2',/an2|an_2/i,190,258,false,190],
 ['LI2','Li-2',/li2|li_2/i,240,280,false,240],
 ['C47','C-47 / AC-47',/c47|ac47|dc3/i,300,360,false,300],
 ['T41','T-41 / O-3A',/t41|t_41|cessna_o3a/i,200,230,false,200],
 ['AC500','Aero Commander 500',/ac500/i,300,360,false,300],
 ['MYSTERE','Mystere IVA',/mystere/i,850,1120,false,850],
 ['MQ9','MQ-9',/mq9|mq_9|reaper/i,370,482,false,370],
 ['PCHELA','Pchela-1T',/pchela/i,130,180,false,130],
 ['TB2','Bayraktar TB2',/bayraktartb2/i,167,204,false,167],
 ['V22','V-22',/mv22|osprey/i,446,509,false,446],
 ['YAK130','Yak-130 analogue',/plane_cas_02/i,700,960,false,700],
 ['CESSNA400','Cessna 400 / TTx',/c400|plane_civil_01/i,400,435,false,400],
 ['C172','Cessna 172',/cessna_172|cessna_civ|plane_ion|plane_orbit|uapolice_plane/i,210,230,false,210],
 ['A300','Airbus A300',/a300/i,830,890,false,830],
 ['B737','Boeing 737',/b737/i,830,890,false,830],
 ['BLACKWASP','F/A-181 fictional',/plane_fighter_01/i,900,1700,true,900],
 ['SHIKRA','To-201 fictional',/plane_fighter_02/i,900,2390,true,900],
 ['BLACKFISH','V-44 fictional',/vtol_01/i,400,509,false,400],
 ['XIAN','Y-32 fictional',/vtol_02/i,450,600,false,450]
];
// Explicit vanilla-only overrides: do not give the bonus to real aircraft in RHS/CUP.
const vanilla=[
 {id:'V_WIPEOUT',label:'A-164 Wipeout / A-10',pattern:/^B_Plane_CAS_01(?:_|$)/i,cruise:560,referenceMaximum:706,bonus:150,afterburner:false,dryMaximum:560},
 {id:'V_NEOPHRON',label:'To-199 Neophron / Yak-130',pattern:/^O_Plane_CAS_02(?:_|$)/i,cruise:700,referenceMaximum:1060,bonus:200,afterburner:false,dryMaximum:700},
 {id:'V_BUZZARD',label:'A-143 Buzzard / L-159',pattern:/^I_Plane_Fighter_03(?:_|$)/i,cruise:700,referenceMaximum:936,bonus:200,afterburner:false,dryMaximum:700},
 {id:'V_BLACKWASP',label:'F/A-181 / F/A-18E + F-22; F-22 speed reference',pattern:/^B_Plane_Fighter_01(?:_|$)/i,cruise:900,referenceMaximum:2120,bonus:300,afterburner:true,dryMaximum:1590},
 {id:'V_SHIKRA',label:'To-201 / T-50 + Su-35; Su-35 speed reference',pattern:/^O_Plane_Fighter_02(?:_|$)/i,cruise:900,referenceMaximum:2390,bonus:350,afterburner:true,dryMaximum:1350},
 {id:'V_GRYPHON',label:'A-149 Gryphon / JAS 39 Gripen',pattern:/^I_Plane_Fighter_04(?:_|$)/i,cruise:900,referenceMaximum:2120,bonus:300,afterburner:true,dryMaximum:900},
 {id:'V_CAESAR',label:'Caesar BTT / Cessna TTx',pattern:/^[CIB]_Plane_Civil_01(?:_|$)/i,cruise:400,referenceMaximum:435,bonus:150,afterburner:false,dryMaximum:400}
];
function resolve(className){const v=vanilla.find(p=>p.pattern.test(className));if(v){const {pattern,...p}=v;return {...p,maximum:p.referenceMaximum+p.bonus,status:'fictional_vanilla_with_user_requested_speed_bonus'};}const p=profiles.find(p=>p[2].test(className));return p?{id:p[0],label:p[1],cruise:p[3],maximum:p[4],afterburner:p[5],dryMaximum:p[6],status:'reference_envelope_not_certified_flight_manual'}:null;}
module.exports={profiles,vanilla,resolve};
