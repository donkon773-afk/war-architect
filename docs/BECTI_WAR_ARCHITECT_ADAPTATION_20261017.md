# Sector Command BECTI — War Architect adaptation, 2026-10-17

## Русский

Установленный отдельный файл:
`H:\SteamLibrary\steamapps\common\Arma 3\MPMissions\WarArchitect_BECTI_Australia_9c8bcb4f617a.australia.pbo`.
SHA-256: `A5B2B0333CFDD2EE07169A764CCAACD3AD81C19ACF90550115D4747FCC65DAAD`.
Запись в библиотеке сценариев: `39f01dd4-6142-448f-ab32-2bae2ab8f5ff`.

Это переработка входа, базы, арсенала и запуска ИИ поверх BECTI. Экономика,
строительство, развитие и основные автоматы поведения BECTI сохраняются.
Полный перенос логистики и стратегического поведения Frontline ещё не завершён.

### Использование

Выберите новую миссию **War Architect — Sector Command BECTI · Australia**.
После смены версии желательно полностью перезапустить Arma: штатные функции
BECTI компилируются как final и могут оставаться от предыдущей миссии в процессе.
Текущая игра автоматически не перезапускается, существующие миссии не заменяются.

В меню действий персонажа доступны:

- **War Architect · Арсенал / заказ** — каталог выбранной армии, поиск по классу,
  названию и моду; корзина и единая кнопка заказа. Окно остаётся открытым.
- **War Architect · Принять командование** — назначение на своей базе возле HQ.
  Должность другого игрока не перехватывается.
- **War Architect · Планшет управления** — строительство, отряды, карта приказов,
  развитие, обслуживание, рабочие, бюджет и вход в Zeus для хоста/администратора.

Техника заказывается с экипажем в отдельном отряде или пустой. Снаряжение
поступает в ящик рядом с покупателем. Пехота присоединяется к исходному отряду.
Покупки доступны возле своей базы, своих строений и захваченных городов.
Позиции без загруженного мода видны с объяснением; подбор сетапа не обрезается.
При неудачном создании заказ отменяется без списания. Бюджет используется BECTI.

Для строительства примите командование и подойдите пешком к мобильному HQ.
Для карты командования, отрядов и улучшений требуется построенный центр управления
и нахождение рядом с ним. Причина недоступности выводится в планшете.

**Zeus:** планшет → **Zeus · хост / админ**. Сервер проверяет личность отправителя
и права хоста/администратора. Командир стороны автоматически прав Zeus не получает.
После назначения доступна стандартная клавиша Y. Существующие и новые бойцы/машины
добавляются в редактируемые объекты с интервалом 5 секунд. Доступность классов
по-прежнему зависит от загруженных модов и их поддержки Zeus.

### Исправления базы и ИИ

Служебная тюрьма и скрытые резервные группы вынесены за пределы игровых секторов.
Мобильный HQ создаётся на безопасной поверхности; восстановление из старого
сохранения больше не применяет ошибочную подземную высоту. Это выполняется при
создании/загрузке, без периодического перемещения действующего штаба.

Два конкурирующих цикла регистрации ИИ из оригинала заменены одним. Каждый слот
регистрируется однократно, без принудительной смерти и повторной смены группы.
Первая жизнь группы сразу проходит проверку готовности автомата BECTI; раньше
значение -600 требовало искусственного возрождения. Группы игроков не захватываются.

Для обеих сторон восстановлены обязательные служебные записи эвакуационных
грузовиков. Их реальные классы берутся из сетапа стороны. Запрос неизвестного
класса отклоняется до очереди; повреждённая запись удаляется, позволяя фабрике
обработать следующий заказ. Тайм-аут удаляет именно соответствующий заказ.

Установленный лимит боевых групп BECTI и число слотов игроков — разные параметры.
При 20 слотах и 10 группах часть незанятых слотов остаётся резервом на базе.
Проверка продвижения относится к зарегистрированным боевым группам, а не ко всем
незанятым персонажам лобби.

### Проверки и ограничения

Материалы: `dist/candidate/becti-war-architect-20261017/` — исходная валидация,
артефакт, установка, журналы тестовых серверов и итоговые результаты.
В отдельном сервере с 107 модами проверялись HQ, модовое оружие, пехота,
техника с экипажем/без него, деньги, отказ при нехватке средств, повреждённая
очередь и выход восточных групп к цели. Это не проверка совместимости всех
механик всех 107 модов. В отдельном тесте с ACE/CBA проверены конфигурация обоих
окон, создание Zeus, назначение, редактируемые объекты и отказ для запроса от бота.
Проверка настоящего входа хоста/удалённого администратора и вид окон в клиенте
требуют игрового запуска.

Итог текущих проверок: 8 автоматических тестов, 69 разобранных SQF-файлов,
573 файла в проверенном PBO; 9 проверок ИИ/очереди и 5 проверок покупок в движке
прошли. В 6-минутном наблюдении все 10 зарегистрированных восточных групп
сохранили идентичность и переместились; 9 боевых групп получили город Town1,
одна группа стала ИИ-командиром. В этом тестовом журнале нет `Error in expression`.
Ни захват удалённого города, ни эффективность боя этим наблюдением не доказаны.
Новый итоговый PBO в клиентской сессии пользователя пока не запускался.

Остаются отдельными этапами: физическое десантирование заказов BECTI с сопровождением,
новая доктрина распределения групп и сил, объединённые операции нескольких групп,
полноценная тактика техники и проверка боевых перехватов ракет. Текущий адаптер
подключает общие профили ракет/ПВО и ограниченные меры безопасности авиации,
объезда и запроса ремонтной поддержки; это не доказательство их боевой эффективности.
Маршруты и захват пока используют правила BECTI, сохранения BECTI остаются отдельными
от Frontline, цены общих классов глобальны для обеих сторон.

### Продолжение разработки

Работать в `C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM`.
Генератор — `tools/build-becti-operation.js`, адаптеры — `tools/becti-assets/`.
Исходный `research/becti-latest` сохранять без изменений; не заменять активные PBO.
Следующая проверка в клиенте: новая миссия → арсенал с модовыми классами →
несколько покупок без закрытия окна → приём командования → центр управления →
приказы экипажному отряду → Zeus от хоста. Затем перенести сбор боевых групп,
распределение целей и резервов, избегание одиночных атак и поддержку техники.
Нативный тест показал движение первоначальных одиночных лидеров до пополнения:
движение исправлено, но это ещё не требуемая доктрина слаженного наступления.
Физическую доставку подключать к `shopPurchase.sqf` с одним итогом заказа,
проверкой потерь, возвратом денег по выбранным правилам и сохранением исходного
отряда игрока. Приоритет игрока и ручные приказы не перехватывать.

## English

**Sector Command BECTI** adapts BECTI's entry flow, HQ placement, army catalog,
requisition cart, commander access and AI registration to War Architect. Native
economy, construction, upgrades and core AI state machines remain in use.

Start **War Architect — Sector Command BECTI · Australia**. A full Arma restart
is recommended after changing mission versions because native final functions
can remain from another BECTI mission. Existing installed missions are preserved.

Use the player's action menu to open the arsenal/cart or command tablet, or claim
side command near your HQ. Requisitions use BECTI funds and the edited faction
catalog, including mod equipment. Gear arrives in a nearby crate; infantry joins
the original group. Vehicles can arrive empty or with a separate crew group.
Failed deliveries are not charged. Missing addon classes are explicitly marked.

The tablet combines construction, team autonomy, map orders, upgrades, service,
workers, funds and a host/admin Zeus entry. Command requires the native control
center where applicable. Claiming command cannot displace another human commander.
Zeus access is checked on the server; side command alone does not grant Zeus.
Existing and newly created units/vehicles become editable every five seconds.

AI slots are registered once without forced death or repeated regrouping. Newly
created groups are immediately eligible for native AI processing. Required salvage
aliases are rebuilt using the selected faction's truck. Invalid requests cannot
poison the factory queue, and a timed-out request cannot remove the next order.
Unused lobby slots may remain at base when player-slot capacity exceeds the native
AI team count. They are distinct from registered combat groups.

Dedicated tests cover spawning, accounting, mod catalog availability, queue recovery,
HQ recovery and east-side group movement. A separate ACE/CBA test covers UI config
loading and curator creation/assignment. These tests do not establish rendered
client usability, remote admin access or complete compatibility of all installed
mods. Physical BECTI airborne delivery, coordinated multi-group doctrine and combat
acceptance of shared missile/air-defense features remain follow-up work.

Upstream: Kiyogitpy/becti_altis_1355.Altis at
`2a883f7ab7f827eea1f7e060b05bf19f4bb96959`. Attribution and CC BY-NC-SA 4.0 retained.
