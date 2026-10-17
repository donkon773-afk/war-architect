# Mod environment and verification / Моди й рівні перевірки / Моды и уровни проверки

[English](#english) · [Українська](#ukrainian) · [Русский](#russian) · [Matrix / Матриця / Матрица](#matrix) · [Extended list / Розширений список / Расширенный список](#extended)

Snapshot / Знімок / Снимок: **17 October 2026 / 17 жовтня 2026 / 17 октября 2026**. Arma 3 **2.22.154089**. ACE **3.21.2.113** inspected on 16 October / перевірено 16 жовтня / проверен 16 октября. Other mod versions were not consistently captured; names alone do not pin a Workshop release. / Версії інших модів фіксувалися не завжди; сама назва не визначає версію Workshop. / Версии остальных модов фиксировались не всегда; название не определяет версию Workshop.

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

<a id="ukrainian"></a>

## Українська

Це перелік середовищ, використаних під час розробки та перевірок War Architect. Він **не означає, що кожен мод і кожне поєднання повністю перевірено в бою**.

Рівні підтвердження:

- **R — ігрова сесія:** мод було підключено у Warlords, місія дійшла до READY. У цій сесії виявлялися помилки покупок; відсутність конфліктів усіх функцій не підтверджено.
- **S — вихідний код/конфігурації/збірка:** перевірено встановлені PBO, класи, обробники чи залежності та відповідні перевірки проєкту. Реальний бойовий результат потребує окремого випробування.
- **L — завантаження:** мод був у параметрах розширеного запуску 17.10.2026, а журнал містить етап завантаження/переліку місій. Ініціалізацію вибраної місії у переглянутому журналі не підтверджено.

Один мод може мати кілька рівнів. Список L — запис середовища, а не рекомендований набір для одночасного ввімкнення.

### Обов’язкові залежності поточного збирача

| Режим / механіка | Залежності |
| --- | --- |
| Операції: повітряний бій, штурм і оборона, кампанія | CBA A3, ACE |
| Кампанія «Фронт і постачання» | Додатково FP-5 Flamingo та RHS AFRF; перевіряються ACE Missile Guidance/SAM |
| Ракетні профілі кампанії в DevMode | Додатково Blastcore Murr TT, RHS USAF, FMC PACK, 3CB Factions |
| Власні фракції та техніка | Моди, що надають вибрані класи, та їхні залежності |
| NeroAI через LM Studio | INIDBI2 і налаштований сервер моделі; LM Studio не є Workshop-модом |
| Warlords з основного центру | CBA; ACE примусово підключається чинною політикою запуску |

NeroAI Strategic, AirDefense та Missile Profiles — згенеровані компоненти War Architect. Вони збираються для вибраних налаштувань і не потребують окремої підписки у Workshop. Політику можна звірити з [operation-mod-policy.js](../control-center/operation-mod-policy.js).

### Відкриті питання сумісності

- Під час аудиту TT Armor System виявлено видалення `HandleDamage` в екіпажу, що може вплинути на ACE Medical. Це виявлений ризик, а не підтверджена сумісність.
- Підключений мод APS не обов’язково призначає активний захист кожній купленій машині. Різні реалізації мають власні умови й обмеження.
- Успішна збірка профілів Patriot/Х-47 не підтверджує заданого відсотка перехоплень. Для цього потрібні окремі серії випробувань у грі.
- Старий згенерований ракетний мод спричиняв помилку успадкування Х-55 під час запуску. Генератор виправлено; це не підстава вважати всі ракетні сценарії перевіреними.
- Наявність кількох модів, що змінюють ШІ, у списку завантаження не підтверджує узгодженості їхніх команд та обробників.

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

<a id="matrix"></a>

## Mod verification matrix / Матриця модів / Матрица модов

| Mod / Мод | Purpose / Призначення / Назначение | Evidence / Підтвердження / Подтверждение |
| --- | --- | --- |
| CBA A3 | Shared framework and event handlers / Спільна інфраструктура й обробники подій / Общая инфраструктура | R, S, L |
| ACE | Gameplay, medical, repair and missile integration / Ігрові механіки, медицина, ремонт та інтеграція ракет / Игровые механики и интеграция | R, S, L |
| RHS AFRF | Russian forces, air weapons, missiles and ERA/APS audit / Збройні сили РФ, авіаційне озброєння, ракети й аудит ДЗ/КАЗ / ВС РФ, ракеты и защита | R, S, L |
| RHS USAF | US forces, ATACMS and ERA audit / Армія США, ATACMS та аудит ДЗ / Армия США, ATACMS и защита | R, S, L |
| RHS GREF | Additional factions and vehicle catalogs / Додаткові фракції й каталоги техніки / Дополнительные фракции | R, S, L |
| RHS SAF | Serbian faction and classes / Сербська фракція та класи / Сербская фракция | R, S, L |
| CUP Weapons | Weapons and faction loadout inventory / Інвентаризація зброї та спорядження фракцій / Оружие и снаряжение | R, S, L |
| CUP Units | Infantry catalogs and presets / Каталоги й пресети піхоти / Каталоги пехоты | R, S, L |
| CUP Vehicles | Vehicle catalogs, faction presets and armor configuration / Каталоги техніки, пресети фракцій і конфігурація броні / Техника и конфигурация брони | R, S, L |
| CUP Terrains — Core | Terrain dependencies / Залежності карт / Зависимости карт | R, L |
| CUP Terrains — Maps | Terrain support / Підтримка карт / Карты | R, L |
| Australia FIXED | Australia scenario environment / Середовище сценаріїв Australia / Окружение сценариев Australia | R, S, L |
| Walzton, USA [MDE] | Warlords session on WINTERURBAN / Ігрова сесія Warlords на WINTERURBAN / Игровая сессия на WINTERURBAN | R, S, L |
| Zeus Enhanced | Zeus integration and editor attributes / Інтеграція Zeus та атрибути редактора / Зевс и атрибуты | R, S, L |
| LAMBS Danger.fsm | AI handoff and behavior integration / Передавання керування ШІ та інтеграція поведінки / Взаимодействие с ИИ | R, S, L |
| INIDBI2 — Official extension | NeroAI transport/storage / Обмін і зберігання даних NeroAI / Обмен данными NeroAI | R, S, L |
| 3CB Factions | Faction presets, vehicles and Scud definitions / Пресети фракцій, техніка й визначення Scud / Фракции, техника и Scud | R, S, L |
| F/A-18 Super Hornet | Aircraft classes and role selection / Класи авіації та вибір ролей / Авиация | R, S, L |
| SU-35 Flanker E | Aircraft classes and role selection / Класи авіації та вибір ролей / Авиация | R, S, L |
| FP-5 Flamingo | Physical cruise missile and launcher integration / Фізична крилата ракета й інтеграція пускової установки / Крылатая ракета и пусковая | S, L |
| Blastcore Murr Edition (TT Version) | Added missiles, ammunition and Kh-47 profiles / Ракети, боєприпаси та профілі Х-47 / Ракеты и профили Х-47 | S, L |
| FMC PACK | M270/ATACMS and vehicle configuration / M270/ATACMS і конфігурація техніки / ATACMS и техника | S, L |
| 3CB BAF Vehicles | British vehicle presets and armor configuration / Британські пресети техніки та конфігурація броні / Британская техника | S, L |
| TT Armor System | Damage model and ACE-handler audit / Модель пошкоджень та аудит обробників ACE / Модель урона и аудит обработчиков | S, L |
| TT ZTZ-99A | ERA calculation audit / Аудит розрахунків динамічного захисту / Расчёт динамической защиты | S, L |
| chelogach's Active Protection System | APS initialization and interception audit / Аудит ініціалізації та перехоплень КАЗ / Инициализация и работа КАЗ | S, L |
| BM Oplot | Vehicle catalog and ERA declarations / Каталог техніки та визначення ДЗ / Каталог и декларации ДЗ | S, L |
| T-84-120 Yatagan | Vehicle catalog and ERA declarations / Каталог техніки та визначення ДЗ / Каталог и декларации ДЗ | S, L |
| T80BVM / T-80BVM FIX | Vehicle catalog and ERA declarations / Каталог техніки та визначення ДЗ / Каталог и декларации ДЗ | S, L |
| TMT — Turkish Forces | Faction inventory and presets / Інвентаризація фракції та пресети / Инвентаризация фракции | S, L |
| Hellenic Armed Forces Mod (HAFM) | Faction and aircraft presets / Пресети фракцій та авіації / Фракции и авиация | S, L |
| Ukrainian Factions Project | Infantry/faction presets / Пресети піхоти й фракцій / Пресеты пехоты | S, L |
| TT Badger IFV, TT Rooikat MTTD, TT Leopard 2RI | Vehicle catalog and preset selection / Каталог техніки та вибір пресетів / Каталог техники и пресеты | S, L |

S refers to the stated scope in the Purpose column; it is not a claim that every feature in the mod was audited. / S стосується зазначеного призначення, а не всіх функцій моду. / S относится к указанному назначению, а не ко всем функциям мода.

## Evidence references / Джерела підтвердження / Основания

- Warlords session / Сесія Warlords / Сессия Warlords `Arma3_x64_2026-10-17_00-17-03.rpt`: mission / місія / миссия `NeroAI_Designed_WINTERURBAN_Native`; READY recorded / READY зафіксовано / READY зафиксирован; purchase failures / помилки покупок / ошибки покупок: [spawn incident report / звіт про спавн / отчёт о спавне](spawn-incident-20261017/REPORT_RU.md).
- [ACE, ERA and APS audit / Аудит ACE, ДЗ та КАЗ / Аудит ACE, ДЗ и КАЗ](ace-protection-audit-2026-10-16/REPORT_RU.md), including ACE version and TT Armor/ACE Medical risk / включно з версією ACE та ризиком TT Armor/ACE Medical / включая версию ACE и риск TT Armor/ACE Medical.
- [Missile and launcher inventory / Перелік ракет і пускових установок / Перечень ракет и пусковых установок](cruise-launchers-2026-10-16/REPORT_RU.md) / [Missile-profile startup incident / Збій запуску ракетних профілів / Сбой запуска ракетных профилей](crash-20261017/REPORT_RU.md).
- Expanded loading session / Сесія розширеного завантаження / Сессия расширенной загрузки `Arma3_x64_2026-10-17_01-44-07.rpt`; sanitized names / очищений перелік назв / очищенный перечень названий: [mod-load-environment-20261017.json](mod-load-environment-20261017.json). Raw local profiles, credentials and RPT files are not published. / Локальні профілі, облікові дані й сирі RPT не публікуються. / Локальные профили, учётные данные и исходные RPT не публикуются.

<a id="extended"></a>

## Extended loading list / Розширений список завантаження / Расширенный список загрузки

**103 external mod folder names** were present in the inspected launch configuration. This preserves the names as observed, including alternative terrain packages; it does not merge them into a certified preset. Generated War Architect addons are excluded from this count.

**103 назви папок зовнішніх модів** були в переглянутій конфігурації запуску. Назви збережено як у середовищі, включно з альтернативними пакетами карт. Це не єдиний перевірений пресет. Власні згенеровані аддони War Architect не входять до цього числа.

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
