'use strict';
// A source is attached to the exact supported claim. Unknown details stay unknown.
const facts=[];
function f(id,pattern,range,speed,guidance,warhead,sources,note=''){facts.push({id,pattern,range,speed,guidance,warhead,sources,note});}
const n='Не подтверждено выбранными первичными источниками';
f('AIM-120',/aim120|amraam|m_zephyr/i,'A: более 48 км; конкретные C/D: точная дальность не раскрыта','A: М 4','ИНС + коррекция; активная РЛ ГСН','A: около 18 кг',['https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196742/AFmuseum/hughes-aim-120-amraam/'],'Старый AIM-120A нельзя считать точной характеристикой AIM-120D.');
f('Р-77 / РВВ-АЕ',/r77|r_77/i,'РВВ-АЕ: до 80 км; РВВ-СД: до 110 км',n,'ИНС + радиокоррекция + активная РЛ ГСН','22,5 кг',['https://roe.ru/pdfs/pdf_4709.pdf','https://roe.ru/pdfs/pdf_4710.pdf'],'Экспортные РВВ-АЕ/СД — опорные изделия; характеристики Р-77М отдельно не подтверждены.');
f('Р-73 / Р-74',/r73|r74|r_73|r_74/i,'Р-73Э: до 30 км',n,'Пассивная ИК ГСН','Р-73Э: 8 кг',['https://roe.ru/pdfs/pdf_287.pdf'],'Характеристики Р-74/М2 не подменены данными Р-73Э.');
f('Р-27',/r27/i,'Р-27ЭТ1: до 80 км; остальные версии требуют отдельного подтверждения',n,'Р/ЭР: полуактивная РЛ; Т/ЭТ: ИК','ЭТ1: 39 кг',['https://roe.ru/pdfs/pdf_4714.pdf'],'Варианты Р/ЭР/Т/ЭТ перечислены раздельно в полном списке.');
f('AIM-9X',/aim9_x|aim9x|bim9x|sidewinder_aa/i,'Засекречена','Засекречена; сверхзвуковая','Тепловизионная ИК; Block II имеет канал данных','9,36 кг',['https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2168989/aim-9x-sidewinder-missile/']);
f('AIM-9L/M',/aim9m|aim9_m|aim_9l|missile_aa_04/i,'Ближний бой; точная дальность в выбранном источнике не раскрыта','AIM-9M: М 2,5','ИК ГСН','Осколочная',['https://www.navair.navy.mil/product/AIM-9M-Sidewinder'],'AIM-9L и M — разные модификации; источник скорости относится к M.');
f('AIM-132 ASRAAM',/aim132|m_air_aa/i,n,n,'ИК, захват до/после пуска',n,['https://www.mbda-systems.com/products/air-dominance/asraam']);
f('MICA RF',/mica/i,n,n,'RF: активная РЛ; у семейства также есть IR-вариант',n,['https://www.mbda-systems.com/products/air-dominance/mica-family/mica']);
f('AGM-65 Maverick',/agm65|agm_65|maverick|missile_agm_02|missile_agm114/i,'До 17 морских миль ≈31,5 км','Сверхзвуковая','A/B/H: ТВ; D/F/G: ИК; E/L: лазер','В зависимости от версии: около 57 или 136 кг',['https://www.navy.mil/Resources/Fact-Files/Display-FactFiles/Article/2168374/agm-65-maverick-guided-missile/'],'Общая дальность семейства не гарантирует захват каждой ГСН на 31,5 км. H/L требуют отдельного подтверждения версии.');
f('AGM-114 Hellfire',/agm114|agm_114|hellfire|m_hellfire/i,'7,1–8 км для HELLFIRE II с высоты 914 м',n,'K/M/N: лазер; L: активная РЛ','Разные кумулятивные/осколочные/термобарические варианты',['https://www.lockheedmartin.com/content/dam/lockheed-martin/mfc/pc/hellfire/23-05810-TM_AGMS-HELLFIRE-II-Product-Card-1.pdf'],'Численная дальность источника относится к AGM-114R, а не к каждой найденной версии.');
f('AGM-179 JAGM',/agm179/i,'Базовый: 8 км; JAGM-MR: 16 км',n,'Комбинированная ГСН',n,['https://lockheedmartin.com/en-us/products/jagm.html'],'Не переносить дальность MR на базовый JAGM.');
f('AGR-20 APKWS',/agr20/i,'Демонстрировались пуски с вертолёта на 1,5–4 км; не паспортный максимум',n,'Полуактивный лазер','Зависит от 70-мм боевой части',['https://www.baesystems.com/en/article/test-demonstrates-apkws-shortrange-accuracy-and-penetrator-warhead-performance']);
f('Х-38',/kh38/i,'До 40 км для Х-38МЭ','М 2,2','МАЭ: активная РЛ; МЛЭ: лазер; МТЭ: тепловизионная; МКЭ: спутниковая','До 250 кг',['https://roe.ru/pdfs/pdf_4722.pdf']);
f('Х-29',/kh29/i,'Х-29ТЭ: 20–30 км; старые Л/Т не приравнены к ТЭ',n,'Л: лазер; Т/ТЭ: ТВ','ТЭ: 320 кг',['https://roe.ru/pdfs/pdf_4715.pdf'],'Игровые ML/MP/D не имеют автоматически подтверждённых паспортов по этой карточке.');
f('Х-25',/kh25|missile_agm_01/i,'Х-25МЛ: 10 км',n,'Зависит от модификации: лазер / ТВ / ИК / РЛ',n,['https://roe.ru/pdfs/pdf_4722.pdf'],'Карточка Х-38 прямо сравнивает дальность 40 км с Х-25МЛ 10 км; не подтверждает все варианты Х-25.');
f('Х-58',/kh58/i,'Х-58УШКЭ: 76–245 км по условиям пуска','Х-58УШКЭ: 4 200 км/ч','Пассивная РЛ ГСН + ИНС','149 кг',['https://roe.ru/pdfs/pdf_2029.pdf'],'Точная версия игрового KH58 не установлена; это сравнение с современной УШКЭ, не паспорт старой Х-58.');
f('AGM-88 HARM',/harm/i,n,'Сверхзвуковая','Пассивная РЛ; поздние версии имеют дополнительные средства',n,['https://www.navair.navy.mil/product/AARGM'],'AARGM — развитие HARM; дальность одной версии не перенесена на другую.');
f('Х-55 / Х-555',/kh55/i,'Открытые оценки: Х-55 2500 км; Х-55СМ 3000; Х-555 3500','Дозвуковая','ИНС + коррекция по местности','Х-55/СМ: ядерная; Х-555: обычная около 400 кг',['https://missilethreat.csis.org/missile/kh-55/'],'Исследование CSIS, а не заводской паспорт. RHS Kh-55Sh HE — игровая реализация, её нельзя автоматически приравнять к реальной ядерной Х-55.');
f('AGM-158 JASSM',/agm158/i,'Базовая: более 370 км; ER: более 926 км','Дозвуковая','ИНС/GPS + ИК на конечном участке','Около 454 кг',['https://www.lockheedmartin.com/en-us/news/features/history/jassm.html'],'TT_agm158 не обозначает автоматически ER.');
f('AGM-84H/K SLAM-ER',/slam_er/i,'Более 250 км',n,'Коррекция + терминальное наведение оператором/ИК',n,['https://www.navy.mil/DesktopModules/ArticleCS/Print.aspx?Article=2168997&ModuleId=4201&PortalId=1']);
f('AGM-130',/agm130/i,'Засекречена в карточке USAF','Засекречена','ТВ/ИК + канал данных; GPS/ИНС','A: Mk84; C: BLU-109',['https://www.af.mil/About-Us/Fact-Sheets/Display/article/104579/agm-130-missile/']);
f('BGM-109 Tomahawk',/bgm109/i,'Подтверждён испытательный полёт 885 км; это не паспортный максимум','Дозвуковая','ИНС, GPS, TERCOM/DSMAC; зависит от версии',n,['https://www.navair.navy.mil/node/6491'],'Корабельное/подводное оружие, хотя мод разрешает авиационную подвеску.');
f('UMTAS',/umtas/i,'0,5–8 км',n,'UMTAS: тепловизионная + радиоканал','Тандемная кумулятивная',['https://roketsan.com.tr/en/products/umtas-long-range-anti-tank-missile-system']);
f('ZT3 Ingwe',/zt3/i,'5 км',n,'Лазерное наведение по лучу','Тандемная',['https://www.deneldynamics.co.za/press-article/Denel-Dynamics-upgrading-missile-range/38','https://admin.denel.co.za/uploads/Denel_Dynamics_Products.pdf']);
f('ZT6 Mokopa',/zt6/i,'Более 10 км',n,'Полуактивный лазер',n,['https://www.denel.co.za/press-article/South-African-Defence-Group-To-Be-A-Prominent-Participant-At-IDEX-2015/73']);
f('TOW',/tow/i,'Базовый: 3 км; ITOW/TOW2/2A/2B: 3,75 км; AERO отдельно',n,'Командное; провод/радиоканал по версии','Кумулятивная / ударные ядра / противобункерная по версии',['https://www.benning.army.mil/infantry/magazine/issues/1989/NOV-DEC/pdfs/NOV-DEC1989.pdf','https://www.army.mil/article/130604/TOWs_return_to_Fort_Riley___Big_Red_One__infantrymen_fire_live_anti_tank_missiles/']);
f('CRV7',/crv7/i,n,n,'Базовая: неуправляемая; PG: управляемая','Разные варианты',['https://magellan.aero/press-release/magellan-kda-teaming-announcement/']);
// Recognised real-world family names whose exact numerical versions are not independently
// established in the selected sources. Never invent a precision figure to fill a cell.
for(const [id,re]of [
 ['Р-60/Р-60М',/r60/],['Magic 2',/magic/],['PL-2',/pl2$/],['PL-5E2',/pl5/],['PL-7',/pl7$/],['PL-8B',/pl8/],['PL-9',/pl9$/],['PL-11',/pl11/],['PL-12',/pl12/],
 ['Х-31ПД',/kh31/],['Х-27ПС',/kh27/],['Х-23М',/kh23/],['Х-35У',/kh35/],['Х-59МК/МК2',/kh59/],['Х-101',/kh101/],['Х-47М2',/kh47/],['AGM-84 Harpoon',/agm84$/],['AGM-12B/C Bullpup',/agm12/],['C-704KD (label C-740KD)',/c704/],['KD-88',/kd88/],['YJ-91',/yj91/],['3М-14К',/3m14/],['3М-55 Оникс',/3m55/],['П-15',/tt_p15/],
 ['9М114 Штурм',/9m114|shturm/],['9М120 Атака',/9m120|ataka/],['9М127 Вихрь',/9m127|vikhr|m_scalpel/],['9М17 Фаланга',/9m17|falanga/],['HOT 1/2/3',/hot[123]/],['FIM-92 / ATAS',/fim92/],['9К38 Игла',/igla/],['DAGR / PGM',/dagr|m_pg_at|m_pgm_at/],['Jian (условный аналог)',/m_jian/],
 ['Hydra 70',/hydra|ffar|rocket_04|m_at$/],['С-5',/s5(?:k|m|$)/],['С-8',/s8|80mm|rocket_03/],['С-13',/s13/],['С-24',/s24/],['С-25',/s25/],['MGM-166 LOSAT',/mgm_166/]
])f(id,re,n,n,n,n,[],'Прототип распознан по имени; точные численные характеристики этой версии не подтверждены в выбранных источниках.');
const addEvidence=(id,values)=>{const item=facts.find(x=>x.id===id);Object.assign(item,values);};
addEvidence('9М120 Атака',{range:'0,4–6 км для перечисленных экспортных вариантов',speed:'550 м/с = 1980 км/ч',guidance:'Командная; конкретный канал зависит от варианта',warhead:'Тандемная кумулятивная / объёмно-детонирующая / ОФ с неконтактным подрывом',sources:['https://roe.ru/upload/iblock/523/phao4lbmsf4r4o3u9x2kq2fn5c1q8eji.pdf'],note:'Вариант 9М120М отдельно не приравнивается к базовому.'});
addEvidence('С-8',{range:'С-8КОМ: 1,3–4 км',speed:n,guidance:'Неуправляемая',warhead:'С-8КОМ: 3,6 кг',sources:['https://roe.ru/pdfs/pdf_306.pdf'],note:'Параметры КОМ не заменяют паспорта DF/T.'});
function reference(id){id=id.toLowerCase();if(id.includes('r77'))return facts.find(f=>f.id==='Р-77 / РВВ-АЕ');if(id==='missile_aa_03_f')return facts.find(f=>f.id==='Р-73 / Р-74');return facts.find(f=>f.pattern.test(id))||null;}
function category(r){const id=r.ammoClass.toLowerCase(),label=(r.label||'').toLowerCase();
 if(/fuel|ptb|buddy_pod|wing_tank|a[l]?tflir|fuelpod|blank|empty|dummy|leaflet|swarm|analq/.test(id+' '+label))return 'Служебная подвеска/не ракета';
 if(/(?:^bo_|^bomb|^ammo_bomb|gbu|fab|kab|rbk|kmgu|cbu|mk_?8[1234]|tt_m118|tt_anm|bg250|ls6|upab|tg1000|agm154|agm62|mam.?l|drone_bomb|ace_missile_sdb)/.test(id))return 'Бомба/планирующий боеприпас';
 if(/crv7.*pg/.test(id))return 'Управляемая ракета';
 if(r.game.simulation==='shotRocket'||/hydra(?!.*dagr)|ffar|rocket_0[34]|r_80mm|r_hydra|rhs_ammo_s(?:5|8|13|24|25)(?!l)|m_at$/.test(id))return 'НАР';
 return 'Управляемая ракета';
}
module.exports={facts,reference,category};
