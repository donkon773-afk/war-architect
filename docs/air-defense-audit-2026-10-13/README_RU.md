# ПВО и РЛС: аудит установленных конфигураций, 13.10.2026

Проверено 4425 бинарных конфигураций ванильной игры и установленных модов; ошибок чтения 0. Отдельно прочитано 1378 конфигураций без модов. Игру не запускали, игровые пакеты и настройки не изменяли.

Это значения из файлов, а не результат испытания попаданий. Сводное наследование построено в порядке сканирования каталога: порядок загрузки зависимостей движком и динамические настройки ACE/модов могут изменить итог. Для окончательной проверки необходим экспорт configFile из игры с тем же набором модов.

maxSpeed боеприпаса и missileLockMaxSpeed цели указаны в м/с; умножение на 3,6 даёт км/ч. Дальность сенсора, дальность захвата и предпочтения стрельбы ИИ различаются. Число ракет ниже — суммарный исходный запас магазинов, включая резерв, а не число одновременно готовых пусковых труб.

Источники по смыслу параметров: [сенсоры](https://community.bistudio.com/wiki/Arma_3:_Sensors_Config_Reference), [захват целей](https://community.bistudio.com/wiki/A3_Targeting_config_reference), [боеприпасы](https://community.bistudio.com/wiki/CfgAmmo).

## Чистая ванильная игра

| Система / класс | Активная РЛС, воздух / фон земли, м | Ракеты: запас; окно захвата, м; maxSpeed, м/с; предел скорости цели, м/с | Пушечный боезапас |
|---|---|---|---|
| IFV-6a Cheetah<br>`B_APC_Tracked_01_AA_F` | 9000 / 6000; сектор 360° | 4Rnd_Titan_long_missiles: 8; 100–4500; 850; 500 | 680Rnd_35mm_AA_shells_Tracer_Red: 680 |
| ZSU-39 Tigris<br>`O_APC_Tracked_02_AA_F` | 9000 / 6000; сектор 360° | 4Rnd_Titan_long_missiles_O: 8; 100–4500; 850; 500 | 680Rnd_35mm_AA_shells_Tracer_Green: 680 |
| AWC Nyx (AA)<br>`I_LT_01_AA_F` | Не найден активный компонент | 4Rnd_70mm_SAAMI_missiles: 8; 200–8000; 850; 250 | 100Rnd_127x99_mag_Tracer_Red: 400 |
| Static Titan AA<br>`B_static_AA_F` | Не найден активный компонент | 1Rnd_GAA_missiles: 4; 100–3500; 850; 250 | — |
| Praetorian 1C<br>`B_AAA_System_01_F` | 10000 / 7000; сектор 360° | — | magazine_Cannon_Phalanx_x1550: 3100 |
| Mk49 Spartan<br>`B_SAM_System_01_F` | Не найден активный компонент | magazine_Missile_rim116_x21: 21; 250–4000; 800; 600 | — |
| Mk21 Centurion<br>`B_SAM_System_02_F` | 14000 / 10000; сектор 15° | magazine_Missile_rim162_x8: 8; 800–12000; 900; 888.8889770507812 | — |
| MIM-145 Defender<br>`B_SAM_System_03_F` | Не найден активный компонент | magazine_Missile_mim145_x4: 4; 1000–16000; 850; 777.7780151367188 | — |
| S-750 Rhea<br>`O_SAM_System_04_F` | Не найден активный компонент | magazine_Missile_s750_x4: 4; 1000–16000; 850; 777.7780151367188 | — |

## Установленные конфигурации с модами

| Система / класс | Активная РЛС, воздух / фон земли, м | Ракеты: запас; окно захвата, м; maxSpeed, м/с; предел скорости цели, м/с | Пушечный боезапас |
|---|---|---|---|
| Bardelas<br>`B_APC_Tracked_01_AA_F` | 9000 / 6000; сектор 360° | ace_missile_manpad_stinger: 8; 250–5000; 850; 2000 | 680Rnd_35mm_AA_shells_Tracer_Red: 680 |
| ЗСУ-35 Тигрис<br>`O_APC_Tracked_02_AA_F` | 9000 / 6000; сектор 360° | ace_missile_manpad_stinger: 8; 250–5000; 850; 2000 | 680Rnd_35mm_AA_shells_Tracer_Green: 680 |
| Wiesel 2 Ozelot (ЗРК)<br>`I_LT_01_AA_F` | Не найден активный компонент | ace_missile_manpad_stinger: 8; 250–5000; 850; 2000 | 100Rnd_127x99_mag_Tracer_Red: 400 |
| Mini-Spike ПУ (ЗРК)<br>`B_static_AA_F` | Не найден активный компонент | 1Rnd_GAA_missiles: 4; 100–3500; 850; 250 | — |
| Praetorian 1C<br>`B_AAA_System_01_F` | 10000 / 7000; сектор 360° | — | magazine_Cannon_Phalanx_x1550: 3100 |
| Mk49 Spartan<br>`B_SAM_System_01_F` | Не найден активный компонент | ace_missile_manpad_rim116: 21; 250–5000; 800; 2000 | — |
| Mk-29 ESSM<br>`B_SAM_System_02_F` | 14000 / 10000; сектор 15° | ace_missile_sam_RIM162: 8; 800–12000; 900; 888.8889770507812 | — |
| MIM-104 Patriot<br>`B_SAM_System_03_F` | Не найден активный компонент | ace_missile_sam_patriot: 4; 1000–16000; 850; 777.7780151367188 | — |
| S-400<br>`O_SAM_System_04_F` | Не найден активный компонент | ace_missile_sam_s400: 4; 1000–16000; 850; 777.7780151367188 | — |
| 2S6 Tunguska<br>`CUP_O_2S6_RU` | 16000 / 0; сектор 360° | CUP_8Rnd_9M311_Tunguska_M: 8; 2500–8000; 900; 500 | CUP_1904Rnd_TE1_30mm_2A38M_HE_M: 1904 |
| 2S6M Tunguska-M<br>`CUP_O_2S6M_RU` | 16000 / 0; сектор 360° | CUP_8Rnd_9M311M_Tunguska_M: 8; 2500–10000; 900; 500 | CUP_1904Rnd_TE1_30mm_2A38M_HE_M: 1904 |
| 2S6 Tunguska<br>`UK3CB_CW_SOV_O_EARLY_2S6_Tunguska` | 12000 / 0; сектор 360° | UK3CB_9M311_8rnds: 8; 10–8000; 600; -1e10 | uk3cb_mag_AZP23_2000_green: 2000 |
| 2S6M Tunguska<br>`UK3CB_ARD_I_2S6M_Tunguska` | 16000 / 6000; сектор 360° | UK3CB_9M311M1_8rnds: 8; 10–10000; 600; -1e10 | uk3cb_mag_AZP23_2000_yellow: 2000 |
| 9K22 Tunguska (SA-19)<br>`OFP_O_2S6_RU` | 10000 / 0; сектор 360° | magazine_Missile_9M311_x8: 8; 100–6000; 880; 888 | OFP_1904Rnd_TE1_30mm_2A38M_HE_M: 1904 |
| 9K22 Tunguska-M (SA-19)<br>`OFP_O_2S6M_RU` | 16000 / 0; сектор 360° | magazine_Missile_9M311_1M_x8: 8; 500–10000; 880; 888 | OFP_1904Rnd_TE1_30mm_2A38M_HE_M: 1904 |
| Multi-Missile NASAMS Launcher<br>`FMC_NASAMS_F` | 9000 / 4000; сектор 145° | mag_Missile_NASAMS_x4_C: 4; 800–12000; 900; 777.7780151367188<br>mag_Missile_NASAMS_x2_AIM: 2; 250–5000; 700; 600 | — |
| ADS-1 NASAMS<br>`E22_B_JC_W_SAM_system_01_F` | Не найден активный компонент | JCA_magazine_NASAMS: 6; 500–16000; 900; 888.8889770507812 | — |
| ADS-2 Skynex<br>`E22_B_JC_W_AAA_System_01_F` | 14000 / 10000; сектор 30° | — | JCA_600Rnd_35mm_AA_shells_Tracer_Green: 1200 |
| M1097 (Avenger, Desert)<br>`CUP_B_nM1097_AVENGER_USA_DES` | Не найден активный компонент | CUP_8Rnd_Stinger_M: 8; 100–7600; 750; 200 | CUP_250Rnd_TE1_Red_Tracer_127x99_M: 500 |
| XM1108 Avenger<br>`UK3CB_KRG_B_M270_Avenger` | 16000 / 6000; сектор 360° | uk3cb_mag_fim92: 8; 300–6500; 750; 333 | 200Rnd_127x99_mag_Tracer_Red: 800; uk3cb_mag_100rnd_127x99_red: 1000 |
| M6 Linebacker (Desert)<br>`CUP_B_M6LineBacker_USA_D` | Не найден активный компонент | CUP_4Rnd_Stinger_M: 8; 100–7600; 750; 200<br>CUP_2Rnd_Stinger_M: 2; 100–7600; 750; 200 | CUP_70Rnd_TE1_Red_Tracer_25mm_M242_APFSDS: 210; CUP_230Rnd_TE1_Red_Tracer_25mm_M242_HE: 690; CUP_800Rnd_TE4_Red_Tracer_762x51_M240_M: 2400 |
| M163A1 VADS<br>`CUP_B_M163_Vulcan_USA` | 4000 / 0; сектор 30° | — | CUP_1100Rnd_TE1_Red_Tracer_20mm_M168_M: 1100 |
| ZSU-23-4<br>`CUP_B_ZSU23_CDF` | 5000 / 0; сектор 360° | — | CUP_2000Rnd_23mm_AZP23_M: 2000 |
| ZSU-23-4 Afghanski<br>`CUP_B_ZSU23_Afghan_CDF` | 5000 / 0; сектор 360° | — | CUP_2000Rnd_23mm_AZP23_M: 4000 |
| ЗСУ-23-4<br>`rhs_zsu234_aa` | 14000 / -1; сектор 360° | — | rhs_mag_AZP23_2000: 2000 |
| ZU-23-2<br>`RHS_ZU23_MSV` | Не найден активный компонент | — | RHS_mag_AZP23_100: 600 |
| ЗУ-23-2<br>`CUP_B_ZU23_AFU` | Не найден активный компонент | — | CUP_100Rnd_23mm_AZP23_M: 600 |
| Hilux (ZU23)<br>`UK3CB_ADA_B_Hilux_Zu23` | Не найден активный компонент | — | uk3cb_mag_AZP23_100_red: 600 |
| FIM-92F (DMS)<br>`RHS_Stinger_AA_pod_D` | Не найден активный компонент | Rhs_mag_2Rnd_stinger: 10; 300–6500; 750; 333 | — |
| ОПУ Джигит<br>`rhs_Igla_AA_pod_msv` | Не найден активный компонент | rhs_mag_2Rnd_Igla: 10; 300–4800; 800; 333 | — |
| FIM92 (DMS)<br>`CUP_B_CUP_Stinger_AA_pod_US` | Не найден активный компонент | CUP_2Rnd_Stinger_M: 20; 100–7600; 750; 200 | — |
| ОПУ Джигит<br>`CUP_B_Igla_AA_pod_AFU` | Не найден активный компонент | CUP_2Rnd_Igla_M: 20; 100–5200; 600; 320 | — |
| S-300<br>`b_afougf_SAM_System_04_green_F` | Не найден активный компонент | ace_missile_sam_s400: 4; 1000–16000; 850; 777.7780151367188 | — |
| R73 Technical Launcher<br>`OFP_I_Hilux_MLRS_TK` | Не найден активный компонент | 2Rnd_Missile_AA_04_F: 8; 150–4500; 920; 445 | — |
| РЛС AN/MPQ-105<br>`B_Radar_System_01_F` | 16000 / 12000; сектор 120° | — | — |
| РЛС R-750 Cronus<br>`O_Radar_System_02_F` | 16000 / 12000; сектор 120° | — | — |
| AN/MPQ-64 Sentinel<br>`E22_O_JC_U_Radar_system_01_F` | 16000 / 12000; сектор 120° | — | — |
| Radar<br>`UK3CB_CSAT_A_O_Radar_System` | 16000 / 12000; сектор 120° | — | — |
| AN/TPQ-48 Легкий контрмінометний радар<br>`b_afougf_lcmr_radar` | Не найден активный компонент | — | — |
| CH-146 Griffin (Radar)<br>`UK3CB_CSAT_F_O_Bell412_Radar` | 10000 / 8000; сектор 120° | — | — |
| CH-146 Griffon (Radar)<br>`CUP_B_412_Military_Radar_HIL` | 4000 / 4000; сектор 120° | — | — |
| EC-130V Hercules AWACS<br>`FMC_B_C130J_Cargo_USMC` | 16000 / 8000; сектор 360° | — | — |

## Выявленные ограничения

- Praetorian и Skynex каталог классифицирует как UAV; это ошибка выбора роли ПВО.
- Название S-300 в Ukrainian Factions Project относится к наследнику ванильной пусковой установки S-750. Самостоятельная РЛС С-300 в этой строке не обнаружена.
- AN/TPQ-48: активный воздушный сенсор и вооружение в проверенной конфигурации отсутствуют. Название радара не делает его РЛС наведения ПВО. Скрипты контрбатарейной работы отдельно не оценивались.
- Mk49 не имеет собственного активного радарного компонента. Пусковые MIM-145 / S-750 / JCA NASAMS используют обмен данными; собственная активная РЛС пусковой не обнаружена.
- JCA NASAMS: предел захвата ракеты 16 км, но активный сенсор ракеты 12 км. Это не гарантия автономного наведения с 16 км.
- CUP Stinger: предел захвата цели 200 м/с = 720 км/ч. Штатный статический Titan: 250 м/с = 900 км/ч. Такие ограничения ниже скоростей Фламинго 1000 км/ч и Х-55 918 км/ч.
- CUP Igla: 320 м/с; RHS Igla / Stinger: 333 м/с. Ограничение скорости допускает обе крылатые ракеты, но не гарантирует обнаружение или попадание.
- В ACE встречается maneuvrability=0: дополнительное наведение может работать через скрипт ACE, поэтому это не доказательство неспособности ракеты поворачивать.
- Дальность сенсоров Skynex 14 км / Praetorian 10 км не равна дальности пушечного огня. В дальних режимах ИИ задано соответственно 3,5 км / 3 км.
- RHS Шилка: найден активный сенсор 14 км, минимальная высота сопровождения 50 м, минимальная скорость 25 м/с; эти значения относятся к проверенному набору конфигураций и патчей.
- Текущий сценарий содержит покупки чужих фракций и сторон: редактор разрешает такой состав. Это не каноническая принадлежность системы.

## Текущий сохранённый сценарий

### WEST

- M1097 (Avenger, Desert) — `CUP_B_nM1097_AVENGER_USMC_DES`
- XM1108 Avenger — `UK3CB_KRG_B_M270_Avenger`
- Mini-Spike ПУ (ЗРК) — `B_static_AA_F`
- M163A1 VADS — `CUP_I_M163_Vulcan_RACS`
- MIM-104 Patriot — `I_E_SAM_System_03_F`
- Multi-Missile NASAMS Launcher — `FMC_NASAMS_F`
- РЛС AN/MPQ-105 — `B_Radar_System_01_F`

### EAST

- ЗСУ-35 Тигрис — `O_APC_Tracked_02_AA_F`
- S-400 — `O_SAM_System_04_F`
- РЛС R-750 Cronus — `O_Radar_System_02_F`
- VDV GAZ-66 (Zu-23) — `UK3CB_CW_SOV_O_EARLY_VDV_Gaz66_ZU23`
- VDV Ural 4320 (ZU-23) — `UK3CB_CW_SOV_O_EARLY_VDV_Ural_Zu23`
- VDV 9K38 (Djigit) — `UK3CB_CW_SOV_O_Early_VDV_Igla_AA_pod`
- ЗСУ-23-4 — `rhs_zsu234_vdv_des`
- Урал-4320 (ЗУ-23-2) — `RHS_Ural_Zu23_VDV_01`
- ZU-23-2 — `RHS_ZU23_VDV`
- 2S6M Tunguska — `UK3CB_ARD_I_2S6M_Tunguska`
- 9K22 Tunguska (SA-19) — `OFP_O_2S6_RU`
- S-300 — `b_afougf_SAM_System_04_green_F`
- CH-146 Griffin (Radar) — `UK3CB_CSAT_F_O_Bell412_Radar`
- AN/MPQ-64 Sentinel — `E22_O_JC_U_Radar_system_01_F`
- AN/TPQ-48 Легкий контрмінометний радар — `b_afougf_lcmr_radar`
- ОПУ Джигит — `rhs_Igla_AA_pod_vmf`

## Дополнительные варианты

`all-variants.csv` содержит 1017 вариантов классов с исходным запасом вооружения, сенсорами, происхождением и признаком выбора в сценарии. Это включает окраски, фракционные копии и радарные вертолёты; число строк не равно числу разных конструкций. В `config-evidence.json` сохранены исходные числовые свойства, пути PBO, сенсоры и режимы оружия; `config-evidence-vanilla.json` — отдельная ванильная выборка.

Дополнительная находка: ракеты UK3CB_AMMO_9M311 / UK3CB_AMMO_9M311M1 имеют необычное строковое значение missileLockMaxSpeed=-1e10. Его эффективное чтение движком и фактический захват требуют проверки; считать это подтверждённым отсутствием скоростного ограничения нельзя.
