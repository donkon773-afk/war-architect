# War Architect

[Русский](#russian) · [English](#english) · [Моды / Mod compatibility](docs/TESTED_MODS.md)

<a id="russian"></a>

## Русский

War Architect — проект для Arma 3: единый центр запуска, редактор военных сценариев, библиотека армий, тактическое поведение ИИ и системы снабжения.

**NeroAI** сохраняется как отдельный модуль управления через локальные LLM. Для сценариев без LLM предусмотрены штатный и тактический режимы ИИ.

## Возможности

- Редактор карт, баз, секторов, гарнизонов и связей между точками.
- Сохраняемые сетапы пехоты, техники и вооружения, национальные и специализированные пресеты.
- Warlords, воздушные сражения, штурм и оборона, кампания «Фронт и снабжение».
- Покупки, снабжение, конвои, сохранение прогресса кампании и опциональная физическая доставка подкреплений.
- Тактический ИИ, взаимодействие групп, движение техники и ремонт.
- Экспериментальные механики ракет, РЛС и ПВО в DevMode.
- NeroAI: мост к LM Studio и раздельные маршруты моделей для сторон.

Наличие механики в исходниках и успешная сборка не означают, что все сочетания модов проверены в игре. Актуальные ограничения и результаты проверок описаны в документации.

## Моды и проверенные конфигурации

Подробный [перечень модов и уровней проверки](docs/TESTED_MODS.md) разделяет игровые сессии, загрузку модов, аудит установленного контента и проверку сборок. Основной набор включает CBA A3, ACE, RHS, CUP, 3CB Factions, Zeus Enhanced и LAMBS Danger; дополнительные ракетные механики используют FP-5 Flamingo, Blastcore Murr TT и FMC PACK. Это перечень исследованного окружения, а не гарантия совместимости любой комбинации.

## Структура

| Каталог | Назначение |
| --- | --- |
| `addons/` | SQF-модули и конфигурация дополнений |
| `control-center/` | Интерфейс, редакторы и локальные HTTP-службы |
| `bridge/` | Модуль NeroAI для обмена с LLM |
| `missions/` | Исходники миссий |
| `tools/` | Инвентаризация, генераторы, сборка и проверка PBO |
| `tests/` | Проверки JavaScript, SQF и контрактов редакторов |
| `docs/` | Разработка, диагностика и результаты проверок |
| `dist/` | Индексы установленного контента и результаты сборок; состав зависит от экспорта |

## Запуск

Проект разрабатывается на Windows. Требуется Node.js 20 или новее, PowerShell, установленная Arma 3 и моды выбранного сценария. Для LLM дополнительно нужны LM Studio и INIDBI2; для части боевых механик — ACE/CBA и соответствующие моды техники.

1. Скопируйте `bridge/neroai3.config.example.json` в `bridge/neroai3.config.json` и укажите свои настройки при использовании NeroAI.
2. Проверьте пути к Arma, Workshop и внешним инструментам. В текущих скриптах ещё есть пути машины разработчика; перенос на другой компьютер требует их настройки.
3. Запустите `Start-War-Architect.cmd`. Старый `Start-NeroAI-Warlords.cmd` сохранён для совместимости.
4. В центре выберите сценарий, настройте армии и карту, сохраните и соберите миссию.

Другой проект Antistasi рядом с этим каталогом не обязателен для первичной настройки центра. Для запуска его отдельного адаптера нужны соответствующие исходники и установка.

Для регенерации адаптаций Warlords сначала извлеките локальные исходники из своей установки игры:

```powershell
node tools/extract-native-warlords.js "H:\SteamLibrary\steamapps\common\Arma 3"
```

Укажите свой путь. Файлы попадут в исключённый из Git каталог `research/native/`. Растровые фоны карт можно восстановить инструментами `tools/extract-map-background.js` и `tools/build-all-map-backgrounds.js` из установленного контента; в исходном экспорте остаются геометрические данные карт.

## Проверки

```powershell
npm test
npm run test:control
npm run test:operations
```

Дополнительные проверки интерфейса используют Playwright и Chrome. SQF-проверки используют SQF-VM. Часть интеграционных тестов требует локальную Arma и индексы установленных модов. Перечень конкретных проверок указан в `package.json` и `tests/`.

## Названия модулей и режимов

- **War Architect** — весь проект.
- **NeroAI** — LLM-модуль.
- **Sector Command**, **Frontline Forge**, **BattleGrid**, **Field Command** — резерв названий для будущего оформления режимов; это не обещание отдельных реализованных продуктов.

Внутренние имена `NeroWL`, `NeroOP` и `NeroAI_fnc_*` сохранены для совместимости существующих миссий и сохранений.

## Что не публикуется

Личные ключи, рабочие профили подключения, сеансы служб, журналы, дампы, резервные копии и архивы сборок исключаются. Примеры конфигурации не содержат действующих ключей. Игра и Workshop-моды устанавливаются отдельно.

Права на сторонний контент и адаптированные исходники принадлежат их авторам. Общая лицензия на весь набор сторонних компонентов этим репозиторием не предоставляется; см. `THIRD_PARTY.md`.

---

<a id="english"></a>

## English

War Architect is an Arma 3 project combining a unified launcher, a military scenario editor, reusable army presets, tactical AI behavior and logistics systems.

**NeroAI** remains a separate module for control through local large language models (LLMs). Scenarios can also use standard Arma AI or the project's tactical AI mode without an LLM.

### Features

- A map editor for bases, sectors, garrisons and connections between objectives.
- Saved infantry, vehicle and equipment setups, including national and specialist presets.
- Warlords, air battles, assault and defense, and the Frontline and Supply campaign.
- Purchases, supplies, convoys, campaign persistence and optional physical reinforcement delivery.
- Tactical AI, group coordination, vehicle movement and field repairs.
- Experimental missile, radar and air-defense mechanics available through DevMode.
- NeroAI: an LM Studio bridge and separate model routing for opposing sides.

A feature being present in the source or passing build checks does not mean that every mod combination has been verified in game. The documentation records the evidence and remaining limitations.

### Mods and verification

See the detailed [mod environment and verification matrix](docs/TESTED_MODS.md#english). It distinguishes actual mission sessions, mod loading, installed-content audits and build checks. The main environment includes CBA A3, ACE, RHS, CUP, 3CB Factions, Zeus Enhanced and LAMBS Danger. Additional missile mechanics use FP-5 Flamingo, Blastcore Murr TT and FMC PACK.

These are documented test environments, not a blanket compatibility guarantee or a requirement to load every listed mod together.

### Project structure

| Directory | Purpose |
| --- | --- |
| `addons/` | SQF modules and addon configuration |
| `control-center/` | User interface, editors and local HTTP services |
| `bridge/` | The NeroAI LLM bridge |
| `missions/` | Mission source files |
| `tools/` | Content inventory, generators, PBO packaging and validation |
| `tests/` | JavaScript, SQF and editor-contract tests |
| `docs/` | Development notes, diagnostics and verification reports |
| `dist/` | Installed-content indexes and build output; contents depend on the export |

### Getting started

Development currently targets Windows. You need Node.js 20 or later, PowerShell, an installed copy of Arma 3 and the mods required by your selected scenario. NeroAI additionally needs LM Studio and INIDBI2. Some combat mechanics require ACE/CBA and the relevant vehicle or weapon mods.

1. Copy `bridge/neroai3.config.example.json` to `bridge/neroai3.config.json` and configure it if you intend to use NeroAI.
2. Check the paths to Arma, Workshop content and external tools. Some scripts still contain development-machine paths; moving to another computer requires adjusting them.
3. Run `Start-War-Architect.cmd`. The older `Start-NeroAI-Warlords.cmd` is retained for compatibility.
4. Select a scenario in the Control Center, configure armies and the map, then save and build the mission.

A neighboring Antistasi project is not required for initial Control Center setup. Its separate adapter requires the corresponding source project and installation.

Before regenerating native Warlords adaptations, extract the reference functions from your own game installation:

```powershell
node tools/extract-native-warlords.js "H:\SteamLibrary\steamapps\common\Arma 3"
```

Replace the path with your own. The extracted files go into `research/native/`, which is excluded from Git. Raster map backgrounds can be regenerated from installed content using `tools/extract-map-background.js` and `tools/build-all-map-backgrounds.js`. The source export retains map geometry data.

### Checks

```powershell
npm test
npm run test:control
npm run test:operations
```

Additional UI checks use Playwright and Chrome. SQF checks use SQF-VM. Some integration tests require a local Arma installation and indexes of installed mods. See `package.json` and `tests/` for the individual checks.

### Project and module names

- **War Architect** — the overall project.
- **NeroAI** — the LLM module.
- **Sector Command**, **Frontline Forge**, **BattleGrid** and **Field Command** — names reserved for possible future mode branding; they do not represent separate completed products.

Internal names such as `NeroWL`, `NeroOP` and `NeroAI_fnc_*` are retained for compatibility with existing missions and saves.

### Publication scope

Personal keys, active connection profiles, service sessions, logs, dumps, backups and build archives are excluded. Example configuration files contain no active credentials. Arma 3 and Workshop mods must be installed separately.

Third-party content and adapted source files remain the property of their respective authors. This repository does not grant a single license covering all third-party components. See [THIRD_PARTY.md](THIRD_PARTY.md).
