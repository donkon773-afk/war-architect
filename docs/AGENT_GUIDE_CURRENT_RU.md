# NeroAI Warlords и Control Center: полная инструкция для следующего агента

Актуализировано 7 октября 2026, Europe/Kiev. Это рабочее руководство по конкретной локальной редакции. Аудит продолжается; результаты последующих проверок записываются в `AUDIT_20261007_RU.md`. История решений и подробные изменения находятся в `AGENT_HANDOFF_RU.md`, но старые показатели установки и старые ограничения там нельзя считать текущими.

## 1. Проект, установка и полномочия

| Объект | Абсолютный путь |
|---|---|
| Исходники Warlords и приложения | `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM` |
| Отдельная версия Antistasi | `C:\Users\Admin\Desktop\ИИ\NeroAI_5.0-antistasi` |
| Arma 3 | `H:\SteamLibrary\steamapps\common\Arma 3` |
| Установленный аддон Warlords | `H:\SteamLibrary\steamapps\common\Arma 3\@NeroAI_Warlords\addons\NeroWL.pbo` |
| Кандидат аддона | `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM\dist\candidate\NeroWL.pbo` |
| Установленные миссии | `H:\SteamLibrary\steamapps\common\Arma 3\MPMissions` |
| Журналы игры | `C:\Users\Admin\AppData\Local\Arma 3` |
| Настройки/пресеты приложения | `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM\control-center\data\profiles.json` |
| Навык разработки | `C:\Users\Admin\.codex\skills\neroai-development\SKILL.md` |

Пользователь поручил полный аудит и исправление ошибок мода и приложения. Продолжать эту работу, а не ограничиваться отчётом. Не запускать отдельный сервер/HC: текущая схема — обычный Steam-клиент, внутри него hosted multiplayer. Не переносить экономику Warlords в соседний Antistasi.

Перед работой проверить наличие AGENTS.md в конкретном дереве. На дату этого аудита в корне Warlords AGENTS.md и Git-репозитория нет. Не применять инструкции координации соседнего проекта автоматически. Перед изменениями сохранять затрагиваемые исходники, пользовательские данные и установленные PBO отдельными резервными копиями. Не завершать игру ради обновления, не удалять INIDBI-очереди, не менять Workshop и исходные пользовательские ZIP.

Файлы profiles/configs содержат частные API-ключи. Не печатать их целиком и не включать ключи в отчёты, тестовые фикстуры, скриншоты или архивы для отправки. `publicState` удаляет ключи при выдаче браузеру. Все операции с моделью идут на выбранные пользователем узлы; API модели не означает подтверждённое управление в игре.

## 2. Текущее состояние и обязательные различия

На последнем осмотре Arma была закрыта. Перепроверять перед установкой: состояние процесса меняется. Последний RPT — `Arma3_x64_2026-10-07_00-16-34.rpt`.

Установленный аддон (с 7.10 19:54) имеет SHA256 `63EB70DCF0FD553019F1FA461910C0A411A0F2AA9B21933289A2D6B6AF795969`. Новый кандидат 7.10 вечер (авиация, базы у аэродромов, GREEN-лимит, телеметрия) — `38F4624947D3FB1DF4395015CA9902D003DE21CBCEB47794ABA4C4084425A920`, 89 файлов, ещё не установлен; прежний 4A468A10… в backups/control-center-20261007-195425. Финальный кандидат аудита — `63EB70DCF0FD553019F1FA461910C0A411A0F2AA9B21933289A2D6B6AF795969`, 87 файлов, 481819 байт. Предыдущий кандидат 32E96E... сохранён в backups/audit-20261007-compatibility/NeroWL.before-full-audit.pbo. Проверять хеши заново: это снимок, а генерация миссии пересоздаёт часть addon FSM. Кандидат пока не установлен; исправление моста и зависимости карты также требует свежего запуска соответствующего процесса.

Доказано в последней игре: native Warlords стартовал, обе базы и семь секторных объектов появились, READY через 13 секунд, 32 командира зарегистрированы. Обе стороны отправляли запросы LLM; были реальные покупки за CP. Эффективное применение техники и равномерный темп обеих сторон не доказаны. За весь завершённый RPT найдено 43 BOARDING_FAILED, 47 PARTIAL_MOUNTED, 22 ошибки CUP LockedTurretGetOut и одна ошибка ACE throwWeapon. FPS в RPT не измерен.

Последний фактический выбор пользователя: Australia, стандартный сценарий (useDesign=false), single Mac / openai/gpt-oss-20b, 10 командиров, до 5 бортов, профиль donko, ACE/Dev включены. Нельзя откатывать его к Посадково. Именованный Posadkovo-пресет сохранён отдельно: WEST CUP AFU против EAST RHS MSV, 16+16, девять подчинённых, без авиации/дальней артиллерии, civilian observer с Zeus, Оплот/Ятаган в магазине и на старте. Читайте core.publicState() для текущего выбора; это не доказательство загруженной модели.

## 3. Как устроен запуск

1. Ярлык NeroAI Control Center запускает `control-center/start.ps1`. Сервер слушает loopback, обычно `http://127.0.0.1:18775/`, при занятости порта выбирает до 18785. Фактические PID/port в `control-center/data/session.json`.
2. HTML получает session token. API проверяет loopback, Host, Origin и X-Nero-Session. После перезапуска панели старый token обновляется штатным механизмом страницы.
3. `core.validate` проверяет профиль, карту, LLM-модели, параметры и каталог. Сохранение профиля не применяет настройки к уже запущенной игре.
4. `core.makeConfig` создаёт производный bridge config в `control-center/data/runtime/`; private keys остаются на сервере. Single направляет основной поток в одну модель. Dual использует primary для стратегии, secondary для тактики; союзная и гарнизонная модели могут иметь отдельный маршрут.
5. `server.prepareAndLaunch` проверяет объявления моделей, записывает выбранные army/lobby settings в dist, генерирует миссию, валидирует её, пакует PBO и сверяет его с исходниками.
6. `launch.ps1` проверяет отсутствие игры/лаунчера, делает настоящий completion-запрос, сверяет candidate/source, сохраняет установленные PBO, копирует новое, проверяет хеши. Затем останавливает только известные bridge paths, запускает мост и Steam-клиент с профилем donko.
7. В Arma: Multiplayer → Create server → нужная карта → сгенерированная миссия. Включить AI. Для LLM vs LLM выбрать Civilian Observer. Боевые slots остаются playable для регистрации native Warlords; это техническое требование режима.

При ошибке запуска читать `control-center/logs/launch-error.log` и `launch-helper.log`. Файл-backed вывод помощника нужен потому, что Steam может держать наследуемые stdout pipes. Повторный запуск ярлыка переиспользует старый сервер и не обновляет загруженные JS-модули.

## 4. Интерфейс и три типа сохраняемых данных

Главное окно имеет вкладки запуска/настроек, списка игровых пресетов и пресетов карт. Внутри запуска есть разделы моделей, техники, пехоты, правил, инструкций и журнала. Техника группируется по модам-поставщикам; classname остаётся стабильным ID даже при одинаковых названиях. Темы страницы хранятся в localStorage браузера и не являются настройкой игрового профиля.

Игровой профиль (`profiles.json`) содержит сценарий, модель/узел, donko, army, цены пехоты, параметры лобби и инструкции. Текущий дизайн карты (`data/designs/<world>.json`) содержит базы, сектора, спавны, гарнизоны, стартовую технику, observer/commander, lethal zones и маршрут гарнизонов. Именованный пресет карты (`data/map-presets/<UUID>.json`) — отдельный снимок дизайна. Он не содержит каталога покупки или основных LLM-узлов.

Открытие именованной карты в редакторе создаёт черновик. «Сохранить сценарий» делает его текущим. «Выбрать для игры» применяет снимок с резервной копией, затем профиль запуска нужно сохранить штатной кнопкой. Переключение вкладок и поиск не должны уничтожать несохранённые поля. После обновления JS сервера перезапустить только панель; после обновления HTML перезагрузить страницу.

## 5. Файлы для изменений

| Узел | Файлы внутри корня проекта |
|---|---|
| UI | `control-center/index.html`, `designer.html` |
| Профили/валидация/маршруты | `control-center/core.js` |
| API и задача запуска | `control-center/server.js`, `launch.ps1`, `start.ps1` |
| Каталог/цены/пехота/зависимости | `control-center/warlords-editor.js`, `asset-names.js` |
| Карты/пресеты/фон | `scenario-design.js`, `map-presets.js`, `map-background.js`, `map-survey.js` |
| Дополнительные требования карт | `control-center/map-mod-dependencies.js` |
| Native mission generator | `tools/build-australia-mission.js`, `build-designed-mission.js` |
| Три стороны | `tools/build-three-mission.js`, `tools/designer-assets/` |
| Архивные миссии | `tools/build-criteria-missions.js`, `package-criteria.ps1` |
| Lobby/default settings | `tools/mission-assets/params.hpp`, `fn_applySettings.sqf` |
| Пакет/проверка | `tools/pack-pbo.ps1`, `verify-pbo.js`, `validate-mission.js` |
| Мод | `addons/NeroAI3/config.cpp`, `addons/NeroAI3/functions/CfgFunctions.hpp` |
| LLM | `bridge/lm-studio.js`, `system-prompt.js`, `warlords-doctrine.js` |
| Транспорт/валидация | `bridge/server.js`, `protocol.js`, `side-memory.js` |
| Диспетчер | `addons/NeroAI3/functions/core/fn_dispatchResponse.sqf`, `fn_executeMacro.sqf` |
| Тактика/закупки | `functions/tactical/fn_tacticalAutonomy.sqf`, `fn_autoRequisition.sqf`, `fn_purchaseAsset.sqf`, `fn_purchaseAirAsset.sqf` |
| Посадка/маршрут | `functions/tactical/fn_vehicleTactics.sqf`, `fn_vehicleRoute.sqf`, `fn_mobilityWatchdog.sqf` |
| Native adapters | `functions/native/`, `tools/adapt-*.js` |

`missions/` и runtime PBO — производные результаты. Не чинить только их: генератор затрёт правку. Индекс `dist/mod-assets.json` отражает прочитанные PBO, но не доказывает, что нужный мод загружен в текущую Arma.

## 6. Контракт LLM и разведки

Снимок SQF → INIDBI outbox → `validateRequest` → выбранная LLM → полный JSON → `validateModelResponse`/grounding → INIDBI inbox → SQF poller → dispatcher → executeMacro. LLM-output всегда данные. Не исполнять её SQF, shell, пути, код или незавершённые потоковые фрагменты.

Прямые приказы игрока имеют приоритет над автономией и watchdog. Память и разведка разделены по side; модель знает только наблюдаемые контакты своей стороны. Общий физический endpoint не означает общую память. Перед изменением маршрута проверить SIDE/GROUP/AUTONOMY/INTERGROUP, observer playerSide и союзный route. Стратегический cache тоже должен разделяться по стороне.

Новые действия требуют согласованной миграции bridge enum/schema, protocol, SQF dispatcher/executeMacro и регистрации функций. Spatial actions принимают только проверенные координаты/известные цели; NO_ACTION и отказ безопасны. Не заменять отказ свободным спавном или телепортацией.

Закупка наземки использует настоящий BIS_WL_funds и BIS_fnc_WLAirdrop. Кандидат ограничивает native и NeroAI заказы общим side cooldown 75 сек., auto threshold 2500 CP, reserve 1500, одну машину на группу. Посадка подтверждается фактическим vehicle каждой пары unit/seat, а не одним assignAsCargo. Логистика временно блокирует новые автономные планы движения. Максимум машин и aircraft budget — отдельные ограничения.

## 7. Как безопасно редактировать и собирать

Новый параметр проходит Params → core validation → UI selection/apply → генератор/серверную настройку → проверку roundtrip. Типы, диапазоны и allowlist проверять на сервере. Новый classname брать из установленного config, проверять side/scope/наследование/экипаж/места/оружие/мод. Не подменять класс по похожему торговому названию.

Перед сборкой записать snapshot выбранных настроек и затрагиваемых исходников. Выполнять стадии последовательно; проверять exit code после каждой Node/native команды. PowerShell-скрипт без внешней программы не обязан устанавливать LASTEXITCODE: его успешность определяется отсутствием исключения.

```powershell
Set-Location -LiteralPath 'C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM'
node --check control-center/core.js
node --check control-center/server.js
node --check bridge/server.js
node --check bridge/lm-studio.js
node --check tools/build-designed-mission.js
node --test tests/control-launch.test.js tests/scenario-design.test.js tests/mission-generation.test.js tests/observer-startup.test.js tests/side-memory.test.js tests/bridge.test.js control-center/core.test.js
```

`npm test` покрывает только dual tests; полный обзор — `node --test --test-reporter=tap tests/*.test.js`. Сохранить результат и разбирать ошибки, а не удалять старые проверки для зелёного статуса. Генерация Native пересоздаёт addon purchase FSM, поэтому addon паковать после генерации. Для текущего дизайна использовать `build-designed-mission.build(schema.load(world), state)` и штатную валидацию. Три стороны имеют отдельный CQ runtime.

```powershell
./tools/pack-pbo.ps1 -SourceDir ./addons/NeroAI3 -OutputDir ./dist/candidate -OutputPbo NeroWL.pbo -Prefix NeroWL
node tools/verify-pbo.js dist/candidate/NeroWL.pbo addons/NeroAI3 NeroWL
```

Миссию паковать с `-Mission` и сверять с `verify-pbo ... --mission`. Простая проверка скобок/регулярных выражений не исполняет SQF. При установке сохранять backup каждого заменённого PBO и manifest хешей. Не выдавать успешную упаковку за исправление поведения ботов.

## 8. Текущий аудит: что уже найдено

Базовый полный прогон: 206 тестов, 182 passed / 24 failed, `dist/audit-tests-20261007.tap`. Многие failure — прежние требования к текстам и старым режимам. Обнаружены отсутствующие рекламируемые tools/vision-monitor.js и tools/benchmark-local-llm.js, устаревшая observer-проверка и неустойчивый тест INIDBI с фиксированным ожиданием 20 мс. Benchmark теперь реализован, отсутствующий vision-monitor убран из npm scripts, observer/poller tests обновлены. Текущий targeted набор 70/70; полный прогон 221 тест, 201 passed / 20 failed, разобранных в AUDIT_20261007_RU.md. Не считать весь набор зелёным.

Основные изменения (полный перечень и ограничения в отчёте):

- `bridge/server.js`: ответы в один inbox сериализуются Promise-очередью; устранена гонка создания INI-секции. Это блокировка одного процесса, не доказательство межпроцессной блокировки INIDBI2.
- `tests/bridge.test.js`: ожидание ответа по факту вместо 20 мс; добавлена проверка 20 одновременных записей.
- `map-mod-dependencies.js` и `build-designed-mission.mods`: Posadkovo получает установленный RHS Terracore, который отсутствует в declared dependency, но нужен по реальному RPT.
- Из выбранного профиля Posadkovo убраны `CUP_B_nM1151_ogpk_m2_AFU` и `CUP_M1240_OGPK_M2_AFU` из-за 22 ошибок турельных callbacks. Полный каталог приложения не удалён. Backup: `backups/audit-20261007-compatibility/profiles.before-compatibility.json`. Фабрика нового Posadkovo-профиля также исключает эти классы.
- Подготовлен предыдущий candidate с общим интервалом закупок/защитой посадки; его игровая приёмка ещё впереди.

Ошибка ACE `fnc_throwWeapon.sqf:32` — внешний мод: тип Any вместо Array. Не чинить установленный Workshop без анализа конкретного сценария/экипировки/события. Ошибки CUP и ACE не доказывают ошибку JSON-диспетчера, но ухудшают реальную посадку и боевое поведение.

Реальная LLM-проверка (продолжение): GPT-OSS-20B загружен пользователем (context 26578), check-brains ready, худший снимок ~5870 токенов, 4,4–5,3 с. Лимит снимка моста поднят 6000→7400, запись inbox повторяется при EBUSY от INIDBI2; полный прогон 203/223 с теми же 20 legacy failures. Подробности — раздел «Продолжение 7 октября» в AUDIT_20261007_RU.md.

## 9. Продолжение аудита и критерии приёмки

Следующий агент должен сверить фактические изменения и `AUDIT_20261007_RU.md`, затем:

1. Завершить targeted тесты изменённого моста и карты. Проверить failure/retry, duplicate/stale ID, restart и выдачу безопасного отказа.
2. Проверить frontend roundtrip моделей/профилей/карт/пехоты/техники, сброс как черновик, API session renewal, сохранность dirty fields; настоящую браузерную проверку отличать от DOM-мока.
3. Проверить генерацию native/three/observer, цены CP, гарнизоны, лимиты, стартовые assets, карту и dependencies. Убедиться, что Posadkovo extraMods содержит RHS Terracore.
4. Проверить SQF locality, ownership, cancelled boarding, реальную посадку, native selected sector, stale LLM response и ресурсы. Не включать всевидение при поиске целей.
5. Разобрать оставшиеся 20 failures по каждому контракту. Исправлять настоящие ошибки кода; устаревшие проверки обновлять с объяснением действующего требования.
6. Собрать новый reviewed candidate и документировать source/package/installed hashes. Запуск игры выполнять только в рамках текущего разрешения пользователя и при закрытой Arma; не закрывать её самостоятельно.
7. В движке проверить 10 минут обеих сторон: число/темп заказов, экипажи, выход с базы, выбранные сектора, CP, airLimit/no-air, garrisons, Zeus properties, реальные FPS. Сохранить RPT и коррелированные request/group IDs.

Промпт для продолжения: «Работай в C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM. Прочитай docs/AGENT_GUIDE_CURRENT_RU.md и docs/AUDIT_20261007_RU.md, затем продолжи незавершённый полный аудит. Сверь текущие процессы и хеши; сохраняй пользовательские данные и оригинальные моды. Проверяй действующие контракты приложения, моста, генератора и SQF, исправляй воспроизводимые ошибки, сохраняй результаты. Не объявляй статическую проверку игровой приёмкой. Перед запуском обновления проверь разрешение и отсутствие Arma/лаунчера. Не запускай server/HC.»

## 10. Пошаговое использование приложения

1. Запустить `control-center/start.ps1`, открыть адрес из session.json. Вкладка «Запуск и настройки» описывает именно будущий запуск. Изменения уже начатую миссию не перенастраивают.
2. Выбрать Warlords или отдельный Antistasi. Для обычных Australia/Takistan/Altis/Chernarus можно оставить стандартный сценарий; для остальных карт нужен сохранённый дизайн и useDesign=true.
3. Во вкладке моделей указать адрес OpenAI-compatible API с `/v1`, выбрать primary/secondary. Single — один основной маршрут; dual — стратегия primary, тактика secondary. Союзники по умолчанию используют стратегическую primary; separate задаётся явно. Физически эти назначения могут вести на один узел.
4. Проверка списка моделей проверяет discovery. Окончательная проверка перед запуском должна получить полный валидный completion. Не выбирать другую модель без причины и не отключать memory guardrails на Mac, чтобы скрыть отказ загрузки.
5. В технике выбрать фракции WEST/EAST и разрешённые классы покупки. Фильтры мода/типа/поиска меняют отображение, не снимают выбранные классы. Самолёты/вертолёты имеют цену и условия сервиса; покупка не доказывает готовый вылет. Infantry отдельно: auto или custom список классов с ценами CP.
6. В правилах задать 10/12/16 командиров, до 9 либо 12 подчинённых согласно Params, air limit 0–5, LLM recruitment, агрессию, гарнизоны, доход/стартовые CP и остальные параметры. Общий лимит NPC считается живыми AI, включая экипажи; лимит техники отдельно. 16 командиров с девятью подчинёнными означает до 160 бойцов на сторону до экипажей/гарнизонов, а не 16 NPC на всю сторону.
7. В инструкциях вписать предпочтения до 3000 символов. Инструкции не дают модели произвольный код, деньги, невидимые координаты или право отменять приказ игрока. Не добавлять бесконечную историю вручную: side memory ограничена.
8. «Сохранить настройки» сохраняет текущий выбор, не переписывая прежний именованный пресет. «Список пресетов → Добавить новый» создаёт отдельную запись. Если текущие поля расходятся с выбранным именованным пресетом, сводка показывает запуск без имени.
9. Если используется редактор, сохранить дизайн отдельно, вернуться в главное окно, выбрать ту же карту и useDesign. Только после этого сохранять launch preset и выполнять обновление/запуск.
10. Запуск создаёт runtime config, новый mission PBO и проверенный addon. Дальше пользователь в hosted multiplayer выбирает миссию, включает AI в лобби, задаёт параметры и начинает за командиром или Civilian Observer.

## 11. Редактор карты и применение дизайна

Редактор `/designer?world=<ID>` имеет шесть разделов: сценарий; точки/гарнизоны; стартовая техника; ресурсы/лимиты; LLM гарнизонов; фон карты. ID установленной карты может отличаться от её display name и Arma world suffix. Использовать `scenario-design.worlds()` как источник соответствия, не составлять classname карты по названию.

Точки: main bases ровно по одной на активную сторону; sectors — цели захвата; spawns — дополнительные respawn points. Положение в UI `[x,y]`, SQM PositionInfo использует `[x,height,y]`; спутниковый SVG имеет отдельное преобразование Y. Не менять порядок координат наугад. Для техники выбирать ровную открытую площадку возле настоящей полосы; наличие красивого фонового изображения не доказывает физическую ровность/проходимость.

В native режиме stock Warlords обслуживает WEST/EAST; GREEN — гарнизоны. В three режиме работает собственный CQ runtime, требуется третья база, доступны GREEN defender/invader и игра за зелёных. Observer — отдельный civilian slot с Zeus; в native AI slots остаются playable ради регистрации stock Warlords. В three observer AI slots не playable. Система выбора следующего сектора, дохода и покупок CQ реализована собственными functions.

Гарнизон каждого сектора: side, radius, число пехоты и число машин, allowlist наземных классов. Число экипажей отдельно от числа обычной пехоты. Стартовые assets каждой стороны задаются отдельно от shop: убрать самолёт из покупки не означает убрать его из стартового списка. Для режима без авиации проверить оба списка и NeroWL_Air=0. Для режима без дальней артиллерии удалить также STATIC/артиллерийские vehicle classes из shop/start/garrison; одних слов модели недостаточно.

Garrison LLM включается в дизайне: shared использует общий маршрут, separate — свой узел/модель и instruction до 2000 символов. Лимит подключаемых групп 1–8. Гарнизоны подключаются по сценарному событию; действительность enrollment и принадлежность intel проверять по группе в RPT.

«Сбросить настройки карты» сбрасывает текущий черновик к defaults и допускает отмену. Он не должен менять текущий файл/именованный снимок до явного сохранения. Именованный preset карты — snapshot дизайна; применение делает backup прежнего дизайна. Launch preset сохраняется отдельно. Контрольный круг: save design → reload designer → main useDesign/map → save profile → generation → parsed config → installed PBO → fresh RPT.

## 12. Транспорт, память, экономика и ограничения

INIDBI2 переносит строки с byte limit: snapshot 7400 bytes, полный wire до 7900. Optional context сокращается как целые поля, а не обрезкой JSON/SQF внутри строки. Player order и адресуемые группы сохраняются. Проверять русские многобайтные символы; char length не равно byte length.

Protocol v3 содержит allowlist действий; изменения enum должны пройти JSON Schema, validateModelResponse, grounding и SQF. `SET_SECTOR` означает наблюдение направления, не захват сектора. Для движения ADVANCE/ASSAULT; BUY лишь покупает; ASSIGN_ROLE назначает роль; AIR_TASK ставит задачу уже доступному платному борту. Состав/CP/позиции в ответах проверяются и не исполняются как код.

Side memory хранится в RAM по конфигурации, mission session и фактической side; до четырёх записей, TTL 30 минут и bounded stores. Перезапуск очищает её. Это не долгосрочная база стратегического обучения. Shared endpoint не имеет права добавлять RED память в BLUE prompt. Контакты — believed positions/knowsAbout, чужая реальная техника исключается из assets. Старый snapshot после side switch не должен выполнять приказы новой стороне.

Native stock infantry и NeroAI имеют разные пути закупки, но ресурсные caps общие. Пауза 75 с ограничивает bot vehicle orders на сторону; custom infantry claim также участвует в очереди. Native infantry не сериализуется этим vehicle cooldown. Aircraft имеют отдельный side cap до пяти и общую vehicle capacity. Игроку ручная CQ покупка не навязывает cooldown ботов; каталог/CP/cap всё равно обязательны.

Защита посадки не является телепортацией. Проверять living crew/cargo, owner/locality, GETIN, сохранённый native waypoint, сроки и причину отказа. Критические CP операции находятся в unscheduled section `isNil { ... }`; не вставлять sleep/waitUntil туда. Невыполненный поздний ответ должен безопасно отказаться, не списать CP второй раз и не накапливать бесплатную технику.

Зрительный модуль не получает изображения от dedicated server/HC. Текущая сборка по умолчанию отключает vision; нет подтверждённого camera publisher с разграничением сторон. Не называть наличие JS vision-файла работающим машинным зрением.

## 13. Диагностика для следующего агента

Сначала прочитать session.json, процессы и последний RPT, затем текущие hashes. Не печатать profiles.json или bridge config целиком: в них ключи. Безопасная краткая сводка:

```powershell
@'
const c=require('./control-center/core'),s=c.publicState();
console.log(JSON.stringify({activePreset:s.activePreset,scenario:s.selected.scenario,map:s.selected.map,useDesign:s.selected.useDesign,mode:s.selected.mode,model:s.selected.primaryModel,commanders:s.selected.commanders,presets:Object.keys(s.presets)},null,2));
'@ | node
Get-CimInstance Win32_Process | Where-Object {$_.Name -match '^arma3'} | Select-Object ProcessId,Name
Get-FileHash -LiteralPath 'H:\SteamLibrary\steamapps\common\Arma 3\@NeroAI_Warlords\addons\NeroWL.pbo' -Algorithm SHA256
```

В RPT искать NeroWL READY, sector counts, NeroAI request/response/group IDs, deferred actual result, BUY payer/cost/balance, BOARDING_FAILED/PARTIAL_MOUNTED, внешние SQF ошибки и missing p3d. В `bridge/logs` искать start/poll/validation/LM errors; панельный `journal.js` объединяет источники и скрывает ключи. Журнал dispatch не доказывает прохождение маршрута; после него нужен actual position/crew/waypoint.

Через API панели session token приходит из HTML. Использовать X-Nero-Session и корректный loopback Origin; не хранить token в документации. Read-only endpoints: `/api/state`, `/api/catalog`, `/api/worlds`, `/api/design?world=...`, `/api/design-defaults?world=...`, `/api/map-presets`, `/api/journal`. Смена профиля/дизайна выполняется POST после server validation, не редактированием случайного PBO.

Приготовить диагностический completion без игры можно через `tools/benchmark-local-llm.js --config <runtime-config> --runs 1`; он не читает/пишет игровые очереди. Отчёт содержит wall latency/validity, не FPS, не tokens/s и не доказательство правильной игры. Список моделей может содержать JIT-downloads. Native LM Studio `/api/v1/models` показывает loaded_instances; менять model load/unload отдельно от read-only диагностики.

## 14. Dev, Zeus и приёмка в Arma

Dev включает консоль Esc и хостовый Zeus (обычно Y). ACE/CBA settings: Esc → Настройки → Настройки дополнений → Клиент/Сервер/Миссия. Само `openCuratorInterface` открывает уже назначенный curator, а не создаёт назначение.

Хостовый setup добавляет активные addons/editable objects и attribute handlers. Если объект выделяется, но double click не открывает свойства, проверить `fn_warlordsMissionSetup.sqf` и `[NeroWL Zeus] attributes opened` на фактически назначенном curator. Пилоны зависят от dynamic loadout конкретного класса/мода; `%ALL` не создаёт отсутствующие свойства. Не обещать редактор пилонов для каждого самолёта без проверки этого класса.

Минимальная свежая игровая приёмка: включённый AI в лобби, обе стороны/слоты, HUD CP/сектора/меню, реальные покупки со списанием CP, постепенное пополнение до лимита, экипаж и выход с базы, no-air preset, пять бортов в air preset, изменение роли, задания только по своей разведке, гарнизоны, manual order сохраняется, Zeus свойства и respawn. Сравнить одинаковые source/package/installed hashes. Затем 10 минут поведения обеих сторон с FPS/frametime и нагрузкой. При откате восстанавливать addon и mission согласованно из одного backup manifest.

## 15. Документы и приоритеты продолжения

`AGENT_GUIDE_CURRENT_RU.md` — свежий вход для следующего агента. `AUDIT_20261007_RU.md` — воспроизводимые находки/исправления/доказательства и открытые риски. `AGENT_HANDOFF_RU.md` — исторические процедуры и §§19–36; читать по задаче, а не принимать старый hash за текущий. `CURRENT_STATUS.md` — краткий журнал. `dist/audit-*.json/tap/txt` — реальные outputs; backup profiles содержит private keys и не является публичным приложением к отчёту.

Приоритет сейчас (готовность GPT-OSS и context budget проверены 7.10): мигрировать 20 оставшихся тестовых контрактов; выполнить игровую приёмку новых ограничений закупки/посадки; затем CQ capture/CP/respawn/разведка. Вопрос пользователя «полный аудит» остаётся открытым до этих проверок; не завершать его ссылкой только на успешную упаковку.

## 16. Operations: редакторы отдельных сценариев, 12.10.2026

Сервис Operations работает отдельно на `127.0.0.1:18786`: воздух `/operations`, штурм/оборона `/ground`, фронт/снабжение `/campaign`. Их генераторы не запускают native Warlords или LLM мост. Общие функции Zeus, обязательные ACE/CBA, слоты ботов и библиотека относятся ко всем новым сборкам Operations.

Свежая инструкция кампании — `OPERATIONS_CAMPAIGN_2026-10-12_RU.md`; земля/лобби — `OPERATIONS_GROUND_2026-10-11_RU.md`. Для кампании установлен FRONT TEST 3, `c2ef943078f4`, запись `5fbba839-4303-4b7d-bdc5-7ca7441cfb77` версии 3. Source/PBO/installed и редактор проверены, движения грузовиков и продолжения в Arma ещё нет. Доказательства — `dist/operations-campaign-20261011/final-evidence.json`. Обновление Operations не закрывает перечисленные выше проверки Warlords.

Новые настройки создают новую область сохранения; обычное переименование и исправление кода сохраняют группу профиля. Самостоятельная копия получает новый ключ. Не смешивать конфигурацию редактора с игровым сохранением профиля сервера и не считать прежний GROUND TEST проверкой нового FRONT TEST 3. Сохранение стратегическое: полный мир, ранения ACE и объекты Zeus не сохраняются. Сначала читать свежий RPT и сопоставлять фактически загруженный пакет с исходниками.

## 17. Актуальное расширение Operations, 12.10.2026

Свежий редактор `campaign-expanded-v3`: http://127.0.0.1:18789/campaign?id=823be410-f43e-4cb7-ab58-344b1c23cc07 (revision 5). Предыдущий §16 отражает старую поставку, которую заменили отдельными пакетами EXPANDED. Основная инструкция и поручение продолжения: `OPERATIONS_EXPANSION_2026-10-12_RU.md`. Доказательства: `dist/operations-expansion-20261012/final-evidence.json`, `delivery.json`. Исходная пользовательская кампания revision 7 / 11 секторов сохранена; расширенная копия — 28 секторов, 20 мест/сторону, до 10 грузовиков, платное обслуживание/отдельный High Command, выбранные моды, полный каталог/категории, сбалансированная поддержка AI и перегрузки ACE для AI. Захват любого соседнего сектора без голосования. 22 готовых пресета в редакторе; не все карты устанавливались как PBO.

Текущие установленные Australia: Frontline `8df4f05aace6` (SHA256 3A412BFE7DDA470EFF4A76168984BE7941CBF07075FA98434024E33EA9CE9C20), AirBattle `f65b75a178d7` (2430E23AFB33C58A977613EC8DB4452342BACD9FC9CABB52AF23EC5F32CC2AFE), AssaultDefense `78ae5fdd0fd9` (F2742FAC41D69EA6B146CFB87E3F48349BF28817444CEEA88BDA56C4E24665C2). Source/PBO/installed и запись редактора совпали; во всех 40 мест. Тесты: Operations45/45, mod83/83, Control58/58, чистый SQF372 утверждения. Восстановимый архив 37 старых/промежуточных PBO проверен, в MPMissions 10 уникальных семейств. Игра не запускалась, движковая приёмка доставки/авиации/HC/G-forces/Zeus ещё нужна. Нельзя выдавать эти проверки за игровой результат или считать предыдущие игровые тесты подтверждением новой сборки. Спецоперации/HVT остановлены пользователем, автоматически не продолжать.


13.10.2026 — аудит фактической Australia grekk: 17 секторов, 11 отрядов/сторону; старая сессия 50 AI-покупок (8 ground/42 air), 86 NO ROAD, 1 доставка, 50 failed/23 successful saves. Исправлены очередь покупок и отдельные оплаченные экипажи, автономный цикл снабжения и дорожные повторы, известные наземные цели CAS/ударных вертолётов, Ту-95 с оператором Х-55Ш [4] и обязательным сопровождением, физическая вертолётная перевозка, марш/ПЗРК, сохранение виртуального ЗРК. Полный отчёт и continuation prompt: docs/CAMPAIGN_COMBAT_AUDIT_2026-10-13_RU.md. Доставлен COMBAT AI: NeroAI_Frontline_Australia_ada093e01e5e.australia.pbo SHA256 EE6A0EA2761089A61BC5987DA28A1CD87EEAF02C20D71159915F00B7DD95F747. Запись 3c726a2c-4550-4bb3-bb5a-0e8a9355d7ff revision 2, campaign-combat-v4 порт 18790; исходный grekk revision 3 и profiles.json не изменены, сохранён тот же namespace прогресса. Operations47/47, mod83/83, Control58/58, SQF67/111, PBO73 файла совпали; final-evidence: dist/campaign-autonomy-20261013/final-evidence.json. Arma к установке была закрыта извне; агент не запускал/не завершал игру. Реальные рейсы, наземные действия, высадки, попадание Х-55 и Continue ещё НЕ приняты в движке. Спецоперации остаются остановлены.


13.10.2026 — добавлена индивидуальная покупка пехоты в текущий отряд: «Магазин снабжения → Пехота в отряд» и отдельное действие. Классы из списка армии, серверная цена ceil(groupCost/groupSize), минимум 5; grekk 5 снаб./боец, WEST32/EAST27. Предел 12 AI с отделёнными экипажами, связанный местный склад/командир/безопасность, конечный резерв пополнений; исходная группа и её приказы сохраняются. Сохранение V4 с оплатой дополнительных бойцов читает V1–V3; прежний namespace сохранён. Доставлен COMBAT AI c336eeb96e9a SHA256 A5C037E303257B496EE665D04BFAF08D123B326CCCBCB37CA0F953773155E60D, 76 файлов PBO совпали. Редактор campaign-recruits-v5 порт 18791, запись 3c726a2c-4550-4bb3-bb5a-0e8a9355d7ff revision 2 неизменна; profiles.json неизменен. Operations48/48, mod83/83, Control58/58, SQF70/135. Отчёт/continuation: docs/CAMPAIGN_INFANTRY_2026-10-13_RU.md; evidence dist/campaign-infantry-20261013/final-evidence.json. Приёмка присоединения/управления бойцом и сохранения V4 в Arma ещё не выполнена, агент игру не запускал. Предыдущий ada093e01e5e архивирован.


13.10.2026 — STRATEGIC: 157 полных армейских пресетов, общая галочка модов, 22 компактные материковые карты 6–12 секторов, 4500 м AGL ручной парашют, переброска AI/местные покупки/стационарные позиции, FP‑5 (5×3 с, 1000 км/ч, 14 м, 50 м, 600/1200 с), Ту‑95 HE/оператор [4]/сопровождение/10 км/штатный аэродром/480/900 с, датчики/ПВО/перехват/ЛТЦ, сохранение V5. Запись cba3cb3d-2940-4964-861d-9586013f88ff r2, 12 секторов Australia, 20 мест лобби/сторону, 18792 campaign-strategic-v6. Доставлена миссия 917013c0bb29 SHA256 F95B8FB3BE1129415DE31E24F5D7405131386BD0950800FA64EB597E646DF5B1, 86 файлов; обязательный локальный аддон NeroStrategic SHA256 F85B5F0ECF20859D64C8DEFE754830590745A1832B52688645426614A4895621 (3 файла). Source/candidate/installed совпали; Operations51/51, mod83/83, Control58/58, SQF80/152. Старый COMBAT r2 и profiles.json хеши неизменны; отдельный namespace нового фронта не перезаписал прогресс. Актуальный последний RPT 2026-10-13_02-12-15 относится к cef5: 10 ground buys/0 air/0 expression errors, новая STRATEGIC в игре не принята. Arma при установке закрыта, агент не запускал/не завершал игру. Полный отчёт и continuation prompt: docs/CAMPAIGN_STRATEGIC_2026-10-13_RU.md; evidence dist/strategic-20261013/final-evidence.json; снимки docs/strategic-compact-map-20261013.png и docs/strategic-army-preset-20261013.png. Следующий gate: настоящий полёт/посадка/перезарядка Ту‑95, пять одиночных пусков FP‑5/перехват, движение/снабжение, ручной парашют, V5 Resume и Zeus/ACE. Спецоперации остаются остановлены.


13.10.2026 — исправлен отказ запуска локального NeroAI Strategic: узкое разрешение его пути + проверка PBO, читаемый UTF‑8/BOM вывод PS7/PS5.1. Исчезнувший необязательный Pinned Down не включается в текущий запуск, сохранённый выбор не стирается; недоступные обязательные моды блокируют сборку. Operations52/52, полный актуальный запрос104mods проверен с подменённым Steam без запуска игры. Сервер18792 перезапущен, PID14192, browser token обновляется штатно. PBO917013c0bb29, запись и profiles неизменны по SHA256. Отчёт/continuation: docs/OPERATIONS_LAUNCH_FIX_2026-10-13_RU.md; evidence backups/operations-launch-20261013/evidence.json. Следующий gate — фактический запуск кнопкой и свежий журнал.


13.10.2026 — STRATEGIC запуск принят пользователем («Да, миссия запустилась») и свежим RPT16:52:01: все104мода, d021f2e3ec60, 12секторов/22отряда, COMMANDER READY и Zeus ASSIGNED. Исправлены внешний Cruise/родитель, расчёт аэродромов, пустой CIM argv, 90с ожидание и компактный файл параметров3131байт вместо обрезанной строки, из-за которой отсутствовал CBA. Миссия SHA256 A66C24F9CC9FF6A5F3095DFC96A7499D8175E9D30D1C81529DB7D550A6DCE657 (87файлов), аддон E20A9843D6D245DADFA38F0B84AF7A41AA87131F2322C1E435A16C68CAE5DC7B; source/installed совпали. Operations52/52, SQF81/21pure/159assertions. После старта выявлены SAVE valid=false, ошибки config/effects CruiseTrack и ROAD FAIL; они НЕ исправлены и не приняты. Игра оставлена работающей. Отчёт/продолжение docs/STRATEGIC_START_REPAIR_2026-10-13_RU.md; evidence backups/strategic-cruise-fix-20261013/final-evidence.json. Старые записи выше — история, текущие артефакты и границы приёмки в новом отчёте.


13.10.2026 — исправления перевозки/FP‑5/авиации подготовлены: общие Transit/Boarding gates, физическая посадка в CAR/APC, площадки и удержание партии вертолёта, уважение staging, запрет конфликтующих покупок, патруль фронта и стабильные ключи авиационных задач, ограниченные точки Ту‑95/сопровождение/ACE pilot coefficient/телеметрия гибели, native ArtilleryShellFired для цели FP‑5 с коррекцией 14 м, безопасный выход ракеты и отсроченный fixed-wing radar proxy с проверкой оружейного попадания, heap дорожного A*. Кандидат7406a1293b74 SHA256 EF3EC95D3D4197F24BEB6FD294504F8842A5CF77D6956D624AD878A3EAB68136 (93 файла), локальный аддон DD5B1D164708361A3D25762B41C8BAB2F64CED46E8428EDC72B3079709E47819 (5 файлов). Operations55/55, SQF87/26pure/184assertions; содержимое PBO/source совпало. НОВАЯ МИССИЯ НЕ УСТАНОВЛЕНА: объединённая команда установки и перезапуска редактора отклонена automatic approval review, blocked by policy; подробной причины нет. Процесс18792/13316 остался прежним, в MPMissions d021f2e3ec60; аддон в проектном dist уже собран. Arma закрыта. Запись r2/profiles/namespace сохранены. Подробности и границы приёмки docs/TRANSPORT_FP5_AIR_REPAIR_2026-10-13_RU.md; evidence backups/transport-fp5-air-20261013/final-evidence.json. Новая движковая приёмка и невалидное автосохранение остаются открытыми; снимок отказа теперь сохраняется в missionNamespace для диагностики. Спецоперации не продолжать.


14.10.2026 — сеть ПВО/РЛС реализована в исходниках frontlineCampaign: окончательная связь 3 км, свежие реальные контакты и круг РЛС для стационарных SAM, дальность пушек/мобильной ПВО не увеличена, собственные стационарные датчики +500 м, сетевой боезапас с сохранением остатка, программируемый подрыв/физические осколки JC Skynex. 961 определение/234 производных стационарных класса; Zeus: [NeroAI AD]. Кандидат bcec8d06b50a SHA256 275E4201778E23FB439760E29FC10FF26B319FC7C807A2BF9CB164B7A26E76CE, дополнительный аддон 6cda786f4c51 SHA256 C0D522BB4D477A61700328734D17507B3765D98A7F1B94BED492B320C4B2FABB. Operations58/58, mod83/83, SQF92/28pure/203assertions; PBO совпали с source. НЕ УСТАНОВЛЕНО/НЕ ПРИНЯТО В ИГРЕ: прежний d021f2e3ec60 и редактор18792/PID13316 сохранены. Полный охват требует производных классов, другие шаблоны операций не подключены; штатные модовые алгоритмы/ACE и мультиплеерная стрельба требуют движковой проверки. Отчёт docs/AIR_DEFENSE_NETWORK_2026-10-14_RU.md, evidence backups/air-defense-network-20261014/final-evidence.json. Старый отказ SAVE valid=false остаётся открытым.


14.10.2026 — по прямому запросу пользователя собран отдельный мод NeroAI Operations — Editor Test (3 PBO: AirDefense, Strategic, Editor) и установлен НОВОЙ папкой H:/SteamLibrary/steamapps/common/Arma 3/@NeroAI_Operations_Test_20261014. Основной MPMissions/старый фронт не заменялся, сервер18792 не перезапускался, Arma не запускалась. Eden F5 opt-in модуль ПВО/РЛС/Skynex/радарных целей крылатых ракет/ЛТЦ/F18/Zeus; полный фронт представлен готовыми шаблонами. 19 шаблонов (17 фронтов + airBattle + assaultDefense) скопированы в Documents/Arma 3/missions; persistence=0 и отдельные ключи. Проверки editor2/2, 17 функций parse-only, 19 validate-operation; 1716 файлов шаблонов и 3 PBO installed/source совпали, NeroEditor SHA256 29890CA27FF4342F1E564865E277AA32F2901FC7C97B6D78D421100EFFEDD40B. Полный тестовый мод требует текущие103 внешних мода, старый отдельный Strategic/AirDefense выключить. Не автономный vanilla-only мод. 5 карт исключены из шаблонов из-за land-validation, свободный модуль доступен на любой карте. Game acceptance=false: ещё проверить F5, embedded scenarios, SP/MP/Zeus/стрельбу. ZIP dist/editor-test/NeroAI_Operations_Test_20261014.zip; evidence dist/editor-test/installed-evidence.json; руководство docs/EDITOR_TEST_MOD_2026-10-14_RU.md. Этот новый мод установлен по свежему запросу; прежний основной candidate bcec8d06b50a в MPMissions всё ещё не установлен.


14.10.2026 — подготовлена архитектура следующего этапа LLM-командования: docs/ADR-LLM-BOT-CONTROL-2026-10-14_RU.md (Proposed) и LLM_COMMAND_PROMPT_DRAFT_RU.md. Цель/готовый навык/точечная подзадача, реестр способностей и текущих фактов, серверный арбитр ресурсов и lease/epoch, подтверждения STARTED и наблюдаемый результат, дедупликация/устаревание, очередь с приоритетами и локальный fallback без LLM. Опирается на actual campaignDoctrine/Buy/Ride/Lift/AirTask/AirDefense и bridge protocol. Это документация, новый протокол НЕ реализован и НЕ подключён, latency интервалы — ориентиры, не измерения. Первый этап реализации — shadow-адаптер без приказов и проверка контрактов/арбитра до действующего управления. Установленные моды, сценарии, службы и сохранения не изменены.


14.10.2026 — исправлено подтверждённое RPT падение загрузки тестового мода: NeroAirDefense/config.cpp M_Titan_AA_static Member already defined. Генератор повторял forward объявления CfgAmmo/CfgMagazines; объявления дедуплицированы, введена строгая проверка до упаковки и воспроизводящий тест. Новый AD866ad802bec2 SHA256 102D11094AC86C36C7E6675042D131A9F17AAC0D9F1B4D1A86331C2F86E7263B установлен в существующую отдельную папку Operations_Test_20261014 при закрытой Arma, старый сохранён в backups/editor-crash-20261014. Миссии и Workshop неизменны. Новый запуск не выполнен/не принят. Отчёт docs/EDITOR_CRASH_FIX_2026-10-14_RU.md.


14.10.2026 — повторное падение Editor Test из-за Undefined base Player исправлено. Живая загрузка выявила сброс родителей при объявлении исходных башен: этот промежуточный вариант заменён. Итог AD ebc6cd7b6d74 использует нетронутые исходные башни и локальную замену ракетного оружия/магазинов; requiredAddons только фактические source patches/ACE missileguidance. Установлены AD 94C6679CF348589DECEB6561607454E8A3EEF9648FE21AE62AB8C70D8515F3A8 и Editor FEAB6AE53F0F153460DADFFA0183CF7BC336B83439E35A2190991574BA019AA0. Operations60/60/editor2/2/SQF92/203. RPT01-33-55: 0 fatal, 0 parent changes NeroAD, 0 missing deps NeroAD; пользователь подтвердил главное меню. Игра оставлена открытой, combat acceptance=false. Сервер/основной MPMissions неизменны; обновлены 17 тестовых ADMagazine. Отчёт docs/EDITOR_SECOND_CRASH_FIX_2026-10-14_RU.md; evidence backups/editor-crash-20261014-second/final-evidence.json.
