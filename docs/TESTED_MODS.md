# Mod environment and verification / Моды и уровни проверки

[Русский](#russian) · [English](#english) · [Матрица / Matrix](#matrix) · [Расширенный список / Extended list](#extended)

Snapshot: **17 October 2026 / 17 октября 2026**. Arma 3 **2.22.154089**. The inspected ACE installation was **3.21.2.113** on 16 October. Other mod versions were not consistently captured; names alone do not pin a Workshop release.

<a id="russian"></a>

## Русский

Это перечень окружений, использовавшихся при разработке и проверках War Architect. Он **не означает, что каждый мод и каждая комбинация полностью проверены в бою**.

Уровни подтверждения:

- **R — игровая сессия:** мод был подключён в Warlords, миссия дошла до READY. В этой сессии обнаруживались ошибки покупок; отсутствие конфликтов всех функций не подтверждено.
- **S — исходники/конфигурации/сборка:** проверены установленные PBO, классы, обработчики или зависимости и соответствующие проверки проекта. Реальный боевой результат требует отдельного испытания.
- **L — загрузка:** мод присутствовал в параметрах расширенного запуска 17.10.2026, и журнал содержит этап загрузки/перечисления миссий. Инициализация выбранной миссии в просмотренном журнале не подтверждена.

У одного мода может быть несколько уровней. Список L — архив окружения, а не рекомендуемый набор для одновременного включения.

### Обязательные зависимости текущего сборщика

| Режим / механика | Зависимости |
| --- | --- |
| Операции: воздушное сражение, штурм и оборона, кампания | CBA A3, ACE |
| Кампания «Фронт и снабжение» | Дополнительно FP-5 Flamingo и RHS AFRF; проверяются ACE Missile Guidance/SAM |
| Ракетные профили кампании в DevMode | Дополнительно Blastcore Murr TT, RHS USAF, FMC PACK, 3CB Factions |
| Собственные фракции и техника | Моды, предоставляющие выбранные классы, и их зависимости |
| NeroAI через LM Studio | INIDBI2 и настроенный сервер модели; LM Studio не является Workshop-модом |
| Warlords из основного центра | CBA; ACE принудительно подключается действующей политикой запуска |

NeroAI Strategic, AirDefense и Missile Profiles — генерируемые части War Architect. Они собираются под выбранные настройки и не требуют отдельной подписки на Workshop. Политику можно сверить с [operation-mod-policy.js](../control-center/operation-mod-policy.js).

### Оставшиеся вопросы совместимости

- В аудите TT Armor System найдено удаление `HandleDamage` у экипажа, которое может затронуть ACE Medical. Это выявленный риск, а не подтверждённая совместимость.
- Подключённый мод APS не обязательно назначает активную защиту каждой купленной машине. У разных реализаций свои условия и ограничения.
- Успешная сборка профилей Patriot/Х-47 не подтверждает заданный процент перехвата. Для этого нужны отдельные игровые серии испытаний.
- Старый генерируемый мод ракет вызывал ошибку наследования Х-55 при запуске. Генератор исправлен; это не основание объявлять все ракетные сценарии проверенными.
- Наличие нескольких модов, меняющих ИИ, в списке загрузки не подтверждает согласованность их команд и обработчиков.

<a id="english"></a>

## English

This document records environments used during War Architect development and verification. It **does not claim that every listed mod or every combination has passed complete combat testing**.

Evidence levels:

- **R — mission session:** the mod was enabled in a Warlords session that reached READY. Purchase errors were observed in that session; full feature compatibility was not established.
- **S — source/configuration/build:** installed PBOs, classes, handlers or dependencies were inspected and relevant project checks were performed. Combat behavior still requires in-game verification.
- **L — loading:** the mod appeared in the expanded launch parameters on 17 October 2026, with mod loading/mission enumeration observed in the log. Initialization of the selected mission was not established in the inspected log.

A mod may have more than one evidence level. The L list is an environment record, not a recommended all-in-one loadout.

### Dependencies enforced by the current builder

| Mode / feature | Dependencies |
| --- | --- |
| Operations: air battle, assault and defense, campaign | CBA A3, ACE |
| Frontline and Supply campaign | Additionally FP-5 Flamingo and RHS AFRF; ACE Missile Guidance/SAM files are checked |
| Campaign missile profiles enabled in DevMode | Additionally Blastcore Murr TT, RHS USAF, FMC PACK and 3CB Factions |
| Custom factions and vehicles | The mods providing the selected classes and their dependencies |
| NeroAI through LM Studio | INIDBI2 and a configured model server; LM Studio is not a Workshop mod |
| Warlords from the main Control Center | CBA; the current launch policy also forces ACE loading |

NeroAI Strategic, AirDefense and Missile Profiles are generated War Architect components. They are built for the selected configuration and do not require separate Workshop subscriptions. See [operation-mod-policy.js](../control-center/operation-mod-policy.js).

### Open compatibility issues

- TT Armor System was found to remove crew `HandleDamage` handlers, potentially affecting ACE Medical. This is an identified risk, not verified compatibility.
- Loading an APS mod does not necessarily initialize active protection on every purchased vehicle. Implementations have different conditions and limitations.
- Building Patriot/Kh-47 profiles successfully does not establish an interception percentage. Dedicated in-game trials are required.
- An older generated missile addon caused a Kh-55 inheritance error at startup. The generator has been corrected; this does not certify every missile scenario.
- Loading multiple AI mods together does not establish that their orders and handlers cooperate correctly.

<a id="matrix"></a>

## Матрица модов / Mod verification matrix

| Mod | Purpose / Назначение | Evidence |
| --- | --- | --- |
| CBA A3 | Shared framework and event handlers / Общая инфраструктура | R, S, L |
| ACE | Gameplay, medical, repair and missile integration / Игровые механики и интеграция | R, S, L |
| RHS AFRF | Russian forces, air weapons, missiles and ERA/APS audit / ВС РФ, ракеты и защита | R, S, L |
| RHS USAF | US forces, ATACMS and ERA audit / Армия США, ATACMS и защита | R, S, L |
| RHS GREF | Additional factions and vehicle catalogs / Дополнительные фракции | R, S, L |
| RHS SAF | Serbian faction and classes / Сербская фракция | R, S, L |
| CUP Weapons | Weapons and faction loadout inventory / Оружие и снаряжение | R, S, L |
| CUP Units | Infantry catalogs and presets / Каталоги пехоты | R, S, L |
| CUP Vehicles | Vehicle catalogs, faction presets and armor configuration / Техника и конфигурация брони | R, S, L |
| CUP Terrains — Core | Terrain dependencies / Зависимости карт | R, L |
| CUP Terrains — Maps | Terrain support / Карты | R, L |
| Australia FIXED | Australia scenario environment / Окружение сценариев Australia | R, S, L |
| Walzton, USA [MDE] | Warlords session on WINTERURBAN / Игровая сессия на WINTERURBAN | R, S, L |
| Zeus Enhanced | Zeus integration and editor attributes / Зевс и атрибуты | R, S, L |
| LAMBS Danger.fsm | AI handoff and behavior integration / Взаимодействие с ИИ | R, S, L |
| INIDBI2 — Official extension | NeroAI transport/storage / Обмен данными NeroAI | R, S, L |
| 3CB Factions | Faction presets, vehicles and Scud definitions / Фракции, техника и Scud | R, S, L |
| F/A-18 Super Hornet | Aircraft classes and role selection / Авиация | R, S, L |
| SU-35 Flanker E | Aircraft classes and role selection / Авиация | R, S, L |
| FP-5 Flamingo | Physical cruise missile and launcher integration / Крылатая ракета и пусковая | S, L |
| Blastcore Murr Edition (TT Version) | Added missiles, ammunition and Kh-47 profiles / Ракеты и профили Х-47 | S, L |
| FMC PACK | M270/ATACMS and vehicle configuration / ATACMS и техника | S, L |
| 3CB BAF Vehicles | British vehicle presets and armor configuration / Британская техника | S, L |
| TT Armor System | Damage model and ACE-handler audit / Модель урона и аудит обработчиков | S, L |
| TT ZTZ-99A | ERA calculation audit / Расчёт динамической защиты | S, L |
| chelogach's Active Protection System | APS initialization and interception audit / Инициализация и работа КАЗ | S, L |
| BM Oplot | Vehicle catalog and ERA declarations / Каталог и декларации ДЗ | S, L |
| T-84-120 Yatagan | Vehicle catalog and ERA declarations / Каталог и декларации ДЗ | S, L |
| T80BVM / T-80BVM FIX | Vehicle catalog and ERA declarations / Каталог и декларации ДЗ | S, L |
| TMT — Turkish Forces | Faction inventory and presets / Инвентаризация фракции | S, L |
| Hellenic Armed Forces Mod (HAFM) | Faction and aircraft presets / Фракции и авиация | S, L |
| Ukrainian Factions Project | Infantry/faction presets / Пресеты пехоты | S, L |
| TT Badger IFV, TT Rooikat MTTD, TT Leopard 2RI | Vehicle catalog and preset selection / Каталог техники и пресеты | S, L |

S refers to the stated scope in the Purpose column; it is not a claim that every feature in the mod was audited. / S относится к указанному назначению, а не ко всем функциям мода.

## Основания / Evidence references

- Warlords session `Arma3_x64_2026-10-17_00-17-03.rpt`: mission `NeroAI_Designed_WINTERURBAN_Native`, READY recorded; purchase failures documented in [spawn incident report](spawn-incident-20261017/REPORT_RU.md).
- [ACE, ERA and APS audit](ace-protection-audit-2026-10-16/REPORT_RU.md), including the inspected ACE version and TT Armor/ACE Medical risk.
- [Missile and launcher inventory](cruise-launchers-2026-10-16/REPORT_RU.md) and [missile-profile startup incident](crash-20261017/REPORT_RU.md).
- Expanded loading session `Arma3_x64_2026-10-17_01-44-07.rpt`; sanitized names recorded in [mod-load-environment-20261017.json](mod-load-environment-20261017.json). Raw local profiles, credentials and RPT files are not published.

<a id="extended"></a>

## Расширенный список загрузки / Extended loading list

**103 external mod folder names** were present in the inspected launch configuration. This preserves the names as observed, including alternative terrain packages; it does not merge them into a certified preset. Generated War Architect addons are excluded from this count.

**103 имени папок внешних модов** присутствовали в просмотренной конфигурации запуска. Имена сохранены как в окружении, включая альтернативные пакеты карт. Это не единый проверенный пресет. Собственные генерируемые аддоны War Architect в число не входят.

<!-- loaded-mods:start -->

- Australia FIXED
- 120-PM-43
- 3CB BAF Equipment
- @Australia
- A3-TTS (text to speech)
- A3TI REAP-IR
- A3UE - Change Emplacement Vehicle
- A3UE Active-Anti-artillery-Defence-System
- Aaren's Sound Core
- Antistasi Ultimate - Mod
- Archie, Summer
- Archie, Winter
- Arma Realistic Map Assets V2
- Australia
- Bastek
- Battle AI A3 v0.92
- Blastcore Murr Edition(TT Version)
- BM Oplot
- Bulat UAV Detector by Nerexis
- chelogach's Active Protection System
- Commander Mod - Tactical AI Map Control [RU]
- CTDL Lambs
- CUP Terrains - Core
- CUP Terrains - CWA
- CUP Terrains - Maps
- CUP Terrains - Maps 2.0
- CUP Weapons
- D-20 M1955
- Death and Hit reactions
- Deformer
- DISMEMBERMENT+GORE [SP-MP]
- DUI - Squad Radar
- dzn eXtended Pointer Interactions
- INIDBI2 - Official extension
- JCA - ADS-1 NASAMS
- JCA - ADS-2 Skynex
- JCA - Land Systems
- JSRS SOUNDMOD 2025
- LAMBS_Danger.fsm
- LAMBS_Suppression
- Left 4 Dead Content pack
- Lybor
- Plane Reversing (Mod)
- POSADKOVO
- Project America - Objects
- RHSPKL
- RHSSAF
- RHSTERRACORE
- Sanagasta
- SSD Death Screams 2.1
- Star Light
- Suppress
- T-84-120 Yatagan
- ToH Dummy CUP
- TT Armor system
- TT J10A
- TT Juggernaut
- TT Merkava Mk.4M
- TT MGM-166 LOSAT
- TT Panzerfaust3
- TT RPG-7
- TT Sturmtiger
- TT ZTZ-99A
- VERESKOVO
- Virolahti - Valtatie 7
- Vision Guard AI
- Walzton, USA Objects
- Walzton, USA [MDE]
- Warlords RHS Edition Mod
- Zeus Enhanced
- [A3UE] - Frontlines & Patrols (A3U v12.0)
- [A3UE] Archie, Summer
- [A3UE] Archie, Winter
- [A3UE] Australia
- [A3UE] Bastek
- [A3UE] CL's Antistasi QoL Tweaks
- [A3UE] Posadkovo & Vereskovo
- [A3UE] Sanagasta
- ace
- CBA_A3
- FP-5 -Flamingo-
- RHSAFRF
- RHSUSAF
- FMC PACK
- 3CB Factions
- CUP Units
- TMT - Turkish Forces
- GX - Drones
- QAV - Merkava
- 3CB BAF Vehicles
- CUP Vehicles
- Ukrainian Factions Project
- Hellenic Armed Forces Mod (HAFM)
- TT Badger IFV
- TT Rooikat MTTD
- TT Leopard 2RI
- FA-18 Super Hornet
- RHSGREF
- RE- RHS Escalation
- MT-LB - The Soviet Workhorse
- T-80BVM FIX
- T80BVM
- SU-35 Flanker E

<!-- loaded-mods:end -->
