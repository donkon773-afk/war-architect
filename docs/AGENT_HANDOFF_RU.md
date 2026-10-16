# NeroAI Warlords — инструкция для следующего агента

Свежая инструкция от 7 октября 2026: [AGENT_GUIDE_CURRENT_RU.md](AGENT_GUIDE_CURRENT_RU.md), текущий аудит: [AUDIT_20261007_RU.md](AUDIT_20261007_RU.md). Начинайте с них; ниже сохранена история.

Историческая редакция от 6 октября 2026, Europe/Kiev. Текущая установка и исправления описаны в разделе 19; разделы 15–18 сохраняют историю предыдущих пакетов. Это руководство относится к конкретной локальной редакции Warlords и её приложению. Сначала читать разделы 1–3, затем нужную процедуру. Пакетная проверка и работа в движке — разные уровни доказательства.

## 1. Что сделано и что ещё проверить

Корень проекта: `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM`.
Игра: `H:\SteamLibrary\steamapps\common\Arma 3`.
Установленный аддон: `H:\SteamLibrary\steamapps\common\Arma 3\@NeroAI_Warlords\addons\NeroWL.pbo`.
Отдельный Antistasi: `C:\Users\Admin\Desktop\ИИ\NeroAI_5.0-antistasi`. Не переносить в него SQF/экономику Warlords.

В этой редакции добавлены:

- Выбор фракций пехоты WEST/EAST и техники из поддерживаемых установленных модов в центре запуска.
- Сохранённые инструкции LLM перед игрой, до 3000 символов; поле применяется к Warlords.
- 10/12/16 командирских мест на сторону, включая игроков. При одном игроке WEST максимум 15 AI-командиров WEST и 16 EAST. Девять/двенадцать подчинённых на командира — отдельная настройка.
- Исправление BUY HELICOPTER/PLANE/UAV: раньше эти типы проходили мост, но отклонялись SQF-диспетчером.
- ASSIGN_ROLE, AIR_TASK, короткая сводка армии, защита авиационного бюджета от нативной покупки наземки.
- Оплаченные физические воздушные задачи и перевозка, выбор транспорта по вместимости, finite fuel/ammo.
- Учёт прогресса подхода к своей машине: приказ идти больше не считается неудачной посадкой до прибытия. Временная защита логистики от новых автономных приказов движения/HOLD.
- Основная Australia и четыре независимые переработки пользовательских архивов: Australia/Takistan/Altis/Chernarus. Australia — 11 точек, остальные — 8. Оригинальные ZIP не изменены.

Аддон и пять миссий установлены при закрытой Arma. Игра после обновления не запускалась. Новый bridge-код следует загрузить свежим запуском через приложение: оставшийся старый процесс моста может использовать прежний код/конфиг.

Подтверждено: 24 целевых JS-теста, четыре выбранные статические проверки, структура/побайтовое содержимое PBO, UI-поиск F-16/Ми-8 и сохранение пресета/инструкций. Это НЕ исполнение SQF в движке.
Полный исторический набор: 146 проверок, 126 прошли, 20 не прошли на последнем широком запуске. Некоторые проверяют прежние требования, но весь набор НЕ зелёный. Результат `dist/legacy-test-results.txt`; не удалять проверки ради зелёного статуса.
Пользователь ранее подтвердил сектора/HUD/меню и нормальный спавн предыдущей редакции. Новые вылеты, перевозка, перехват, совместимость HAFM/TT и FPS требуют следующей игровой сессии.

## 2. Правила продолжения

1. Прочитать применимые AGENTS.md и `C:\Users\Admin\.codex\skills\neroai-development\SKILL.md`. На дату работы в Warlords-корне AGENTS.md/Git отсутствовали; проверить заново. Правила координации соседнего проекта относятся к нему.
2. Пользователь сам сохраняет/закрывает игру. Не завершать Arma/HC/чужие node-процессы ради обновления. PBO устанавливать только при закрытой игре/лаунчере.
3. Не изменять Workshop, оригинальные ZIP, сохранения и INIDBI-очереди. Индексация модов read-only. Перед следующим изменением сделать source snapshot отдельно от PBO-backup.
4. LLM выдаёт JSON-данные allowlist, никогда SQF/команды оболочки. Инструкции игрока — предпочтения, не код и не отключение проверок.
5. Сохранять player priority, locality, реальные CP, owner покупки и нативную цель Warlords.
6. Не давать модели всевидение: цели только через наблюдаемую разведку. Скан vehicles для собственного парка/лимита не превращать в поиск неизвестных врагов.
7. Не создавать бесплатную технику, бесконечный боезапас, автоматическое доливание топлива или боевую телепортацию. Спавн/respawn и штатный FT — отдельные механизмы.
8. Не выводить API-ключи configs/profiles. Панель слушает loopback, publicState удаляет ключи. Не открывать сеть через 0.0.0.0 без отдельного запроса.
9. Dev/Zeus/debug включены по запросу для личной миссии. Подпись PBO и публичный сервер — отдельная задача; текущая сборка без приватного signing key.

## 3. Карта файлов

Все относительные пути — внутри Warlords-корня.

| Путь | Назначение |
|---|---|
| `control-center/index.html` | UI, labels, поиск, selection/apply, сохранение, instructions |
| `control-center/core.js` | Валидация, миграция отсутствующих полей, profiles, derived configs |
| `control-center/warlords-editor.js` | Индекс, curated цены/роли, defaults, validation, commanders, preset и зависимости |
| `control-center/server.js` | Loopback API/session, game guard, генерация/упаковка/launch job |
| `control-center/launch.ps1` | Реальная completion-проверка, backup/install, известные мосты, Steam-клиент |
| `control-center/start.ps1` | Запуск/повторное использование панели, Edge app-window |
| `control-center/data/profiles.json` | Пользовательские nodes/selected/presets и частные ключи; не заменять тестовой фикстурой |
| `control-center/data/runtime/` | Производные конфиги, launch-request, миссии; не авторский источник |
| `control-center/logs/` | Панель, помощник, мост |
| `bridge/neroai3.config.json` | Базовый конфиг; приложение создаёт копию |
| `bridge/lm-studio.js` | Payload/schema, instructions, single/dual, strategy cache |
| `bridge/system-prompt.js`, `bridge/warlords-doctrine.js` | Контракт и общая доктрина модели |
| `bridge/protocol.js`, `bridge/server.js` | Allowlist, validation, grounding, INIDBI |
| `addons/NeroAI3/config.cpp` | requiredAddons/CfgRemoteExec, PBO prefix NeroWL |
| `addons/NeroAI3/functions/CfgFunctions.hpp` | Регистрация функций и ранний native FSM path |
| `functions/core/fn_dispatchResponse.sqf` | Проверка пришедших действий; внутри addons/NeroAI3 |
| `functions/core/fn_executeMacro.sqf` | Последняя проверка, player priority, logistics lock, действия |
| `functions/core/fn_buildSnapshot.sqf` | Снимок группы, army/role/logistics/shop/support/цели |
| `functions/tactical/fn_purchaseAsset.sqf` | Пехота/наземная техника по CP и native airdrop |
| `functions/tactical/fn_purchaseAirAsset.sqf` | CP, class, H/A, runway, crew/owner/air role |
| `functions/tactical/fn_assignDefaultRole.sqf` | Стартовые роли противника; LLM может переназначать |
| `functions/tactical/fn_nativeGroundPurchaseAllowed.sqf` | Защита авиационного бюджета в native FSM |
| `functions/tactical/fn_autoRequisition.sqf` | Своя техника/посадка прежде новой покупки, role/CP |
| `functions/tactical/fn_vehicleTactics.sqf`, `fn_vehicleRoute.sqf` | Реальная посадка, MOVE/DISEMBARK, рельеф |
| `functions/tactical/fn_autoAirTask.sqf` | Редкий обзор парка, native objective/известные контакты |
| `functions/tactical/fn_dispatchAir.sqf` | ПВО/база/кулдаун и путь воздушной задачи |
| `functions/tactical/fn_paidAirSortie.sqf` | RECON/CAS/INTERCEPT/ESCORT и RTB |
| `functions/tactical/fn_airTransport.sqf` | Вертолёт, посадка/перелёт/высадка/RTB |
| `tools/scan-mod-assets.js` | Read-only индекс установленных PBO |
| `tools/read-pbo-entry.js`, `tools/read-world-config.js` | PBO/RAP; scalar type 6 int64 |
| `tools/build-australia-mission.js` | Общий генератор миссии по layout/editor/settings |
| `tools/build-criteria-missions.js` | Четыре независимые миссии из исследованных архивов |
| `tools/australia-layout.js`, `dist/*.layout.json` | География/связи; RHS20 layout — ввод основной Australia |
| `tools/mission-assets/` | Авторские Params/spawn/readiness/catalog templates |
| `research/native/`, `research/worlds/`, `research/user-archives/` | Прочитанные нативные функции, карта, архивы |
| `missions/` | Производные исходники: ручные изменения затрутся генератором |
| `dist/mod-assets.json` | Индекс config; не доказательство loaded config игры |
| `dist/warlords-editor-settings.json` | Производный ввод: army + commanders |
| `dist/launcher-mission-settings.json` | Defaults лобби + NeroWL_Dev |
| `dist/candidate/NeroWL.pbo` | Кандидат, сопоставлять с source перед установкой |
| `dist/criteria-release/` | PBO/source packages/ZIP четырёх карт |
| `dist/combined-arms-install.json` | Последняя установка, backup/hash |
| `CURRENT_STATUS.md` | История состояния; дополнять новой записью |

## 4. Запуск, preset и границы редактора

Рабочий стол: `NeroAI Control Center.lnk`. Панель `http://127.0.0.1:18775/`; fallback до 18785, реальный порт в data/session.json.
Preset **Australia · Mac · 16 · авиация**: одна openai/gpt-oss-20b на Mac, donko, temperature 0.9/maxTokens 900, 16 мест/сторона, 9 подчинённых, FT игроки+боты, airLimit 5, ACE/Dev. Остальные параметры читать из preset, не угадывать по названию.

Порядок: закрытая Arma → применить preset → проверить модели → написать instructions/выбрать технику → сохранить → «Обновить мод и запустить Arma» → «Мультиплеер → Создать сервер → Australia» → **NeroAI Warlords - Australia (Mac RHS 16v16)** → включить AI → синее место → ОК. PBO-файл сохраняет RHS20 в имени ради пути; это не число слотов. Остальные карты: NeroAI Warlords RHS + Zeus - <карта>.

Фракции выбираются внутри их нативной стороны: WEST=1/EAST=0. Перенос между сторонами требует отдельного адаптера/экипировки. Индекс сканирует 18 поддерживаемых модов по wanted regex, не весь Workshop. 5354 публичных записи, 57 фракций, config evidence; наследование и вместимость повторно проверять в игре.
Новые instructions применяются к Warlords. Antistasi bridge в этой работе не изменён. UI скрывает редактор при Antistasi.
Меню обычно удержание I, Zeus Y, console Esc; ACE/CBA → Настройки дополнений → Клиент/Сервер/Миссия. Зависит от раскладки/прав хоста.

## 5. Редактирование приложения

### Новый параметр

1. Lobby: tools/mission-assets/params.hpp, values/texts одинаковой длины, допустимый default.
2. Нативное имя проверить по research/native/Warlords/fn_WLInit.sqf. Авторскую серверную настройку применять в fn_applySettings.sqf с диапазоном/allowlist и publicVariable при необходимости.
3. core.validate: тип, диапазон, миграция старого preset. Браузерные min/max недостаточны.
4. index.html: label, selection, apply, сценарная видимость. Poll не должен затирать несохранённый ввод.
5. prepareAndLaunch: только проверенные значения, правильный владелец настройки — mission/bridge/launch. Не показывать «применено в игре» после JSON-save.
6. Тест преобразования и отказа неверного значения; UI сохранить/загрузить preset.

### Инструкции/модели

selected.instructions → core.makeConfig → preGameInstructions → lm-studio.buildMessages, отдельное user-message после постоянного system contract. Dual strategy также получает bounded инструкции и общую доктрину. system-prompt меняет тактический контракт; warlords-doctrine используется обеими моделями.
Single: один запрос на план группы. Dual: primary strategy, secondary tactical; intent до 500 символов/cache 120 секунд/snapshot до 7400 символов. maxPending/maxConcurrent 1. Не добавлять запросы каждому солдату/пилоту и полный каталог в контекст.
JS bridge требует перезапуска именно его процесса; HTML reload, core/server — restart панели. start.ps1 переиспользует сервер: повторное открытие ярлыка не обновляет загруженный core.

### API

GET / выдаёт страницу с token. Остальные API требуют X-Nero-Session, Host/Origin, loopback.
GET /api/state: nodes без ключей, selected/presets/params/job/running/addon hash match.
GET /api/catalog: индекс классов/модов/цен/ролей.
POST /api/save: {selected,name?}; /api/nodes: узел; /api/check: {id}; /api/launch: {selected}, асинхронная job.
models API лишь объявляет модели; helper требует настоящую completion. Это ещё не игровое управление. Body limit 32768 байт; при расширении проверить размер.

## 6. Добавление техники/цен/модов

1. Найти установленный мод, не угадывать classname по торговому названию.
2. При необходимости добавить provider в wanted regex scanner. `node tools/scan-mod-assets.js` пишет только индекс проекта.
3. Проверить errors/scope 2/side/kind/faction/cargo/isUav/modPath. Если base parent не прочитан, добавить нужный vanilla PBO в чтение, не выдумывать параметры.
4. curated в warlords-editor: [class,label,CP,role]. Положительная цена, classname только A-Za-z0-9_. Aircraft catalog roles: AIR_TRANSPORT/AIR_CAS/JET_CAS/JET_FIGHTER; это метаданные, не функции.
5. defaults включает существующие классы правильной стороны. Сохранённый старый preset автоматически не обязан расширяться: добавить через UI, сохранив прочие поля.
6. mods(army) собирает providers/известные requiredAddons. Base launch уже содержит CBA/RHS/CUP Weapons+Units+Vehicles+Terrains/карты/INIDBI/Zeus/ACE. Это не полный resolver всех Workshop-зависимостей: неизвестные проверить по mod info/новому RPT.
7. preset пишет CfgWLRequisitionPresets/NeroWL_RHSStart/WEST,EAST, H вертолётам/A самолётам. Цены UI/config должны совпадать.
8. NeroWL_customCatalog=1 отключает старую дозапись extendWarlordsShop/expandPreset, сохраняя выбор пользователя.
9. В игре проверить class/модель/экипаж/пилоны и actual services. scope 2 в файле недостаточен.

| Сторона | Техника | Class |
|---|---|---|
| WEST | F-35B | CUP_B_F35B_USMC |
| WEST | F-4E/F-16C/F-16D B52 | F4E_BLU / F16C_BLU / F16_B52_BLU |
| WEST | Abrams v1/v2/v3 | rhsusf_m1a2sep1wd_usarmy / rhsusf_m1a2sep2wd_usarmy / CUP_B_M1A2C_TUSK_II_Woodland_US_Army |
| WEST | Не vanilla Merkava | TT_Merkava_Mk4M |
| WEST | Challenger/Leopard 1/2A6 | CUP_B_Challenger2_Woodland_BAF / CUP_B_Leopard_1A3_GER / CUP_B_Leopard2A6_GER |
| WEST | Warrior | CUP_B_FV510_GB_W |
| EAST | Су-34/Су-35 | CUP_O_SU34_RU / JS_JC_SU35 |
| EAST | Т-80БВ/Т-72Б3 | rhs_t80bv / rhs_t72bd_tv |
| EAST | Т-90М/Т-14 | CUP_O_T90M_RU / rhs_t14_tv |

Т-74 названия были опечаткой, пользователь подтвердил Т-80БВ/Т-72Б3. Вместительный transport: RHS_CH_47F/CUP_O_Mi8AMT_RU; UH-60 с 8 cargo не перевезёт 9+командир. JET_CAS/FIGHTER не доказывает комплекта бомб/AT/AA: используется default class loadout, отдельного платного редактора пилонов нет.

## 7. Протокол и управление армией

Цепочка: schema → protocol.validateModelResponse → server grounding → INIDBI → dispatchResponse → executeMacro → SQF executor. Новый action менять на ВСЕХ этапах; пропуск воспроизводит отказ авиации.
ASSIGN_ROLE: support INFANTRY/MECHANIZED/ARMOR/RECON/AIR_TRANSPORT/AIR_CAS/AIR_SUPERIORITY, position пустая. Меняет текущую группу. Стартовая политика защищает CP до первого LLM-ответа, далее модель переназначает.
AIR_TASK: CAS/RECON/TRANSPORT/INTERCEPT/ESCORT, grounded position. Зарегистрирован также в server spatial set и protocol POSITION_ACTIONS.
BUY: INFANTRY/CAR/APC/TANK/TRUCK/HELICOPTER/PLANE/UAV. Модель не передаёт произвольный classname.
Snapshot army до 16 строк [callsign,role,alive,cp,ownedGroundCount], current role/logistics, компактный shop [kind,min,max]. Полный asset index в prompt не попадает.
roleUntil записывается +300 секунд, но автоматического истечения сейчас нет: роль сохраняется до следующего назначения. Не обещать гарантированный возврат по таймеру.
Цель BIS_WL_currentSector_<side> авторитетна. Не подменять ближайшим сектором. manageEnemyAI имеет cap армии/partisan ring, paid air crew исключён. Число slots не увеличивает LLM concurrency.
Army summary не является постоянным многоэтапным армейским планом с общим кошельком. Поочерёдная LLM координация по сводке реализована; persistent shared strategy stages — возможное дальнейшее развитие.

## 8. Логистика и авиация

Ground: native BIS_fnc_WLAirdrop, BIS_WL_groupVehs/itemOwner, funds/drop fee/reserve/pending. Малый танк не должен удалять лишнюю пехоту.
Board progress [vehicle,distance,lastProgressAt]; попытки при непосредственной посадке/долгом отсутствии прогресса. logisticsUntil блокирует автономные ADVANCE/ASSAULT/RETREAT/HOLD/CANCEL/DISEMBARK, прямой приказ приоритетен. vehicleTactics подтверждает vehicle unit и снимает lock. Проверять смерть/таймаут/новый приказ, чтобы lock не зависал.
Air: catalog bucket/class/side/scope, собственный H/A-sector, CP+fee+reserve, до 5 living aircraft стороны. Jet требует real ILS/SecondaryAirports около своего сектора. Unsheduled payment/create/refund, реальный crew отдельной группы до 4, owner AI-warlord. Jet доставляется FLY и сначала садится — потенциальное слабое место конкретных карт/модов.
States LANDING → PARKED → SORTIE/TRANSPORT → RTB → PARKED/UNAVAILABLE. autoAirTask возвращает фактически приземлившийся здоровый UNAVAILABLE, не ремонтирует/заправляет.
CAS подбирает strike catalog role; superiority JET_FIGHTER; transport capacity ≥live squad. paidAirSortie bounded RECON/CAS/ESCORT/INTERCEPT then RTB. ESCORT — patrol заданной точки, не formation follow движущегося вертолёта. INTERCEPT только observed live Air contact, doTarget/native combat; уничтожение не гарантировано.
Transport: только AI-пешая группа, цель >2500 м, paid helicopter/seats/ровные pickup+LZ, известное ПВО отменяет. assignAsCargo/orderGetIn, подтверждение, физический полёт/высадка. Нативный AICore/FT не переписан и может конфликтовать: обязательно проверить. Не лечить удалением всех ground waypoints/телепортацией.
Review ≤раз в 30 секунд на группу, purchase/sortie cooldown. Ammo/fuel конечны; ремонт/перезарядка отдельными правилами сценария.

## 9. География/генерация/архивы

Править layouts/templates/generator, затем пересоздавать missions. Border=200 SCALAR, не BOOL — прежний BOOL ломал HUD/markers. Module side: 0 neutral/1 EAST/2 WEST, не CfgVehicles side. PositionInfo [x,height,y], getPosATL [x,y,z].
Sync graph соединяет базы через sectors; IDs уникальны, maxPlayers=count*2 в обоих headers, disabledAI=0/playable flags. AI toggle также вручную в лобби.
Slots менять вместе core/UI/generator/validator/manifest/tests. Сейчас 32 slots/46 entities основной Australia. Spawn near airfields через prepareBase/placeCommander/findOpenGround, только старт/respawn, не battle rescue.
Оригиналы Downloads/WL_RHS_Zeus_*.zip; распаковки research/user-archives. build-criteria делает независимые native missions, package-criteria обновляет release PBO/source/ZIP/manifest. Не менять архивы пользователя.

## 10. Сборка и проверки

PowerShell 7, Node ≥20. Сначала проверить editor/settings JSON: генератор использует saved defaults, не только шаблон. Если их нет — legacy 10v10/minimal preset. Выполнять стадии последовательно и проверять каждый exit code.

```powershell
Set-Location -LiteralPath 'C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM'
node --check control-center/core.js
node --check control-center/server.js
node --check control-center/warlords-editor.js
node --check bridge/lm-studio.js
node --check bridge/protocol.js
node --check bridge/server.js
node tools/build-australia-mission.js dist/australia-rhs20.layout.json
node tools/build-criteria-missions.js
node tools/validate-mission.js missions/NeroAI_Warlords_Australia_RHS20.australia
node --test tests/warlords-editor.test.js tests/mission-generation.test.js tests/warlords-dual.test.js control-center/core.test.js
node --test --test-name-pattern='T25 F1|delimiters|dynamic SQF|backslash' tests/static-sqf.test.js tests/command.test.js
./tools/pack-pbo.ps1 -OutputDir dist/candidate
node tools/verify-pbo.js dist/candidate/NeroWL.pbo addons/NeroAI3 NeroWL
./tools/pack-pbo.ps1 -SourceDir missions/NeroAI_Warlords_Australia_RHS20.australia -OutputDir dist -OutputPbo NeroAI_Warlords_Australia_RHS20.australia.pbo -Mission
node tools/verify-pbo.js dist/NeroAI_Warlords_Australia_RHS20.australia.pbo missions/NeroAI_Warlords_Australia_RHS20.australia --mission
./tools/package-criteria.ps1
```

Полный обзор отдельно node --test tests/*.test.js, сохранить ошибки. npm test запускает только dual tests. verify-pbo сверяет full manifest/bytes. Генерация миссий также пересоздаёт addon native FSM: упаковывать addon ПОСЛЕ неё.
FSM подключается ранним CfgFunctions/A3_Warlords/Warlords/WLAIPurchases.file; не присваивать final-функции после старта.

## 11. Установка/restart/rollback

Штатно кнопка приложения после закрытия Arma. prepareAndLaunch: models → derived configs/settings → generate/verify/pack. Helper: real completion → verify candidate/source → backup/copy/hashes → остановить только известные bridge paths → новый мост → Steam -applaunch 107410 -noLauncher -useBE -name=donko. Отдельный server/HC не запускается.
После ошибки читать file-backed launch-helper.log; Steam не должен держать job running наследуемой stdout pipe. Ручная установка должна сохранять тот же game-close/backup/hash gate.
Panel restart: session.json PID → проверить Win32_Process CommandLine control-center/server.js → завершить только этот PID → Start-Process node server.js скрыто. Не Stop-Process -Name node.
Rollback: закрытая Arma → остановить только известный мост → прочитать install manifest → сохранить новый набор → вернуть addon/затронутые mission PBO из named backup → согласованный предыдущий bridge/source/config из своего snapshot → hashes → свежий запуск. Старый PBO+новый протокол не полный rollback.
Нынешний named backup сохраняет установленные PBO, НЕ полную копию старого source/bridge. Не заявлять обратное; перед будущими изменениями сделать полный source snapshot.

## 12. Игровая приёмка

1. Свежая command line: NeroWL/HAFM/TT/CUP/RHS/карта, без случайного старого DCO/Antistasi. Lobby 16 мест/side, AI on; после старта sectors/HUD/I/Y/debug/CBA tabs.
2. RPT configured=true для native purchase FSM, без final override/undefined/missing class/compilation.
3. Enemy role и aviation budget до первого LLM-плана, ASSIGN_ROLE реально меняет variable. Player order отменяет autonomous action корректно.
4. BUY AIR: class/price/CP-left → physical object/crew → PARKED → task → взлёт/бой → RTB. Лог или меню без фактического борта недостаточны.
5. Transport: места для всех → дошли/сели → перелёт/высадка/native objective. Повторить seats shortage/AA/pilot death/timeout/manual order/base loss. Проверить CP/owner/locks/cleanup.
6. Ground owned vehicle 400–1000 м: реально дошли/сели, пехота не удалена, LLM не разворачивает. Не бесконечная закупка idle units.
7. Fighter: known aircraft → intercept; lost target → прекращение/RTB. Escort патрулирует безопасно, не летит в защищённую базу.
8. Actual pylons/ammo HAFM/CUP/SU35, canFire, взлёт/посадка на каждой карте. Не обещать AT/бомбы по роли.
9. 30–60 минут: FPS/server diag_fps/RAM/groups/units/vehicles/air/request cadence, поздние покупки используются. 10v10 proof не является FPS proof 16v16.

Read-only debug, выполнять на сервере/хосте:

```sqf
diag_log format ["[NeroWL DEV ARMY] %1", (missionNamespace getVariable ["BIS_WL_allWarlords",[]]) apply {private _g=group _x; [name _x,side _g,_g getVariable ["NeroAI_callsign",groupId _g],_g getVariable ["NeroWL_role",""],_x getVariable ["BIS_WL_funds",0],count units _g,_g getVariable ["NeroWL_logisticsUntil",0]]}];
diag_log format ["[NeroWL DEV AIR] %1", (vehicles select {_x getVariable ["NeroWL_paidAir",false]}) apply {[typeOf _x,alive _x,count crew _x,_x getVariable ["NeroAI_assetRole",""],_x getVariable ["NeroAI_airState",""],fuel _x,damage _x,_x getVariable ["BIS_WL_itemOwner",objNull],getPosATL _x]}];
diag_log format ["[NeroWL DEV LOAD] fps=%1 units=%2 groups=%3 vehicles=%4",diag_fps,count allUnits,count allGroups,count vehicles];
```

RPT C:\Users\Admin\AppData\Local\Arma 3\Arma3_x64_*.rpt, выбирать свежий по времени/command line. Исследованный Arma3_x64_2026-10-05_20-26-59.rpt относится к прежней игре. Bridge logs control-center/logs; standalone может писать свой журнал. Queue path читать из actual config, не угадывать/не удалять.

## 13. Следующий шаг агента

Получить новый RPT и наблюдение пользователя, hashes/launch line. Воспроизвести один отказ небольшой миссией. Приоритет: native AICore/FT против transport, HAFM/TT dependencies, cargo inheritance, actual missiles/loadout, warlord death ownership, landing/locks timeout, bounded snapshot.
Исправлять конкретный executor вместе с протоколом, не усиливать prompt наугад. После принятия обновлять CURRENT_STATUS, manifest, этот guide/README. Разделять написано/JS-tested/packed/installed/engine-accepted.

## 14. Первичные источники

- [Warlords и requisition presets](https://community.bistudio.com/wiki/Arma_3_MP_Warlords).
- [assignAsCargo](https://community.bohemia.net/wiki/assignAsCargo).
- [AI vehicle management](https://community.bistudio.com/wiki/AI_Group_Vehicle_Management).
- [CfgFunctions](https://community.bistudio.com/wiki/Arma_3_CfgFunctions).

Опора также research/native именно установленной игры. Документация не заменяет проверку locality/модовой техники/миссии.

## 15. Исторический снимок установки от 5 октября

- Addon SHA256: `78EB1A53CCAF6371BA53D27461C96B9974753BF043BDCABF5AA1C4908AE0E343`.
- Main mission SHA256: `03029F63AE44DFAA6682E82ACE80A75262D7C37C61C28F5ABDD03856D5ED629D`.
- Backup: `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM\backups\combined-arms-20261005-224935`.
- Install manifest: dist/combined-arms-install.json; verify: dist/addon-verification.json, dist/main-verification.json.
- Новое поведение не принято в игре. Полный legacy suite не зелёный.


## 16. Гарнизоны, союзники, каталог и журнал — 6 октября 2026

### Текущая установка и границы проверки

- Addon SHA256: `376F5DB64A66EB1C2E162ADF8FB6A1F42B830762C7442099D9481CFB17B8D476`, 75 файлов, 393071 байт.
- Main Australia SHA256: `6737976A528CD6B69DB0A284735C14C52B69F96F25B9C8A8CEC9225456CCBCCE`.
- Запись установки: `dist/city-controls-install.json`; резервная копия: `backups/city-controls-20261006-001706`.
- Обновлены основная Australia и четыре миссии `dist/criteria-release` (Australia, Takistan, Altis, Chernarus), а также производные ZIP. Исходные пользовательские ZIP не изменены.
- Установка выполнена после закрытия Arma, без запуска игры. Текущий старый процесс моста получает новые поля журналирования только после следующего запуска через приложение.
- 28 целевых тестов и 4 выбранные статические проверки прошли. Результаты: `dist/current-test-results.txt`, `dist/current-static-results.txt`. Последний полный исторический прогон имел 20 ошибок; он не доказывает текущую исправность всего legacy suite.

### Раздельные лимиты городских гарнизонов

Источник параметров: `tools/mission-assets/params.hpp`, применение: `addons/NeroAI3/functions/fn_applySettings.sqf`. Идентификаторы `NeroWL_WestGarrison`, `NeroWL_EastGarrison`, `NeroWL_GreenGarrison`; допустимы -1 (штатный), 0, 6, 12, 18, 24, 36, 60.

`tools/adapt-garrison.js` адаптирует установленный native `research/native/Warlords/fn_WLSectorPopulate.sqf` с проверкой обязательных опорных фрагментов. Результат `addons/NeroAI3/functions/native/fn_WLSectorPopulate.sqf` подключён через CfgFunctions до финализации штатных функций. Генератор основной миссии вызывает адаптацию: упаковывать addon после генерации.

Переменная `NeroWL_garrisonCaps` имеет порядок EAST, WEST, resistance. Лимит относится к NPC одного штатного формирования гарнизона сектора, включая экипажи. Он ограничивает создание, не увеличивает штатный гарнизон до выбранного числа. Машина, чей экипаж не помещается, не остаётся пустым неоплаченным объектом; последний пехотный отряд сокращается до оставшегося бюджета. При ограничении GREEN отключено штатное подкрепление этого гарнизона, обходящее лимит. -1 сохраняет нативное поведение.

Это НЕ общий предел всех находящихся в городе солдат: армии командиров, подкрепления других систем, игроки и атакующие отряды не удаляются. Уже созданные гарнизоны не сокращаются сохранением пресета; проверять в новой миссии. Не добавлять регулярную очистку allUnits: она разрушит владение, экономику, отряды игрока и сценарий.

### Союзные AI-отряды и отдельная модель

`NeroWL_FriendlyLLM`: 0 выключено, 1 ручное подключение через NeroAI, 2 автоматическое. `NeroWL_FriendlyLimit`: 1/2/4/8/12/16, по умолчанию 4. Союзники здесь — AI-отряды стороны игрока. Группа игрока и группы с живыми игроками исключены; ручной отказ от управления сохраняет приоритет. Автоматический менеджер вызывается не чаще одного раза в 8 секунд. Изменены `fn_registerGroup`, `fn_serverLoop`, `fn_assignDefaultRole`, `fn_nativeGroundPurchaseAllowed`.

В приложении `allyRoute` shared/separate. Shared использует основную модель, отдельный маршрут выбирает `allyNode` и `allyModel`. Генерируется только для Warlords как `lmStudio.sides.ALLIED`; shared удаляет старый отдельный маршрут. `control-center/core.js` проверяет узел, имя модели и настройки, сервер проверяет наличие модели, `tools/check-brains.js` делает настоящий пробный ответ союзной модели. Не менять этим главный маршрут противника. Контроль количества подключённых групп отделён от количества слотов и подчинённых.

### Полный редактор доступной техники

`tools/scan-mod-assets.js` теперь читает все установленные Workshop-моды с addons: текущий снимок 105 модов, 7181 записей, 67 фракций, 0 ошибок разбора. Учитываются публичные классы scope=2 и нативная сторона. Это статический каталог конфигураций: не обещать исправность модели, вооружения и зависимостей без запуска в движке.

В `control-center/warlords-editor.js` техника разделена на наземную, авиацию, статические установки и корабли. Infantry служит выбору фракций. Корабли требуют нативный сервис W (порт), поэтому не каждая городская точка допускает их покупку. WEST/EAST не перекрашиваются под произвольную сторону. Совместимые патчи без собственной публичной карточки не подменяют исходный мод-поставщик.

В UI поиск, фильтры типа/мода, по 60 записей на страницу и сохранение флажков между страницами. До 512 выбранных классов на сторону. Все моды каталога не включаются автоматически: к базовому набору добавляются поставщики выбранных классов и зависимости. Предельный размер тела запроса приложения поднят до 131072 байт. Не заменять каталог выдуманными classnames; обновлять скан и проверять сторону/поставщика.

### Журнал LLM и отдельная консоль

Файлы: `control-center/journal.js`, `journal-cli.js`, `log-console.ps1`, `open-console.ps1`; API GET `/api/journal`, POST `/api/console` под существующей loopback/token-защитой. На рабочем столе `NeroAI-LLM-console.cmd`, вызывающий `Start-NeroAI-Log.ps1`. Окно показывает дописываемые строки моста и NeroWL/NeroAI/ошибки свежего RPT; Ctrl+C останавливает только просмотр.

Чтение ограничено хвостом 128 KiB, выводом до 180 строк моста и 100 строк движка, без полной загрузки многочасовых логов. Скрываются Bearer и известные ключи узлов. Не печатать session.json/API-ключи; исходный bridge log содержит игровые данные и пользовательские инструкции.

Новый `bridge/server.js` пишет принятую сводку игры (до 900 символов), итоговый JSON LLM (до 10000), время ответа, разрешённые команды и результат передачи. Это поле итогового ответа, не внутренние рассуждения модели. Отправленный приказ, подтверждение SQF и фактический взлёт/посадка/покупка — разные доказательства. История старого процесса не содержит новых полей до его перезапуска.

### Zeus

`fn_warlordsMissionSetup.sqf` регистрирует существующие объекты сценария и новые EntityCreated, включает зарегистрированные addon-классы, снимает области ограничения редактирования/камеры, обнуляет стоимость действий и waypoint. Logic не регистрируется как обычный редактируемый объект. Существующий периодический реестр units/vehicles остаётся.

Установленный Zeus Enhanced присутствовал в свежем RPT: zen_attributes.pbo и zen_pylons.pbo. Редактирование навыков/атрибутов и динамических пилонов использует ZEN; набор пилонов зависит от поддержки конкретного самолёта. Встроенные неподвижные объекты карты не обещаны как обычные объекты сценария. Начальное назначение навыка выполняется один раз; ручную проверку сохранения навыка проводить после начальной настройки миссии. Первичные ссылки: https://community.bistudio.com/wiki/Curator и https://community.bistudio.com/wiki/addCuratorEditableObjects .

### Проверка после следующих правок

```powershell
node --test tests/control-options.test.js tests/warlords-editor.test.js tests/mission-generation.test.js tests/warlords-dual.test.js control-center/core.test.js
node --test --test-name-pattern='T25 F1|delimiters|dynamic SQF|backslash' tests/static-sqf.test.js tests/command.test.js
```

Далее генерация основной и четырёх миссий, упаковка addon, verify-pbo по разделу 10. Перед установкой проверить отсутствие Arma/launcher; резервировать реально установленный addon и миссии. Не закрывать чужую игру без авторизации и не путать приложение, мост и Arma. Сверять installed hash и актуальный launch line.

Следующая игровая приёмка: новая миссия с небольшими разными лимитами WEST/EAST/GREEN; фактический подсчёт защитников и экипажей при захвате/повторной активации; ручное/автоматическое подключение союзников и сохранение управления группой игрока; реальный ответ отдельной модели; новая покупка появляется в Zeus, изменение навыка и пилонов поддерживаемого самолёта; сопоставление приказа в консоли с действием в игре; загрузка CPU/RAM/FPS. Также остаётся приёмка авиации из раздела 12. До этого статус — написано, протестировано JS/статически, упаковано и установлено; не engine-accepted.

## 17. Задержка подготовки на карте — 6 октября, 00:30–00:34

Свежий RPT `C:\Users\Admin\AppData\Local\Arma 3\Arma3_x64_2026-10-06_00-26-34.rpt`: миссия RHS20 стартовала 00:30:01; readiness elapsed=0 в 00:30:18, sectors=0 до elapsed=182; elapsed=213 sectors=13 bases=true/true; READY elapsed=217 clientMarkers=RECTANGLE. EAST=10/WEST=9 AI, 20 commanders total. Это наблюдаемая длительная инициализация, не отказ загрузки. Новые лимиты в этой сессии штатные [-1,-1,-1], friendlyMode=1.

Подготовлена кандидатная оптимизация: `tools/adapt-vars-init.js` ограничивает нативный WLVarsInit.isUniformAllowed классами публичной униформы (ItemInfo.type=801, непустой uniformClass), вместо всех CfgWeapons; оригинальная функция сохраняется с диагностикой этапов. Предупреждения оружия CUP/HAFM и параллельная подготовка каталога Zeus совпали с задержкой. Их точный вклад по времени не измерен. Создание Zeus отложено до наличия секторов и баз. Генератор пересоздаёт эту адаптацию перед упаковкой.

В оригинальном WLVarsInit есть compile доверенных mission-config preset/group paths. Статический тест допускает только точное совпадение этого файла с ограниченной адаптацией оригинала; остальные файлы по-прежнему запрещают динамическое исполнение. Проверки: 13 целевых и 4 статических прошли; PBO verify passed. Кандидат SHA256 `DD4D3B540E29BB04DD5E048DF3F70CAC368AD9542E71CEDF2C3FBBB4127FB94B`, 76 файлов, 411584 байта. Сохранён `dist/candidate/NeroWL.pbo`, результат `dist/init-delay-verification.json`.

Кандидат ещё НЕ установлен в запущенную Arma. Следующий запуск через приложение проверит и установит его с существующей процедурой резервирования. Нужна новая RPT-приёмка времени до READY и сохранения HUD/покупок/Zeus. Улучшение времени пока не измерено. Не перезапускать текущую игру ради кандидата без запроса пользователя.

## 18. Выделение в Zeus работает, свойства не открываются

Пользователь подтвердил: NPC/техника выделяются, но двойной щелчок не открывает свойства. Installed ZEN module source `research/zen-moduleCurator.sqf` регистрирует отдельные локальные CuratorObject/Group/Waypoint/MarkerDoubleClicked handlers, вызывающие BIS_fnc_showCuratorAttributes. Наша ручная динамическая регистрация объектов сама эти обработчики не добавляла. Точное отсутствие native handler в живом curator ещё не измерено; исправление закрывает этот путь отказа.

В `fn_warlordsMissionSetup` добавлена разовая настройка реально назначенного host curator, включая альтернативный уже назначенный mission curator. Существующие обработчики ZEN не удаляются; `!dialog` предотвращает повторное создание уже открытого окна. Разрешены %ALL атрибуты объектов/групп/waypoints/markers; навыки игроков специально не разрешались. Есть журнал готовности и результата открытия. Hotfix для выполнения ЛОКАЛЬНО в текущем host: `tools/zeus-attributes-hotfix.sqf`, не исполняется агентом через LLM/INIDBI2.

Кандидат включает предыдущую оптимизацию подготовки: SHA256 `17768929D6DFEF1D58F06587DBF8AF7E7E3247589A2C65AED62C980D1558D047`, 76 файлов, 413284 байта. 13 целевых и 4 статических проверки прошли; `dist/zeus-attributes-verification.json` matches source. Пока игра открыта — не установлен. Следующий запуск через приложение установит кандидат. Игровая приёмка: двойной щелчок по неигровому NPC и пустой/занятой машине → ровно одно окно; применённый навык сохраняется; поддерживаемые пилоны ZEN работают; после respawn активный curator всё ещё настроен. При отказе читать `[NeroWL Zeus]`, тип объекта, curatorInfoType и BIS_fnc_curatorAttributes, не считать один hash доказательством.

## 19. Установленные исправления сессии — 6 октября 01:00 Europe/Kiev

ЭТО ТЕКУЩИЙ снимок установки, заменяющий статусы «кандидат не установлен» разделов 17–18. Пользователь закрыл игру и поручил работать над исправлениями. Проверено отсутствие Arma/launcher/BattlEye, после этого установлен addon и пять миссий; runtime/missions синхронизирован для следующего запуска центра. Игра не запускалась.

Addon SHA256 `331731DC85D7BE502987D3555CC26A71ED62AA2256883F0E0D79D40AC5811C80`, 79 файлов, 423478 байт. Main mission SHA256 `EF08FB9F11E41BCF840A51124C65093565ADA0A6B5E75855B4933F28ECCFECB8`. Полный manifest `dist/session-fixes-install.json`; installed/source verify `dist/session-fixes-installed-verification.json`. Backup `backups/session-fixes-20261006-010007`. Кандидат и dist/NeroWL.pbo совпадают с установленным. 31 целевой тест + 4 статических проходят; полного нового legacy прогона нет.

### Подтверждённая причина Су-35

Read-only диагностика пользователя 00:51:08/13: JS_JC_SU35 pos [226.786,-315.523,3836.42], затем [-36.5679,-106.037,3868.72], speed ~264, state UNAVAILABLE, airport=2, home=[24888.6,13053.1,0], MOVE waypoint [0,0]. Нет подтверждённой задачи AIR_TASK для этого Су-35. Покупка создаёт борт в воздухе и требует посадки; timeout раньше делал его UNAVAILABLE без маршрута восстановления. Начальная точка crew-group в углу карты оставалась. Это фактический отказ, не стратегическое решение LLM.

Новый `core/fn_groundAssetKind.sqf` зарегистрирован в CfgFunctions. Новый `tactical/fn_recoverAirLanding.sqf` работает только на сервере, локальном живом оплачиваемом самолёте и его отдельной AI crew-group; исключает игроков/экипаж с игроком, слабое топливо, повреждения, invalid home/outside world. Не телепортирует, не добавляет топлива/патронов/CP. Удаляет только air-group WPs, отменяет failed landing и задаёт LOITER радиус800 около проверенного home. READY означает пригодный к задаче самолёт в воздухе, а не посаженный.

`fn_purchaseAirAsset`: убрана нулевая WP, перед первоначальной посадкой MOVE на home; timeout300s проверяет также speed<5, затем вызывает восстановление. `fn_paidAirSortie`: принимает PARKED/READY, не подставляет аэропорт0 при missing airport, вызывает восстановление после failed RTB. `fn_autoAirTask`: owned UNAVAILABLE plane review не чаще30с, READY допускается; fn_buildSnapshot считает READY готовым. Транспортная посадка остаётся только PARKED: самолёт в воздухе не считается транспортом с готовой погрузкой.

Первичная landing совместимость Australia airport2/JS_JC_SU35 по-прежнему не измерена после правки; исправлен аварийный путь и нулевая WP, а не заявлена исправность всех runway-конфигураций. Пять минут initial landing grace остаются. READY держится на реальном топливе; низкое топливо/повреждения не «чинятся» этим watchdog.

### Другие исправления из аудита

- `fn_autoAirTask` при native цели в protected enemy-base bubble выбирает другой известный сектор вне этой зоны: сначала не своей стороны, затем ближайший; использует только публичные native sector objects. Не сканирует скрытые врагу юниты. Защита базы/известного AA сохраняется. LLM явно выбранная запрещённая цель по-прежнему отклоняется.
- `fn_groundAssetKind` используется в purchaseAsset, factionAssets, shop/assets snapshot. Tracked APC/cargo/known BMP/BMD/Bradley/Warrior/MTLB отличает от MBT, традиционные MBT-маркеры сохраняет. Из generic tank/APC автопокупки исключены известные SPAA/артиллерийские chassis. Это эвристика по конфигурации/именам, не полный идеальный классификатор всех Workshop. Дополнять проверенными классами при новых модах. Скан каталога дополнен T-80 и известными IFV markers; 105mods/7181assets/0errors. Тестируются установленные BMP2/Bradley/APC и T80/T72/T14/TANK.
- `fn_vehicleTactics` сбрасывает autoBoardTries только после полного MOUNTED, не после каждой частичной посадки; невошедшие живые бойцы освобождаются от устаревшей seat assignment. Native orders/группа сохраняются. Это устраняет известный бесконечный сброс попыток, но не доказывает решение всех seat/path/locality конфликтов.
- `bridge/system-prompt.js` явно объясняет SET_SECTOR=наблюдать/doWatch, а не выбрать/захватить/двигаться. ADVANCE/ASSAULT нужны для манёвра. Запрещает выдавать роль/покупку за доказанный вылет. Не конвертировать любой SET_SECTOR в движение: это сломает приказы игрока на наблюдение. Реальное следование модели проверить следующими планами. Старый процесс моста получает новый prompt после перезапуска через приложение.
- `tools/adapt-purchase-availability.js` с проверкой native anchors генерирует WLSubroutine_purchaseMenuAssetAvailability. `_category` локально читается из `_assetDetails param [5,"",[""]]`; неизвестная/неполная категория не допускается к покупке, выдаёт понятный tooltip. CP/DLC/сервисы/лимиты исходника сохранены. Это закрывает undefined _category из 49 повторов RPT, а не обещает исправление всех сторонних форматировщиков меню.
- Также установлены оптимизация WLVarsInit и разовые Zeus attribute double-click handlers из разделов17–18. Hotfix пользователю повторять после нового запуска не требуется.

### Приёмка следующей сессии

1. Проверить launch line/hash и свежую RPT, сохранённый узел/модель пользователя (последняя сессия Bonsai27B, не старый GPT-OSS из начала чата). Не перезаписывать выбор узла.
2. READY native Warlords: измерить elapsed, сектора/HUD/покупки. Не заявлять ускорение без нового времени.
3. Zeus NPC/пустая и занятая машина: двойной щелчок открывает ровно одно окно, изменения применяются. Pilons только у supporting aircraft. После respawn проверить назначение.
4. Су-35: initial landing route home≠[0,0], при failed landing `[NeroAI4] AIR landing recovery` и READY, waypoint около home, фактическое движение обратно к аэродрому; затем ESCORT/INTERCEPT только по известной цели. RTBtimeout проверять отдельно. No fuel/ammo reset, player crew excluded.
5. AIR AUTO при protected enemyHQ меняет цель на sector вне1400м, не спамит прежний отказ; grounded CAS/known AA guard сохранены.
6. BUY TANK→MBT, BUY APC→BMP/Bradley, цена реально списана; меню без undefined _category.
7. Частичная посадка не сбрасывает tries; после ограниченного числа попыток автоцикл отдаёт управление обычному native продвижению; no teleport/delete infantry.
8. Планы LLM содержат реальное ADVANCE/ASSAULT при подходящей обстановке, речь не выдаётся за фактический вылет. Контекст/FPS/CPU/RAM измерить отдельно; стратегия и воздушный бой не приняты одной сборкой.

Отчёт до правок: docs/RUNTIME_BEHAVIOR_20261006_RU.md. Артефакты этой проверки: dist/session-fixes-*.json/.txt. Возврат файлов: копировать PBO из указанной backup только при закрытой игре; откат prompt делается отдельно в bridge/system-prompt.js. Не откатывать выбранную модель/сохранения/очереди INIDBI2 вместе с addon.


## 20. Каталог по модам и названия машин

6 октября обновлён только интерфейс/данные приложения; игровой PBO остаётся из раздела19. `control-center/index.html`: отдельные раскрываемые моды внутри WEST/EAST, независимые страницы по60 в каждом моде, поиск открывает совпадения, выбор хранится по classname и не зависит от подписи. Строки техники показывают только label; classnames, цены и mod убраны из строк. Технический classname сохраняется в модели данных для build/покупки и в поиске. Категории переведены на русский; фильтр модов показывает только моды с техникой WEST/EAST. Пехота не добавлена в этот список.

`tools/resolve-asset-names.js` читает root stringtable.xml из установленных PBO (не исполняет содержимое). Индекс `dist/asset-names.json`: 406 таблиц, 56570 ключей. В выборке3642 техники WEST/EAST удалось восстановить1831 локализованное имя; у315 отсутствует разрешимое название или исходное название совпадает с ID — используется читаемое обозначение из classname. Не выдавать их за подтверждённые официальные названия. `control-center/asset-names.js` разрешает Russian→English→Original через индекс; curated overrides имеют приоритет. Сохранение classname исключает путаницу одинаковых отображаемых названий разных модов.

Обновление после установки новых модов: node tools/scan-mod-assets.js, затем node tools/resolve-asset-names.js; перезапустить только центр запуска, не Arma/мост. Тесты конфигурации/каталога16pass, UI проверяется отдельно. Для конкретной неверной подписи добавить проверенный override; не менять classname/side/provider ради косметического имени. Каталог содержит варианты раскраски/вооружения, не схлопывать одинаковые подписи в один игровой класс.

Уточнение фильтра модов: equipmentModOptions в index.html формирует список только из actual WEST/EAST equipment categories (CAR/APC/TANK/HELICOPTER/PLANE/SHIP/STATIC), дополнительно по выбранной категории. Сейчас34 providers для всех категорий,16 для самолётов,22 для танков; карты/звуки/Zeus без оборудования в список не входят. Стационарное вооружение считается техникой, поэтому мод с реально добавленным миномётом/ПТРК остаётся. Полный105-mod dependency index сохранён отдельно от UI filter: не удалять зависимости при косметической фильтрации. UI проверен:16 plane providers и сохранённый выбор; категория возвращена на все. Скриншот docs/control-center-tech-mod-filter.png.

## 21. Редактор сценариев и трёхсторонний режим — 06.10.2026

Статус: приложение и генераторы изменены, кандидат собран; новые игровые пути ещё НЕ приняты в Arma. Старый установленный PBO не заменялся в этом проходе. Следующий запуск из панели устанавливает кандидат после проверки соответствия исходникам. Не выдавать проверки JavaScript/упаковки за успешную игру.

Ключевые файлы:
- `control-center/designer.html`: отдельное окно, масштаб/панорама, базы/цели/спавн, стартовая техника, гарнизоны, маршрут модели, роль наблюдателя.
- `control-center/scenario-design.js`: типизированная проверка; `data/designs/<world>.json` — сохранённые проекты. Не читать и не печатать API-ключи из profiles.json.
- `tools/scan-worlds.js`, `dist/worlds.json`: 22 карты. Проверяется присутствие WRP в установленных PBO. Australia/Takistan/Chernarus имеют резервные метаданные; размер необходимо сверить в движке.
- `tools/build-designed-mission.js`: Native/Three отдельные имена миссий; построение связного графа для native, CfgNeroDesign, моды с зависимостями.
- `tools/build-three-mission.js`, `tools/designer-assets/fn_cq*.sqf`: отдельная экономика/захват трёх сторон. Не использует ModuleWLInit_F. Это НЕ штатный трёхсторонний Warlords и не модификация его зелёных защитников через переименование.
- `fn_spawnDesignGarrison.sqf`, `fn_manageGarrisonLLM.sqf`: локальные реальные гарнизоны, лимиты, включение по атаке/выбору цели. Снимок содержит типизированный garrison=true; bridge/lm-studio.js выбирает маршрут модели и инструкцию. Общие менеджеры исключают эти группы.
- `tools/adapt-zone-restrictions.js`: точечные отключения штатного таймера только при NeroWL_useDesigner=1 и NeroWL_lethalZones=0. Обе native-функции зарегистрированы в CfgFunctions.
- `tools/designer-assets/fn_observer.sqf`: отдельный гражданский слот, остальные боевые слоты только AI; End Game Spectator и доступ к назначенному Зевсу. Для двух сторон сохраняется штатный Warlords, для трёх — CQ.
- `fn_exportMap.sqf`, `control-center/map-survey.js`: разовый экспорт высот 256×256, до 50 000 зданий/сегментов дорог через отдельный INIDBI2 файл NeroWL_map_<world>.ini. В игровом бою автоматически не запускается. Команда на сервере: `[] spawn NeroAI_fnc_exportMap;`, затем кнопка импорта в редакторе. Векторные здания/дороги чёткие при увеличении; рельеф дискретный. При достижении лимита карта помечается неполной. Изображение PNG/JPEG 256–8192 квадратных пикселей также импортируется отдельно; без экспорта/изображения фон является схемой. Реальный экспорт ещё не выполнен.

Использование: открыть редактор карты; поставить по одной базе активной стороны и хотя бы одну цель; сохранить; в главном окне выбрать ту же карту и «Использовать сценарий редактора». В режиме трёх сторон нужна третья база. Для LLM-vs-LLM выбрать роль наблюдателя: в лобби входить в Civilian — NeroAI Observer / Zeus. Зевс назначается хосту; доступ для внешних клиентов не подтверждён.

Инцидент запуска: JavaScript String.replace обработал последовательность `$'` в PowerShell-шаблоне как подстановку хвоста строки, из-за чего была оборвана проверка имени миссии и продублирован конец launch.ps1. Исправлено сборкой из срезов без replacement-подстановок. launch.ps1 проверен парсерами Windows PowerShell 5 и PowerShell 7 без исполнения запуска; добавлен тест. Для будущих правок текста с `$` применять callback replacement или конкатенацию. Не удалять очереди и не закрывать игровую сессию ради теста.

Проверки: 33 целевых теста прошли; четыре проверки безопасности/синтаксиса addon также прошли. Полный старый static/lm-studio набор имеет три ранее существовавших несоответствия ожиданий; не объявлять весь набор зелёным. Кандидат dist/candidate/NeroWL.pbo: 84 файла, 453052 байта, SHA256 0C6D9846EBF53655A306E37D5AAD275E8CE2312F19BD5409ACBA2BE82EA187BB. Есть резервная копия прежнего кандидата в backups/designer-candidate-*. Панель перезапущена, выбранные пользователем настройки не менялись.

Оставшиеся приёмочные проверки в движке: native-редактор с отключением таймера; спавны/сохранение CP после смерти; все три стороны покупают и физически применяют технику; зелёные в режиме обороны не ведут обычный наступательный маршрут; переключение наблюдатель↔Zeus; нет назначения AI человеку; реальный экспорт геометрии и совпадение координат карты; гарнизонная LLM получает именно свой снимок и удерживает свой сектор; авиация/экипажи/купленная техника не остаются без задач. UI-проверка через Computer Use остановлена, так как Firefox не поддержан механизмом проверки URL инструмента; не обходить это через другой способ UI-автоматизации в том же проходе.

## 22. Спутниковый фон из файлов Australia и исправление missionFiles — 06.10.2026

Этот раздел заменяет ограничение §21 о необходимости предварительного экспорта/ручного изображения для Australia. Реальный спутниковый фон уже создан из установленного australia.pbo БЕЗ запуска Arma. Остальные карты не объявлять обработанными.

Источник: `H:\SteamLibrary\steamapps\common\Arma 3\!Workshop\@Australia FIXED\addons\australia.pbo`. Прочитаны 1849 действительных `data/layers/S_xxx_yyy_lco.paa` и привязки Stage0/TexGen worldPos в соответствующих RVMAT. Не учитывать многочисленные добавочные/нестандартные записи архива как реальное содержимое карты. PAA DXT1, 512×512, дополнительное сжатие LZO; это 2 м/пиксель на местности. Материалы доказывают: исходный блок 1024 м, шаг 960 м, перекрытие 64 м, начало первого блока (-32,40992), квадрат мира 40960 м. Пограничные фрагменты обрезаются по точной площади мира. Полная площадь покрытия проверена: 1677721600 м². Совпадение перекрывающихся пикселей в трёх выбранных областях по горизонтали/вертикали: средняя ошибка 0.0.

Файлы:
- `tools/extract-map-background.js`: индексирование PBO, чтение RAP-материалов, получение подтверждённой проекции, manifest.
- `tools/map-assets/build-background.py`: потоковое чтение/распаковка PAA, удаление перекрытий, обзор и подробные JPEG. Pillow и локальный `tools/vendor/python/lzokay` (установлен в проект, системное окружение не менялось). Полный raster 20480×20480 не выделяется.
- `control-center/data/map-tiles/Australia/source.json`: пути/смещения исходных файлов, привязки и список фрагментов.
- `control-center/data/map-tiles/Australia/background.json`: готовность/размер/шаг/разрешение.
- `overview.jpg`: 4096×4096, 4623161 байт; `tiles/`: 1849 JPEG, суммарно 99259002 байта. Построение заняло 14.83 сек на текущем ПК, это не гарантия времени другой машины.
- `control-center/map-background.js`: метаданные и проверка границ выдачи фрагментов.
- `server.js`: `/map-background/<world>.jpg`, `/map-tile/<world>/<x>/<y>.jpg`; карты API возвращают background. Сборка из приложения `/api/build-background`, состояние `/api/background-job`; во время запущенной Arma сборка запрещена ради нагрузки. В UI доступны источники спутник/импорт; дополнительные фрагменты рисуются только видимые и не более 100 одновременно.

Данные дорог roads.shp найдены, но НЕ добавлены в слой: их координаты UTM содержат восточное смещение, перевод в игровые координаты пока не доказан. WRP содержит данные объектов/высот, но не распакован. Не объявлять анализ уклонов, точные контуры зданий или навигационную проходимость реализованными: текущий результат — привязанный спутниковый фон.

Проверено: все файлы фрагментов и 100% покрытие; обзор просмотрен как локальное изображение; 6 новых тестов карты/запуска; HTTP 200 JPEG для обзора, центрального/последнего фрагмента, отказ за границами/неизвестной карте; оба встроенных UI-скрипта синтаксически проверены. Реальный интерфейс браузера не визуально принят, игровые режимы не запускались. Приложение перезапущено и направлено в редактор.

Ошибка `missionFiles is not defined`: в prepareAndLaunch отсутствовали локальные объявления и для missionFiles, и для designed. Теперь объявлены `let designed=null; let missionFiles=[];` до разветвления. `tests/control-launch.test.js` выполняет целиком prepareAndLaunch в VM с заменой файловых/процессных действий и проверки API: ordinary Warlords, designer Warlords, Antistasi. Это подтверждает построение запроса/списков без реального запуска игры или обращения к моделям, не игровой успех.

## 23. Фоны для всех карт редактора — 06.10.2026

Подготовлены все 22 карты текущего реестра: 15356 подробных JPEG, обзор 4096×4096 для каждой, общий размер изображений около 1332 MiB. Данные на диске, UI одновременно показывает обзор и не более 100 видимых фрагментов; все карты в RAM сразу не загружаются. Фон выбирается через «Спутниковая карта из файлов»; в списке редактора есть отметка «фон готов». Сводный просмотр: docs/maps-backgrounds-contact.jpg. Реестр результата: dist/map-background-build.json. Индекс исходников: dist/map-background-index.json. Подготовка повторяется tools/extract-map-background.js <world>, затем Python tools/map-assets/build-background.py <source.json>, либо tools/build-all-map-backgrounds.js для проиндексированных карт.

Расширен extractor: виртуальные пути собираются из всех PBO нужного набора, поэтому Altis/Tanoa и другие карты с отдельными архивами слоёв теперь поддержаны. Размер квадрата взят из заголовка WRP v25 (слой × размер ячейки); учтён AppID. Для сжатого Australia читается только небольшой префикс, не выделяются 200 MB распакованного WRP. Для несжатых WRP потоковым чтением определяются ссылки на RVMAT; неиспользуемые старые материалы исключаются. Это устранило конфликт сеток Isla Pera: реально используются 81 фрагмент 9×9, а не все 484 оставшиеся в PBO. Размер Isla Pera 10240 м; Archie summer/winter 12288 м. В предыдущих CfgWorlds эти значения ошибочны/отличаются. Takistan и Chernarus теперь имеют реальные размеры 12800/15360 м; прежние резервные метаданные вообще не содержали размера. scan-worlds.js обновлён, чтобы следующее сканирование сохранило размеры из WRP.

Размер деталей рассчитывается по самому подробному исходному фрагменту, а не по последнему: однотонные морские текстуры иногда всего 4×4. На Altis есть 2233 ячейки без исходных спутниковых изображений; они отображаются однотонным фоном и помечены в интерфейсе. Точные исходные фрагменты не подменяются. На остальных 21 карте выбранная сетка покрыта файлами полностью. Малые погрешности float сохраняются в преобразовании, координаты не угадываются по картинке.

Проверено: все объявленные JPEG присутствуют, метаданные/размеры согласованы; расчётное покрытие с учётом явно пропущенных ячеек; 44 HTTP-проверки (обзор+деталь каждой карты) без ошибок; общий контактный лист просмотрен локально. Четыре теста карты и три имитированных пути запуска прошли. Это не приёмка UI браузера и не запуск игровых сценариев. Подробный рельеф/объекты и автоматический анализ уклонов всё ещё отдельная работа; PBO мода в этом проходе не изменялся.


## 24. Редактор покупки пехоты — 06.10.2026

В основной панели, после состава сторон, добавлен блок «Покупка пехоты за CP». Стороны: west (синие), east (красные), green (зелёные). Автоматический состав сохраняет подбор до 12 классов бойцов выбранной фракции; цену каждого можно изменить. Ручной состав позволяет выбирать бойцов из разных установленных фракций одной стороны. Есть фильтры мода, фракции и названия, только выбранные, страницы по 60 строк, цена каждого выбранного бойца, сброс цен стороны до 100 CP. Фильтры не удаляют выбор. Для зелёных автоматическая фракция берётся из дизайна карты; ручные покупки действуют в трёхстороннем режиме.

Поля внутри selected.army и каждого пресета: westInfantry/eastInfantry/greenInfantry — null для автоматического режима или массив классов для своего состава; westInfantryCosts/eastInfantryCosts/greenInfantryCosts — объект class:integerCP. Отсутствующие поля старых пресетов при validate нормализуются в null и {}. Ручной список: 1–256 элементов, дубликаты убираются; список цен: до 512 записей, целые 60–50000 CP. Нижняя граница согласована с существующим порогом расширения архивного каталога. Проверяются установленный класс INFANTRY и его сторона; технику, чужую сторону и неподдерживаемый класс отклоняем до запуска. Цена не указанного в ручном списке бойца может сохраняться для будущего повторного выбора; в текущий каталог этот боец не попадает.

control-center/warlords-editor.js: validate проверяет поля, infantry(army,prefix,faction) возвращает список с ценами, preset создаёт точные секции WEST/EAST Infantry, mods добавляет моды ручных классов и зависимости. Commander и гарнизоны остаются отдельными настройками; изменение магазина не подменяет фракцию командира. tools/build-three-mission.js получает GUER Infantry через тот же helper, учитывает цены. Native Australia и четыре адаптированных архива получают новый preset штатным генератором; server.prepareAndLaunch перед генерацией записывает selected.army в dist/warlords-editor-settings.json. Если вызываете native генератор самостоятельно, сначала синхронизируйте этот файл с нужным army: генератор читает его, а не произвольное состояние вызывающей стороны.

Для пользователя: открыть центр запуска, выбрать сторону → «Свой список бойцов», отметить бойцов и задать CP → «Сохранить настройки» или «Сохранить пресет». Далее запустить новую миссию через приложение. Редактор карты отдельно сохраняет геометрию; каталог пехоты относится к пресету запуска, поэтому при useDesign применяется к сгенерированному сценарию этой карты. В уже начатой миссии покупки не обновляются автоматически. Синие/красные каталоги общие для игроков и ботов соответствующей стороны; зелёные покупки относятся к собственному трёхстороннему runtime.

Проверка: node --test tests/infantry-shop.test.js tests/warlords-editor.test.js tests/control-launch.test.js tests/scenario-design.test.js control-center/core.test.js tests/control-options.test.js — 34/34. Пять новых тестов проверяют старые пресеты, точный состав и CP, отказ неверных классов/цен, реально сгенерированный GUER каталог, UI выбор/фильтры/цены/восстановление через VM и модель DOM. Основная панель перезапущена, HTTP подтверждает новый блок; это не визуальная проверка настоящего браузера. Профили пользователя не перезаписывались, Arma и LLM не запускались, установленный addon PBO не менялся. Следующая игровая приёмка: новая миссия, меню покупки игрока содержит выбранные классы и цены, боты набирают отряд из этого списка, CP реально списывается. Доступность отдельного класса может дополнительно ограничиваться конфигурацией загруженных модов.


## 25. Удобный редактор, сброс, стратегические союзники и память сторон — 06.10.2026

control-center/designer.html переработан без замены API сценариев: шесть вкладок (Сценарий; Точки и гарнизоны; Стартовая техника; Ресурсы и лимиты; LLM гарнизонов; Фон карты), карта занимает оставшуюся ширину, отдельная панель масштаба и инструментов добавления. Точки сгруппированы по типу, есть поиск, кнопка перехода к точке, выделение на карте и редактирование X/Y. Для компактных экранов карта и панель расположены вертикально. Семантические вкладки имеют aria-selected/aria-controls. Есть предупреждение о несохранённых изменениях при переключении карты/закрытии страницы. Переход Three → Native удаляет третью базу и исправляет недопустимую сторону игрока GUER.

Новая GET /api/design-defaults?world=ID возвращает scenario-design.blank(ID), не пишет файлы и требует ту же сессию панели. Кнопка «Сбросить настройки карты» подтверждает действие внутри приложения; сброс касается черновика текущей карты. До «Сохранить сценарий» сохранённый дизайн остаётся прежним. «Отменить сброс» возвращает черновик вместе с ещё не сохранёнными полями. По умолчанию: две базы на нормализованных позициях .2/.8 размера карты, native, игрок WEST, без смертельной зоны, без секторов/дополнительных спавнов/стартовой техники, лимиты 160 NPC / 32 машины, 6000 CP, доход 100, LLM гарнизонов выключена. Перед сохранением сброшенного дизайна надо поставить хотя бы один сектор: существующая проверка сценария это требует. Фон, подготовленные фрагменты карты, профили запуска и каталог покупки не сбрасываются.

Маршрут союзников shared теперь означает profile(primary,s.primaryModel), даже в dual, где основной tactical endpoint расположен на secondary. Отдельный allyRoute=separate сохраняется. Изменение в core.makeConfig; индекс панели поясняет новый смысл. Старые shared-пресеты автоматически получают стратегический маршрут при следующей генерации конфигурации, без переписывания пользовательских профилей. Отдельные маршруты сохраняются. playerSide=NONE (наблюдатель) теперь разбирается как NONE, поэтому три AI-стороны получают стратегическое сопровождение в dual; BLUE не считается стороной наблюдателя.

Новый bridge/side-memory.js: WeakMap по объекту конфигурации bridge, далее ключ snapshot.session + реальная BLUE/RED/GREEN. Четыре последних решения на сторону, до четырёх валидных действий в записи, без сохранения полного snapshot или текста ответов. Координаты действия запоминаются только если присутствуют в текущих фактах. Это история решений, НЕ подтверждение исполнения и НЕ достоверная текущая позиция врага. TTL 30 минут, до 32 разделов; память в RAM, сбрасывается при новом bridge. Snapshot session задаётся в missionNamespace через worldName/missionName/diag_tickTime и живёт до конца миссии. Новая миссия получает отдельную память. Нет смешивания между сторонами при одном узле или одной модели; запросы chat completions независимы. Стратегический кэш тоже перенесён из глобального Map в WeakMap конфигурации и ключ миссия/сторона/playerSide. Кэш 120 секунд; предел 32 записи. LM сообщения включают только OWN_SIDE_MEMORY своего ключа и правило FOG OF WAR. Типизированный разбор side/playerSide/ch не принимает поля, спрятанные в строке приказа.

Исправлена утечка данных до LLM: fn_buildSnapshot фильтрует группы одной стороны; в assets попадает только техника своей стороны через getVehicleSide; противник не становится observer/camera source. sharedIntel проверяется по TTL. Память группы очищается при изменении NeroAI_memorySide. fn_tacticalAutonomy берёт предполагаемую позицию контакта через getHideFrom, а shareIntel/uavRecon используют позицию/type из nearTargets, вместо getPosATL действительного объекта. Карта, названия/владельцы публичных секторов и фракции остаются доступными по правилам режима; это не список скрытых юнитов. Данная правка касается информации в контексте LLM, не меняет все ванильные алгоритмы ИИ или пользовательские средства Зевса. Официальное описание предполагаемой позиции: https://community.bistudio.com/wiki/getHideFrom?useskin=vector ; target knowledge: https://community.bistudio.com/wiki/knowsAbout . Некоторые страницы nearTargets недоступны через web (403), формат списка также проверен по существующим исходникам.

Проверки: 45 целевых тестов прошли (side-memory/designer-ui/warlords-dual/control-options/core/infantry-shop/control-launch/scenario-design); ещё 4 выбранные статические проверки безопасности и синтаксиса addon прошли. Восемь новых тестов проверяют reset/undo/save, вкладки/поиск/координаты, переключение режимов, разделение памяти по стороне/миссии/config, TTL/лимит/копии, отказ неверных данных, маршруты и настоящие HTTP тела запросов к локальному тестовому серверу. После небольшой финальной правки NONE/ARIA эти восемь тестов повторно прошли. Полный старый static набор по-прежнему падает на двух ранее описанных ожиданиях: вызов warlordsAutonomy в tacticalAutonomy и порядок profile-before-spawners. Их не скрывали и не меняли в рамках этой задачи. HTTP работающей панели подтвердил вкладки, сброс, две базы по умолчанию и стратегическую подпись; это не проверка изображения в настоящем браузере.

Собран dist/candidate/NeroWL.pbo: 84 файла, 454506 байт, SHA256 1A0E2F5A2C7F3A531F4DE232F0840F35F981CD1B2C5CBFE3BCFC09A5CC8977C5; verify-pbo подтвердил все исходные байты. Предыдущий кандидат сохранён в backups/editor-memory-*. Установленный PBO не перезаписывался, Arma/LLM не перезапускались, пользовательские профили не менялись. Использовать кнопку «Обновить мод и запустить Arma» после сохранения настроек; штатный запуск подготовит новую bridge config и установит кандидат с проверкой исходников. После перезапуска панели обновить открытые вкладки: старый session token устарел.

Следующая игровая приёмка: скрытая техника противника не появляется в assets/snapshot; контакт получает только известную/предполагаемую позицию после обнаружения, исчезает/устаревает по правилам разведки; BLUE/RED/GREEN запросы имеют собственный session/side и отдельную память. В dual союзный запрос должен идти на primary, вражеский — strategy primary + tactical secondary, а наблюдатель NONE — не создаёт союз BLUE. Проверить это по свежим RPT и журналу моста, без публикации ключей API. Сброс/отмена/выбор точек требуют отдельной визуальной проверки реального браузера; тест DOM не считается такой приёмкой.


## 26. Видимый список пресетов в центре запуска — 06.10.2026

control-center/index.html: блок «Сохранённые пресеты» над основными настройками. renderPresets строит карточки из state.presets с названиями, режимом, картой, числом командиров Warlords, игровым профилем, узлом/моделями и useDesign. Поиск по имени/карте/режиму/узлу/моделям; счётчик найденных и всех пресетов. DOM создаётся через textContent, пользовательские названия не вставляются в HTML. Пустой список и отсутствие совпадений различаются. applyPreset(name) заполняет поля и синхронизирует старый select и ссылку редактора карты; не сохраняет и не запускает игру. При наличии dirty-полей спрашивает о замене несохранённых изменений. Старый выпадающий список сохранён и использует тот же helper. save(name) обновляет карточки после API save; новый пресет сразу появляется. viewedPreset хранит выбранную карточку только в текущем окне. API/schema профилей не менялись.

12 проверок preset-list/infantry-shop/designer-ui прошли; четыре новые проверки покрывают карточки, фильтрацию/пустые состояния, применение без запуска, отмену замены несохранённых изменений, обновление коллекции и уникальные ID. HTTP работающей панели подтвердил список и поиск; реальный визуальный рендер браузера этими проверками не подтверждён. Приложение не перезапускалось, пользовательские профили и PBO не изменялись. Открытые вкладки обновить через Ctrl+F5 или перейти в основное окно центра запуска.


## 27. NetworkError локальной панели — 06.10.2026

Наблюдение: session.json указывал завершённый PID 20044; процесса server.js и listener 18775 не было, HTTP получил отказ подключения. stdout содержал только строку запуска, stderr без причины завершения. Причина остановки процесса не установлена; не приписывать её браузеру, модам или последним изменениям без доказательств. Панель восстановлена штатным control-center/start.ps1 -View launcher, новый PID 1588 / порт 18775; main/designer/API вернули 200, четыре пресета сохранены. Запускать ярлык для восстановления отсутствующего backend; простой refresh остановленный процесс не запускает.

В обоих HTML api теперь переводит сетевую ошибку в понятное сообщение с названием ярлыка. После конкретного 403 «Сессия панели устарела» клиент читает новую сессию из той же локальной главной страницы и повторяет отвергнутый запрос один раз, не перезагружая страницу и не очищая черновик. API_SESSION отделена от исходной константы SESSION. При сетевом отказе POST не повторяется автоматически: неизвестно, был ли он принят до разрыва. Другие 403 не обходятся; не изменены серверные host/origin/token проверки. Старые уже открытые страницы должны один раз загрузить обновлённый клиент, чтобы получить этот механизм.

13 проверок panel-connection/preset-list/designer-ui прошли; шесть новых проверок покрывают обе страницы, сетевой отказ, сохранение тела при обновлении токена, отказ чужого 403 и ограничение повторов. Повторная независимая HTTP-проверка после завершения команды запуска подтвердила доступность процесса. Устойчивость процесса при неизвестном внешнем завершении не гарантирована; постоянный сервис/автостарт Windows не создавался. Arma, bridge LLM и PBO не менялись.


## 28. Пресет Посадково: ВСУ против РФ, без авиации/артиллерии — 06.10.2026

Создан и выбран пресет «Посадково · ВСУ против РФ · без авиации», world m_36tuu484111s99 (Posadkovo, 9984 м). Новый tools/create-posadkovo-preset.js содержит чистую prepare(state,design) и явно изменяющую install(); повторный запуск install перезапишет этот именной пресет и дизайн текущей карты, поэтому для проверки использовать prepare. До установки сделаны копии profiles.json и map design в backups/posadkovo-preset-2026-10-06T20-50-52-064Z. Остальные четыре пресета сохранены; сохранённая конфигурация узлов/моделей и режим LLM наследованы из выбранного пользователем запуска. Выбрано 16 командиров на сторону (32 слота), 9 подчинённых, игрок WEST.

ВСУ: CUP_B_AFU, 12 типов покупаемой пехоты; РФ: rhs_faction_msv, 10 типов. Цены пехоты 100–200 CP по роли. Украинский магазин: 18 наземных классов, включая kba_bm_oplot (БМ Оплот), kba_t84_120 (Т-84-120 Ятаган), украинские Leopard 2A6/M1A1, Bradley, БТР-60, МТ-ЛБ, БРДМ, Humvee/M1240, транспорт/ремонт/боеприпасы/топливо/медицинский транспорт и пулемёт/АГС/СПГ. Российский: 12 классов, Т-72Б3 (2012/2016), Т-80БВ, Т-90, БМП-2/3, БТР-80/80А, Тигр, Урал, Корд, АГС. Старт: ВСУ Оплот + Ятаган + Bradley + Урал; РФ Т-72Б3 + Т-80БВ + БМП-2 + Урал. В сумме 8 стартовых машин. Экипажи создаёт существующая функция spawnAsset штатными конфигурациями техники; форму экипажа отдельного мода в игре не проверяли.

Настройки: NeroWL_Air=0, авиационных классов в магазинах нет; исключены все миномёты/ствольная артиллерия/РСЗО, включая BM21 (он в исходном каталоге CAR, поэтому проверка по категории недостаточна). В инструкциях LLM запрещены CAS/БПЛА/авиационные и артиллерийские запросы. Секторное сканирование выключено для разведки без выдачи скрытых позиций. Стартовые CP=6000, WEST/EAST гарнизоны 6, GREEN=0; союзная LLM shared (стратегическая primary).

Взята существующая геометрия карты: две базы и 5 секторов, координаты сохранены. Базы переименованы «База ВСУ/РФ». Вместо независимых гарнизонов секторы распределены WEST/EAST по середине карты (X), чтобы конфликт шёл между двумя указанными армиями; стандартные названия «Новая точка» заменены ближайшими населёнными пунктами либо «Центральные поля». Переход native/useDesign=true, green третьей армией не запускается. Изменение дизайна этой карты общее для всех запусков, использующих текущий сохранённый дизайн; прежний файл находится в указанной резервной копии.

Генерация проверена в missions/NeroAI_Designed_m_36tuu484111s99_Native.m_36tuu484111s99: validateDirectory дал 5 секторов/32 слота; обе категории Aircraft пустые; классы Infantry совпадают с заданными списками. ExtraMods содержит 12 путей, включая оба танковых мода. dist/warlords-editor-settings.json и dist/launcher-mission-settings.json синхронизированы с новым выбранным пресетом перед генерацией. Два новых теста tests/posadkovo-preset.test.js прошли, штатный HTTP state подтвердил 5 пресетов, новый activePreset и Air=0. Игра не запускалась; файлы в установленной Arma не менялись. Через центр запуска выбрать этот пресет и нажать «Обновить мод и запустить Arma»; в игре выбрать Posadkovo и сгенерированную миссию. Следующая приёмка: наличие обоих танков в магазине и стартовом спавне, пехота своих фракций, фактическая посадка/использование техники, отсутствие авиационных/артиллерийских покупок и безопасные позиции баз в движке.


## 29. Отдельная вкладка списка пресетов — 06.10.2026

Главное окно разделено на вкладки «Запуск и настройки» и «Список пресетов» (index.html, launchPanel/presetsPanel, showAppTab). Все формы остаются в DOM: переключение вкладки не сбрасывает введённый состав/параметры. Список и поиск перенесены в отдельную вкладку вместе с названием и кнопкой «Добавить новый пресет». «Настроить новый пресет» открывает настройки текущего запуска, которые пользователь редактирует и сохраняет под новым именем. Повторное имя блокируется в UI, чтобы новый пресет не перезаписал существующий. Применение карточки открывает вкладку настроек. Прямая ссылка /?tab=presets открывает список при загрузке страницы. Серверная схема/API не изменены. 15 проверок preset-list/panel-connection/infantry-shop прошли; HTTP подтвердил вкладку и форму добавления. Пользовательские пресеты и игровые артефакты не менялись.


## 30. Переработка основного интерфейса

index.html: launchPanel теперь содержит верхнюю сводку и setup-workspace с боковой навигацией: overview (запуск), models, vehicles, infantry, rules, instructions, journal. showSetup переключает видимость существующих форм; все прежние ID и selection/apply/save/API остаются совместимыми. Узлы перенесены к моделям, пользовательская инструкция — в свой раздел, технические пояснения редактора свёрнуты. Вкладка списка пресетов сохранена. Нижние кнопки сохранения/запуска закреплены; боковая навигация имеет ограничение высоты/прокрутку, узкие экраны используют сетку кнопок. В Antistasi Warlords-разделы отключены, редактор скрыт.

updateSummary показывает выбранный пресет, карту/профиль, модель(и), число командиров, количество выбранной техники, авиацию и dirty-состояние. updateDesignSummary читает только метаданные сохранённого дизайна и показывает observer/commander; revision защищает от устаревшего ответа при смене карты. Это состояние выбранных настроек, не свидетельство исполнения текущей миссии. Поиск и переключатели представления не делают конфигурацию dirty. message заменяет длинные технические ID карт на читаемые названия. parameterNodes группирует лобби-параметры в четыре раздела; поиск фильтрует строки/группы, сохраняя все select в DOM.

15 проверок preset-list/panel-connection/infantry-shop прошли после изменения collaborators теста карточек. Дополнительно выполнена настоящая проверка Codex In-app Browser: окно загрузило пять пресетов/Posadkovo/observer/16 командиров/Air=0; переключения Models/Rules/Presets/Overview работают, поиск «авиа» оставил настройку лимита авиации, временный профиль donko_UI_CHECK сохранился при переключениях. Тестовый профиль НЕ сохранялся; возвращён donko и тестовая вкладка перезагружена. Ошибок консоли не обнаружено. Снимок настоящего отображения сохранён docs/control-center-ui-refresh.png. Проверка выполнена на обычном viewport; отдельной проверки узких размеров нет. Работающая Arma наблюдалась в API как running, запуск заблокирован штатно. Игра/мост не перезапускались; профили, дизайн карты и PBO в этой задаче не изменялись. Обновить старую вкладку приложения или открыть /?v=20261006-ui-refresh.


## 31. Цветовые темы приложения

index.html и designer.html получили selector themeSelect «Цвет страницы». Семь встроенных палитр: blue/green/purple/amber/red/graphite/light. NERO_THEMES содержит фон/карточку/границу/акцент/приглушённый текст; setColorTheme выставляет CSS variables root, color-scheme и dataset.theme. CSS overrides перекрашивают страницы/формы/карточки/сводку/вкладки/журнал и панель карты, без изменения цветов WEST/EAST/GUER в SVG и исходного спутникового фона. Поскольку backend запущен, CSS/JS встроены в оба HTML и не требуют новых маршрутов/перезапуска. При изменении набора палитр синхронизировать обе копии.

Выбор сохраняется в localStorage 'neroai-color-theme' текущего браузера и origin. Не относится к игровому пресету или model config. Storage event синхронизирует уже открытые обновлённые страницы этого origin; недоступное хранилище не ломает интерфейс, неизвестное имя возвращается к blue. Индикатор dirty игровых настроек не реагирует на themeSelect (оба события input/change исключены).

17 целевых проверок прошли, включая четыре новые проверки themes для main/designer: все семь вариантов, восстановление, отсутствие сохранения на начальной загрузке, отказ localStorage, storage sync и неизвестное имя. Настоящая браузерная проверка: purple пережила reload, green и light визуально отобразились, индикатор оставался «Сохранено». Снимок зелёной темы docs/color-theme-green.png. После QA восстановлена исходная blue; пользователю предоставлен выбор темы. Профили, дизайн, PBO и процессы игры не менялись; реальное отображение редактора карты отдельно в этой задаче не проверяли.


## 32. Именованные пресеты настроенных карт (07.10.2026)

Главное окно: третья вкладка «Пресеты карт» (`/?tab=maps`). Варианты независимы от профилей запуска LLM/армий: сохраняются полный design редактора, базы, сектора, гарнизоны, спавны, стартовая техника, режим сторон, роль игрока, ресурсы и маршрут LLM гарнизонов. Каталоги покупки, узлы основных LLM и инструкции сторон остаются в профилях запуска.

Хранилище `control-center/map-presets.js`: отдельные UUID JSON в `control-center/data/map-presets/`, до 200 вариантов; одинаковая карта может иметь несколько снимков. Сохранение нового варианта не заменяет текущий design. В списке также показаны текущие карты с секторами из `data/designs/`, они явно помечены как текущие, не именованные снимки. Текущий Posadkovo сохранён отдельным снимком «Посадково · ВСУ против РФ · наблюдатель»; игровой design не менялся.

API с прежним localhost/session/origin контролем: GET `/api/map-presets` (снимки+текущие), GET `/api/map-preset?id=UUID`, POST `/api/map-presets` `{name,design}` либо `{name,world}` (последний сохранённый design), POST `/api/map-preset-apply` `{id}`. Каждый новый снимок и применение проходят scenario-design.validate с текущими установленными классами/узлами. Применение при выполняющемся запуске запрещено. Перед заменой текущего design сохраняется JSON резервной копии в `data/map-presets/backups/`.

Редактор: «Сценарий → Название пресета карты → Сохранить вариант в пресеты карт» сохраняет collectDesign() без замены текущей игровой конфигурации. Ссылка `designer?world=...&preset=UUID` читает snapshot как несохранённый черновик; не вызывает save. Нажатие «Сохранить сценарий» делает его текущим. Главное окно «Выбрать для игры» явно подтверждает замену текущей карты, сохраняет её с резервной копией, выбирает Warlords/map/useDesign только в полях запуска. Профиль надо сохранить штатной кнопкой; игра применит настройки при следующем запуске.

Проверка: 21 тест (map-presets, preset-list, designer-ui, color-themes, panel-connection), реальный IAB: создание снимка Posadkovo, сохранение после reload, поиск, открытие с пятью секторами и observer ролью в редакторе как черновика. Скриншот `docs/map-presets.png`. Arma/bridge/LLM/PBO не перезапускались и не изменялись этой UI-задачей; перезапускалась только панель для новых API.


## 33. Зависание native Warlords при гражданском наблюдателе (07.10.2026)

Живой RPT `C:\Users\Admin\AppData\Local\Arma 3\Arma3_x64_2026-10-06_23-56-08.rpt`: Posadkovo mission init в 00:00:20; в 00:12:29 elapsed=730 sectors=0 bases=false/false server=false client=false; в 00:15:02 elapsed=882. LLM adapter ждёт API, а не блокирует загрузку. Native research fn_WLInit.sqf ждёт player WEST/EAST на hosted client до WLVarsInit/sectorSetup; civilian observer условию не соответствует. Второй дефект: генератор делал combat units isPlayable=0, тогда как native WLVarsInit собирает playableUnits+switchableUnits. Официальная BIKI Arma_3_MP_Warlords требует playable commanders.

Исправление подготовлено, НЕ установлено в работающую Arma: tools/adapt-observer-init.js → addon functions/native/fn_WLInit.sqf и registration в CfgFunctions.hpp. Только в миссиях NeroWL_observer=1 обходит два combat client gates: server init сохраняется, civilian не запускает purchase client; sector arrays и endLoadingScreen проходят как server branch. tools/adapt-vars-init.js выключает ненужные uniform/client variables для observer. В build-australia-mission все native commander slots остаются playable для регистрации, native respawn и экономики; отдельный Civilian Observer остаётся основным местом игрока. Боковые combat slots теперь технически доступны в лобби: для LLM vs LLM выбирать Civilian Observer, иначе observer helper выдаёт подсказку. validate-mission проверяет playable=1 для боевых командиров независимо от observer.

Designer observer: независимые локальные маркеры секторов, обновление цвета раз в 5 сек., флаг NeroWL_observerReady. waitReady использует этот флаг вместо CP/menu/HUD игрока-командира. Через 120 сек. ожидание сообщает задержку вместо безусловного предложения ждать.

Проверено: 5 observer/Posadkovo тестов + 3 targeted mission-generation, всего 8; это статические/Node проверки, не исполнение SQF движком. Generated Posadkovo: 33 slots, 5 targets, 6 edges. PBO manifest+bytes verified: addon 85 files, 474636 bytes, SHA256 4A468A1030DE9FC19C7704E6D2B4EE9924FBC85DEDB82C170303F5D11C1B3D37; candidate mission 16 files, 100460 bytes, SHA256 F37849D59C912311D6914CDB78032817D8CDA8E85FD674DBA359EDB3080EF242.

Следующий обязательный gate: пользователь полностью закрывает Arma, запускает кнопкой панели «Обновить мод и запустить Arma» (она проверяет и устанавливает candidate, заново генерирует/пакует design). В лобби AI включён, место Civilian Observer. Проверить свежий RPT [NeroWL Init] observer=true, variables finished, Ready READY, warlords=32, sectors=7 including bases; на карте сектора/боты/Zeus, действительные покупки и действия обеих LLM. Фактическая скорость загрузки после исправления пока не измерена. Отдельные missing rhsterracore .p3d warnings остаются: они не объясняют зафиксированный wait-gate; зависимости карты требуют отдельной проверки.


## 34. Live check after observer gate update (07.10.2026)

User relaunched; live PID 22596, RPT `C:\Users\Admin\AppData\Local\Arma 3\Arma3_x64_2026-10-07_00-16-34.rpt`. Mission starts 00:17:56; 8 seconds later native init says observer=true, server=true; WLVarsInit start/end at 00:18:01; at 00:18:04 seven sectors (5 targets+2 bases), both bases and serverReady=true; READY elapsed=13 at 00:18:17 with warlords=32. This is direct live engine evidence the blocker is resolved in the running session. Installed addon PBO SHA256 equals candidate 4A468A1030DE9FC19C7704E6D2B4EE9924FBC85DEDB82C170303F5D11C1B3D37. Installed live mission matches generated `missions/` source via verify-pbo; its SHA 9CF36B9FAF78A1D4F227D18AD2DDFD6791E7A0A5A812ED0174E3E29C607216A0 differs the earlier candidate build, since launcher regenerated/repacked it after the candidate. Do not confuse that with installed mission failure.

Bridge live during 21:16-21:39 UTC (host log): 17 RED requests: 9 prism-ml/bonsai-27b and 8 google/gemma-4-26b-a4b-qat; 15 BLUE requests: all google/gemma-4-26b-a4b-qat. Average reply reported by bridge: RED 12.3 sec (peak 24), BLUE 6.3 sec (peak 14.3); multiple valid plans, but many NO_ACTION; one malformed/truncated finish_reason=length response safely became NO_ACTION. This matters to live order tempo; Warlords startup itself no longer waits for LLM. Runtime RPT has 13 dispatched action lines and 10+ native requisition logs in the observed six-minute slice. Evidence proves model transport/planning dispatch and some purchases, not equal strategic quality/effective combat on both sides.

Current process RAM 5.69 GiB. Boarding telemetry during same RPT: 9 BOARDING_FAILED, 29 PARTIAL_MOUNTED, 10 CUP_LockedTurretGetOut missing/invalid callback reports. These are observed ongoing correctness/performance risks, not the mission-start delay cause. Need separately reduce purchase/commander concurrency and repair seat/turret compatibility before calling battle quality good; do not restart live mission for inspection. FPS itself unavailable in RPT; measure in-game/server FPS separately.

## 35. Закупки на каждую сторону и удержание отрядов на посадке (07.10.2026)

Пользователь наблюдает повторные покупки у обеих армий и простаивание синей техники на базе. Причина в коде: штатный FSM Warlords и NeroAI действуют параллельно, у каждого из до 16 командиров свой кошелёк и ограничения покупки применялись отдельно к группе. Снимок live RPT подтверждает native-покупки и собственные реквизиции в одной сессии; там же зафиксировано 9 BOARDING_FAILED и 29 PARTIAL_MOUNTED в осмотренном фрагменте, поэтому заявлять, что приобретённая техника используется эффективно, нельзя.

Подготовлен candidate: `fn_claimSidePurchaseSlot.sqf` задаёт общий атомарный интервал 75 секунд на сторону для native FSM и NeroAI BUY; native predicate вызывается только после проверки доступного каталога/CP и отсутствия уже закреплённой техники группы. `fn_autoRequisition.sqf`: больше не покупает вторую машину для частично размещённого отряда, автоматический порог CP 2500, резерв 1500, максимум 1 машина на группу. `fn_tacticalAutonomy.sqf`: во время интервала после заказа и активной посадки LLM-приказы не перебивают логистику. Генератор Australia нормализует все три ветки native purchase FSM.

Candidate `dist/candidate/NeroWL.pbo`, 86 файлов, 476289 байт, SHA256 `32E96E913F46EF8F341DA49C14AAC526E6C33E066C66C2CF63402AA933DD71E1`. `verify-pbo` подтвердил полное совпадение с исходниками, build-australia-mission.js прошёл `node --check`, dry-run адаптера показал три side-gates после проверок цены/денег/текущей техники. Предыдущие candidate сохранены в `dist/candidate/backups/`. Это статическая проверка; SQF ещё не запущен движком. Не устанавливать в живую сессию.

Текущая Arma PID 22596 остаётся открыта (на момент осмотра RAM около 6.37 GB); installed PBO не менялся. Следующий gate: пользователь полностью закрывает Arma/лаунчер и запускает обновление из Control Center, чтобы кандидат установился вместе с пересобранной миссией. В новой партии сравнить покупки каждой стороны за 10 минут, время между заказами, количество групп в PARTIAL_MOUNTED/BOARDING_FAILED, посадку в свою технику и реальные приказы продвижения. Проверить по свежим RPT и журналу моста; статистическая закупка/зелёный PBO сами по себе не доказывают боевую эффективность.


## 36. Полный аудит 7 октября: текущий handoff

См. новую полную инструкцию и отчёт. Изменены мост/сериализация inbox, карты/dependencies, purchase/boarding/native FSM/global caps, generator profile precedence, casualty strength, active preset labels, CQ guards, green catalogue и актуальная доктрина. Целевые тесты 70/70, полный набор 201/221 с 20 незавершёнными контрактами, static SQF smoke 4/4. Новый кандидат 63EB70DCF0FD553019F1FA461910C0A411A0F2AA9B21933289A2D6B6AF795969 / 87 файлов / 481819 байт совпадает с source, но не установлен. Установленный hash 4A468A... не изменён. Реальный GPT-OSS completion: HTTP400 insufficient system resources; loaded Gemma :2 context4096 timeout20s. Пользовательский выбор Australia/single/GPT-OSS не откатывать к Посадково. Панель перезапущена, игру/мост не запускали. Следующий gate: model readiness/context budget, миграция тестов, актуальное разрешение на game acceptance и свежий RPT.
