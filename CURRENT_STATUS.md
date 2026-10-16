# NeroAI Warlords and Control Center — current status

Updated 2026-10-05, 19:18 Europe/Kiev. Historical snapshot preserved in
`docs/status-before-control-center-20261005.md`; Antistasi source was not modified.

## Mini-app

Desktop: `C:\Users\Admin\Desktop\NeroAI Control Center.lnk`.
Local panel: http://127.0.0.1:18775/ (fallback through 18785).
Guide: `control-center/README_RU.md`. Screenshot: `docs/control-center.png`.
The shortcut uses the verified bundled PowerShell 7 runtime and an ASCII wrapper.

Selection: Antistasi/Warlords; one/two LLM; primary/tactical node and model;
model discovery; real completion preflight; temperature/output limit; Arma profile;
ACE; Warlords Dev; 26 native/custom gameplay parameters; saved presets; additional nodes.
Current saved preset: Australia · Mac · Dev, GPT-OSS 20B, donko, temperature 0.9,
900 output tokens, 10000 CP, nine subordinates plus commander, FT players+AI,
air cap five, ordinary skill and balanced aggression. User changed skill/aggression
to 2/2 in the lobby of the current game, confirmed in RPT. Lobby overrides work.

Derived configurations are private under `control-center/data/runtime`; original
bridge configuration files are unchanged. Single mode removes old RTX dependencies.
Vision is disabled pending a real camera source. Selecting a node does not install
or load a remote model. Game uses Steam, ordinary player client; no dedicated/HC.
Live-game guard prevents overwrites and duplicate launch; verified API rejection.
Selected Warlords defaults regenerate all five mission packages. Prior installed
files are backed up before deployment. Only known NeroAI bridges are restarted.

## Current live acceptance

Launch recorded 19:07:31: Warlords, single, donko, 17 mods, bridge PID 24296.
RPT: `C:\Users\Admin\AppData\Local\Arma 3\Arma3_x64_2026-10-05_19-07-42.rpt`.
ACE 3.21.2 is loaded, including installed RHS/CUP compatibility components.
Mac discovery returned seven models; real completion succeeded before launch.

- User confirmed **sectors, HUD, purchase menu, normal spawn** in Australia.
- 19:10:42 open ground: WEST [15878,34470,0], EAST [34900,13195,0], clearance 100m.
- 19:11:11 READY: 13 hubs, 20 commanders, client marker RECTANGLE, actual HUD check.
- 19:11:17 EAST 10 AI; WEST nine AI plus player; disabledAI=0.
- 19:11 onward Mac GPT-OSS returns correlated enemy plans. Some invalid actions
  are rejected to NO_ACTION by the existing allowlist; model text is never executable SQF.
- 19:15:18 boarding verified 5/5 and 2/2 members mounted. This confirms physical
  use of vehicles; it does not prove aircraft combat or nine-subordinate recruitment.

The previous missing interface was caused by a BOOL Border custom attribute;
native WLSectorsCommonInit expected numeric meters and aborted. Border is now
SCALAR 200. Readiness requires both server arrays and client markers/menu/FSM/HUD.
Australia includes Perth, Willcania, Toowoomba, Coober Pedy and Pine Gap.

## Prepared update, not installed into the current match

The live RPT revealed **Attempt to override final function - bis_fnc_wlaipurchases**.
Thus current AI squads still use the native four-subordinate limit even though
the lobby setting is nine. The misleading preInit assignment has been removed.
The new addon config modifies the exact installed path
`CfgFunctions/A3_Warlords/Warlords/WLAIPurchases` before final compilation;
dependency `A3_Functions_F_Warlords` ensures ordering. Its FSM removes only the
three hard-coded four-man caps and the crew-trimming behavior; CP/delivery rules
and native AICore/fast travel remain. The new patch requires a fresh game process.

Current live addon SHA256:
`05EBCD5E2377EBD18EFFFF5E8ADBE209A6A17559B4A8B92B75712C9C9C90F2E0`.
Next-launch candidate `dist/candidate/NeroWL.pbo`, 70 files, 365767 bytes:
`8F12B800A28DA76072AAC08C6DCA08CB9F1C05A6CE5C54214EF6BDD7E093C20E`.
Candidate contents verified against source; it is intentionally not copied over
the open game. Control Center installs it after the user closes Arma and launches again.

Current installed main mission SHA256:
`1B6099E748F27722F943F3EFEF8790638889DD9A57EB136DB3DC377F275D661C`.
Next-source main mission `dist/NeroAI_Warlords_Australia_RHS20.australia.pbo`:
`1A2D4121DB88890F0BC4A67E8E20E1B8DD7D663C10437C165B49147D972A3100`.
Four updated archive ZIPs/PBOs/source are in `dist/criteria-release`;
original user archives remain unchanged. Each has 20 commander slots;
Australia 11 capture sectors, other maps eight. No live acceptance for other maps yet.

## Validation and next acceptance

Bridge tests 7/7, mission tests 8/8, mini-app config tests 5/5.
Source/package manifests and hashes checked. UI: scenario and one/two model switches,
preset save, discovery, live-game detection checked; actual Warlords launch succeeded.
The launch helper now uses file-backed output so Steam cannot keep a pipe open and
leave the panel indefinitely in a launching state. New helper behavior needs the next
fresh launch; current game is unaffected.

Next game acceptance: configured native purchase path true, no final-override warning,
actual nine-subordinate recruitment at affordable CP, physical boarding without infantry
deletion, native AI fast travel, up to five aircraft with costs/services/finite ammunition,
and gameplay FPS. Antistasi and two-model routes have configuration tests, but are not
live-tested through the new mini-app. Zeus and all CBA settings still need visual checks.

## 2026-10-05 — combined arms/editor update

Installed while Arma was closed. No fresh gameplay acceptance. The earlier hashes and runtime notes above are historical.
Current addon SHA256: 78EB1A53CCAF6371BA53D27461C96B9974753BF043BDCABF5AA1C4908AE0E343.
Main Australia mission SHA256: 03029F63AE44DFAA6682E82ACE80A75262D7C37C61C28F5ABDD03856D5ED629D.
Backup: backups/combined-arms-20261005-224935; install record: dist/combined-arms-install.json.
New editor: native-side factions, selected assets/providers, pre-game instructions (Warlords), 10/12/16 slots per side including players. Preset Australia · Mac · 16 · авиация: single Mac, donko, 9 subordinates, AI+player fast travel, airLimit 5.
New ASSIGN_ROLE/AIR_TASK protocol, bounded army snapshot, aircraft BUY dispatch fix, paid transport/CAS/intercept/escort paths and boarding-progress lock. Implemented and packaged; physical air gameplay, native AICore/transport interaction, loadouts and FPS remain unverified.
24 targeted tests pass; 4 selected static checks pass. Full historical suite: 126 of 146 pass, 20 fail; see dist/legacy-test-results.txt. Do not describe all tests as green.
Detailed editing/build/install/rollback/acceptance guide: docs/AGENT_HANDOFF_RU.md.

## 2026-10-06 — city controls, allied LLM, catalog, console and Zeus

Installed after Arma closed; no fresh game launch/engine acceptance.
Addon SHA256: 376F5DB64A66EB1C2E162ADF8FB6A1F42B830762C7442099D9481CFB17B8D476.
Main Australia SHA256: 6737976A528CD6B69DB0A284735C14C52B69F96F25B9C8A8CEC9225456CCBCCE.
Backup: backups/city-controls-20261006-001706; manifest: dist/city-controls-install.json.
Separate WEST/EAST/GREEN native garrison caps; allied off/manual/auto with shared/separate LLM route; 105-mod catalog with pagination, ships/statics and 512 classes per side; bounded/redacted app journal and desktop CMD viewer; expanded Zeus object registration/edit permissions using installed ZEN attributes/pylons.
28 targeted tests and 4 selected static checks pass. Historical full-suite failures remain separately documented. New bridge logging takes effect on next launch. Detailed implementation/limitations/acceptance: docs/AGENT_HANDOFF_RU.md section 16.

## 2026-10-06 — observed long initialization, candidate optimization

Live RHS20 session reached native readiness after 217 seconds: 13 sectors, both bases, native client markers; EAST=10/WEST=9 bots. RPT Arma3_x64_2026-10-06_00-26-34.rpt. Not a permanently failed mission.
Candidate: filter native uniform compatibility queries to actual public uniforms and delay Zeus catalog until Warlords sector/base readiness. 13 targeted and 4 static checks pass; source/package verify pass. Candidate hash DD4D3B540E29BB04DD5E048DF3F70CAC368AD9542E71CEDF2C3FBBB4127FB94B. Game remains open, installed addon unchanged; next app launch installs candidate. No measured latency improvement yet. Handoff section 17.

## 2026-10-06 — Zeus attribute dialog candidate

User: objects selectable but no properties on double click. Candidate adds one-time UI handlers to assigned host curator, preserving ZEN handlers and guarding duplicate dialogs, permits all non-player default attributes. Candidate hash 17768929D6DFEF1D58F06587DBF8AF7E7E3247589A2C65AED62C980D1558D047; 13 targeted/4 static pass, PBO source match. Still not installed into running Arma. Hotfix: tools/zeus-attributes-hotfix.sqf, local host console. Gameplay acceptance pending; handoff section 18.

## 2026-10-06 — read-only live behavior audit 00:34–00:47

Both BLUE and RED receive prism-ml/bonsai-27b responses from Mac. Physical boarding has full/partial/failure evidence; paid aircraft purchases exist, physical air combat remains unproven. Main issues: SET_SECTOR only watches rather than captures despite LLM intent, repeated blue protected-base air aborts, Tank inheritance classifies BMP/Bradley as TANK, repeated boarding failures, undefined _category native purchase menu spam. No game/config edits or restarts in this audit. Evidence/report: docs/RUNTIME_BEHAVIOR_20261006_RU.md; bounded event statistics: dist/runtime-audit-20261006.json.

## 2026-10-06 01:00 — session fixes installed after user closed game

Current addon SHA256 331731DC85D7BE502987D3555CC26A71ED62AA2256883F0E0D79D40AC5811C80 (79 files / 423478 bytes). Main mission EF08FB9F11E41BCF840A51124C65093565ADA0A6B5E75855B4933F28ECCFECB8. All five missions + runtime copies updated. Manifest dist/session-fixes-install.json; backup backups/session-fixes-20261006-010007; installed/source verify passes.
Includes Zeus handlers, uniform scan optimization, healthy AI paid-plane landing recovery to home/READY, no default airport0, alternate safe native sector for protected-base air task, common MBT/APC classification, bounded partial-boarding attempts, explicit SET_SECTOR watch semantics in prompt, native purchase-category guard. 31 targeted / 4 selected static checks pass; no new engine acceptance. Game not launched. Bridge prompt will update on next app launch. Handoff section19 is current; previous candidate-only statuses are historical.

## 2026-10-06 — catalog presentation

App only: expandable per-mod WEST/EAST equipment sections, 60 rows per mod page, names only on equipment rows, Russian category labels, equipment-only mod filter. Class IDs preserved internally/search for selection/build. Resolved1831 labels using installed stringtables;315 fallback readable model identifiers, not official names. Catalog selection remains intact. 16 focused tests passed; UI verification recorded separately. PBO unchanged from session-fixes installation.

## 2026-10-11 — NeroAI Operations / Australia air battle

Separate Operations constructor and standalone finite air battle implemented; user chose pilot as the primary role. Dedicated loopback service on 18786, desktop NeroAI Operations shortcut, side fleets/reset/undo/saved operations/map entry points, bounded reinforcements and score/time victory. Native Arma aviation AI; no LLM bridge required in this first template.

AIR TEST PBO installed under a new name: NeroAI_AirBattle_Australia_e5b1aa557abf.australia.pbo, SHA256 596DAD316F24BF7E08E7CCDA03010A9503601248321942B3F0BEF40FBEE09913, 20 files / 30095 bytes. Source match and repeat packaging verified. Original operation record and private profiles preserved. Operations tests 8/8; production pure SQF logic 255 assertions / 14 parsed files; existing Control Center 58/58 and main suite 83/83 passed.

Launcher defect fixed: add noLauncher/win64/useBE and verify actual game process/mods before reporting success. User confirmed main menu from their existing 104-mod launcher profile and reported loading/cockpit for AIR TEST. Live RPT 17:28:25 confirms mission INIT, beyond this engine acceptance remains open. Corrected 12-mod Operations button has a behavioral mock regression; fresh real button launch is pending. Running Arma was not restarted.

Details, limits and continuation: docs/OPERATIONS_AIR_AUSTRALIA_2026-10-11_RU.md. Verification manifest: dist/operations-air-20261011/installed.json. UI screenshot: docs/operations-map-20261011.png.

Live acceptance update 17:30: RPT confirms PILOT READY / CLIENT IN COCKPIT for F/A-18E, READY aircraft=20, enemy credit and reinforcement 0:9. Runtime evidence: dist/operations-air-20261011/runtime-observation.json and runtime-air.txt. Full combat/respawn/end acceptance and clean 12-mod launch remain pending. Existing 104-mod profile emits MissileFire particle, ACE fragment and aircraft destruction-effect errors; exact mod conflict not yet isolated.

## 2026-10-11 — F/A-18 cockpit and helmet display

F18 FIX mission 493a523c472c actually loaded at 17:42:05; RPT confirms AVIONICS READY with native cockpit/mfd systems. User reports incomplete UI, specifically missing helmet display. Installed mod inspection identifies an independent HMD gate: Switch_hmd, numeric MFD user48 and FA18_JHMCS. New guarded local airHelmet helper initializes all three and exposes a manual helmet toggle; subsequent player switch choices are preserved.

Separate F18 HUD copy installed: NeroAI_AirBattle_Australia_0a875c490807.australia.pbo, SHA256 1BEABC82A43CDE8DFA5AAECF7A7AC943125467B789DE512DC7F4BD8314AF4F76, 22 files / 33959 bytes, contents match source. Operations 10/10, 16 SQF files parsed, 255 pure assertions passed. Native HMD config/button contract checked against the installed addon. Source/PBO validation is complete; actual helmet rendering and toggle/respawn acceptance await user test. Existing mission/addon packages and game process were not replaced or restarted. Manifest: dist/operations-air-20261011/fa18-hud-installed.json. Evidence: fa18-hud-observation.json. Current guide: docs/OPERATIONS_AIR_AUSTRALIA_2026-10-11_RU.md.

User acceptance update: user confirmed "Да, прицел шлема появился" after selecting F18 HUD and checking while looking away from the forward HUD. Helmet rendering is accepted by user observation. Manual toggle, helmet restoration on respawn and full battle completion remain unverified; this confirmation is limited to the reported missing helmet display.


14.10.2026 — сеть ПВО/РЛС реализована в исходниках frontlineCampaign: окончательная связь 3 км, свежие реальные контакты и круг РЛС для стационарных SAM, дальность пушек/мобильной ПВО не увеличена, собственные стационарные датчики +500 м, сетевой боезапас с сохранением остатка, программируемый подрыв/физические осколки JC Skynex. 961 определение/234 производных стационарных класса; Zeus: [NeroAI AD]. Кандидат bcec8d06b50a SHA256 275E4201778E23FB439760E29FC10FF26B319FC7C807A2BF9CB164B7A26E76CE, дополнительный аддон 6cda786f4c51 SHA256 C0D522BB4D477A61700328734D17507B3765D98A7F1B94BED492B320C4B2FABB. Operations58/58, mod83/83, SQF92/28pure/203assertions; PBO совпали с source. НЕ УСТАНОВЛЕНО/НЕ ПРИНЯТО В ИГРЕ: прежний d021f2e3ec60 и редактор18792/PID13316 сохранены. Полный охват требует производных классов, другие шаблоны операций не подключены; штатные модовые алгоритмы/ACE и мультиплеерная стрельба требуют движковой проверки. Отчёт docs/AIR_DEFENSE_NETWORK_2026-10-14_RU.md, evidence backups/air-defense-network-20261014/final-evidence.json. Старый отказ SAVE valid=false остаётся открытым.


14.10.2026 — по прямому запросу пользователя собран отдельный мод NeroAI Operations — Editor Test (3 PBO: AirDefense, Strategic, Editor) и установлен НОВОЙ папкой H:/SteamLibrary/steamapps/common/Arma 3/@NeroAI_Operations_Test_20261014. Основной MPMissions/старый фронт не заменялся, сервер18792 не перезапускался, Arma не запускалась. Eden F5 opt-in модуль ПВО/РЛС/Skynex/радарных целей крылатых ракет/ЛТЦ/F18/Zeus; полный фронт представлен готовыми шаблонами. 19 шаблонов (17 фронтов + airBattle + assaultDefense) скопированы в Documents/Arma 3/missions; persistence=0 и отдельные ключи. Проверки editor2/2, 17 функций parse-only, 19 validate-operation; 1716 файлов шаблонов и 3 PBO installed/source совпали, NeroEditor SHA256 29890CA27FF4342F1E564865E277AA32F2901FC7C97B6D78D421100EFFEDD40B. Полный тестовый мод требует текущие103 внешних мода, старый отдельный Strategic/AirDefense выключить. Не автономный vanilla-only мод. 5 карт исключены из шаблонов из-за land-validation, свободный модуль доступен на любой карте. Game acceptance=false: ещё проверить F5, embedded scenarios, SP/MP/Zeus/стрельбу. ZIP dist/editor-test/NeroAI_Operations_Test_20261014.zip; evidence dist/editor-test/installed-evidence.json; руководство docs/EDITOR_TEST_MOD_2026-10-14_RU.md. Этот новый мод установлен по свежему запросу; прежний основной candidate bcec8d06b50a в MPMissions всё ещё не установлен.


14.10.2026 — подготовлена архитектура следующего этапа LLM-командования: docs/ADR-LLM-BOT-CONTROL-2026-10-14_RU.md (Proposed) и LLM_COMMAND_PROMPT_DRAFT_RU.md. Цель/готовый навык/точечная подзадача, реестр способностей и текущих фактов, серверный арбитр ресурсов и lease/epoch, подтверждения STARTED и наблюдаемый результат, дедупликация/устаревание, очередь с приоритетами и локальный fallback без LLM. Опирается на actual campaignDoctrine/Buy/Ride/Lift/AirTask/AirDefense и bridge protocol. Это документация, новый протокол НЕ реализован и НЕ подключён, latency интервалы — ориентиры, не измерения. Первый этап реализации — shadow-адаптер без приказов и проверка контрактов/арбитра до действующего управления. Установленные моды, сценарии, службы и сохранения не изменены.


14.10.2026 — исправлено подтверждённое RPT падение загрузки тестового мода: NeroAirDefense/config.cpp M_Titan_AA_static Member already defined. Генератор повторял forward объявления CfgAmmo/CfgMagazines; объявления дедуплицированы, введена строгая проверка до упаковки и воспроизводящий тест. Новый AD866ad802bec2 SHA256 102D11094AC86C36C7E6675042D131A9F17AAC0D9F1B4D1A86331C2F86E7263B установлен в существующую отдельную папку Operations_Test_20261014 при закрытой Arma, старый сохранён в backups/editor-crash-20261014. Миссии и Workshop неизменны. Новый запуск не выполнен/не принят. Отчёт docs/EDITOR_CRASH_FIX_2026-10-14_RU.md.


14.10.2026 — повторное падение Editor Test из-за Undefined base Player исправлено. Живая загрузка выявила сброс родителей при объявлении исходных башен: этот промежуточный вариант заменён. Итог AD ebc6cd7b6d74 использует нетронутые исходные башни и локальную замену ракетного оружия/магазинов; requiredAddons только фактические source patches/ACE missileguidance. Установлены AD 94C6679CF348589DECEB6561607454E8A3EEF9648FE21AE62AB8C70D8515F3A8 и Editor FEAB6AE53F0F153460DADFFA0183CF7BC336B83439E35A2190991574BA019AA0. Operations60/60/editor2/2/SQF92/203. RPT01-33-55: 0 fatal, 0 parent changes NeroAD, 0 missing deps NeroAD; пользователь подтвердил главное меню. Игра оставлена открытой, combat acceptance=false. Сервер/основной MPMissions неизменны; обновлены 17 тестовых ADMagazine. Отчёт docs/EDITOR_SECOND_CRASH_FIX_2026-10-14_RU.md; evidence backups/editor-crash-20261014-second/final-evidence.json.

14.10.2026: установлен field-fix тестового мода. Подробности: backups/ad-fieldtest-20261014/FIELD_FIX_REPORT_RU.md. Проверка стрельбы в движке и измерение FPS остаются открытыми; ранний взрыв Ту-95 не принят как исправленный.

14.10.2026: установлен AD/AIR r2 в отдельный тестовый мод; Skynex/AHEAD и ракетные пуски NASAMS/пилотов. Operations 60/60, Editor 2/2, SQF 224. Подробности: backups/ad-air-engagement-20261014/CHANGES_RU.md. Повторная проверка стрельбы в Arma остаётся открытой.

14.10.2026: NeroFlight.pbo добавлен в отдельный тестовый мод. 1199 классов самолётов/конвертопланов, 44 семейных профиля. Крейсерский/форсаж/максимальная мощность, HUD, игровой расход выше крейсерской. Неопознанные БПЛА и вертолёты сохранены без изменений. SQF расчёты и PBO проверены, полёт не проверен в движке. SHA256 769FDAB6AACB4A183091E7BD11774B43FA643AB47FAF249DDF61F5DA4A9F0E8C. Документация: tools/flight-assets/README_RU.md.

14.10.2026: ванильные самолёты получили отдельные профили с бонусом 150–350 км/ч поверх максимума выбранного прототипа. Реальные модовые модели без бонуса. NeroFlight установлен; 3/3 теста, PBO verified; полёт не проверен. SHA256 ED63F37D0E39F11B6F7487F385AB33D470436361678302E35DB5B608C283356B.

14.10.2026: выполнен read-only аудит авиационных ракет: 107 папок модов, 4480 config.bin, 3070 авиационных вариантов, 340 классов подвесок. После классификации 221 ракетный класс (184 управляемых + 37 НАР), 67 групп. 142 класса имеют ссылку на реальное семейство; остальные численные характеристики явно не подтверждены. Отчёты: docs/aircraft-missiles-2026-10-14/. Конфигурации не равны live configFile; боеприпасы и установленные моды не изменялись.
