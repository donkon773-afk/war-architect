$ErrorActionPreference='Stop'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$entries=Get-Content -LiteralPath (Join-Path $projectPath 'dist\criteria-missions.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$releasePath=Join-Path $projectPath 'dist\criteria-release'
New-Item -ItemType Directory -Path $releasePath -Force | Out-Null
$manifest=@()
foreach ($entry in $entries) {
    & node (Join-Path $PSScriptRoot 'validate-mission.js') $entry.output
    if ($LASTEXITCODE -ne 0) {throw 'Mission structure validation failed'}
    $pboName="$($entry.name).$($entry.world).pbo"
    & (Join-Path $PSScriptRoot 'pack-pbo.ps1') -SourceDir $entry.output -OutputDir $releasePath -OutputPbo $pboName -Mission
    & node (Join-Path $PSScriptRoot 'verify-pbo.js') (Join-Path $releasePath $pboName) $entry.output --mission
    if ($LASTEXITCODE -ne 0) {throw 'Mission PBO verification failed'}
    $packagePath=Join-Path $releasePath "$($entry.name)_package"
    New-Item -ItemType Directory -Path (Join-Path $packagePath 'MPMissions') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $packagePath 'source') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $releasePath $pboName) -Destination (Join-Path $packagePath 'MPMissions') -Force
    Copy-Item -LiteralPath $entry.output -Destination (Join-Path $packagePath 'source') -Recurse -Force
    $readmeText=@"
$($entry.title)

Установка: скопируйте PBO из папки MPMissions в MPMissions установленной Arma 3.
Папка source содержит исходники для редактора; её не нужно устанавливать вместе с PBO.
Исходные пользовательские ZIP не изменены.

Запуск: клиент NeroAI с профилем donko → Мультиплеер → Создать сервер → нужная карта → эта миссия → Играть.
В лобби: включите ИИ и задайте настройки во вкладке Параметры, затем выберите место и нажмите ОК.
По $($entry.commanderSlots / 2) мест командиров на каждой стороне. Игрок занимает одно из них. По умолчанию до 9 подчинённых + командир у каждого; пополнение покупается за CP.
Параметры: стартовые CP, доход, подчинённые, время суток, быстрое перемещение, LLM, авиация, сложность, стиль планирования.
RHS-экипировка командиров и пехоты; гарнизоны независимых — RHS GREF CDF NG.
В Australia добавлены Perth, Willcania, Toowoomba, Coober Pedy, Pine Gap; всего 11 захватываемых секторов.

Нужен обновлённый @NeroAI_Warlords, RHSUSAF, RHSAFRF, RHSGREF, RHSSAF, INIDBI2, CBA и соответствующая карта.
Для выбранных HAFM/CUP/TT/FA18/SU35 покупок загрузите соответствующие моды из каталога приложения. Отсутствующие классы из исходного RHS каталога пропускаются.
Режим сейчас использует одну модель GPT-OSS 20B на Mac. Отдельные сервер и HC не нужны.
Покупки расходуют реальные CP. Авиация требует своего сектора с нужным обслуживанием и площадки/полосы.
До 5 бортов LLM на сторону, настраивается в лобби; конечные топливо и боезапас. Штатное быстрое перемещение ИИ сохранено.
ACE включён в запускаторе, с установленной совместимостью RHS/CUP; настройки клиента, сервера и миссии доступны через CBA.
Стартовые точки баз рядом с аэродромами уточняются по ровному свободному участку, на расстоянии от строений.
Зевс у хоста: по умолчанию Y после загрузки. Отладочная консоль: Esc.

Проверено: связанные сектора, классы мест командиров из установленных RHS, параметры, целостность PBO.
HOSTFIX Australia с предыдущими 4 местами на сторону открыл лобби и после задержки запустил Warlords и обмен с Mac LLM.
Предыдущая редакция создала 13 секторов и обмен с LLM, но ошибочный BOOL Border прерывал интерфейс клиента.
В этой редакции Border исправлен на SCALAR 200 метров; проверка готовности теперь также требует клиентские маркеры и HUD.
В основном сценарии Australia пользователь подтвердил сектора, HUD, меню и нормальный спавн; журнал подтвердил посадку ИИ в технику.
Защита финальной функции заблокировала прежнюю замену покупок: исправлен путь функции через конфигурацию аддона до компиляции.
Для 9 подчинённых нужен следующий запуск с новым аддоном; это исправление ещё требует проверки в игре.
Остальные карты, боевые вылеты до 5 бортов, быстрое перемещение ИИ и FPS также требуют проверки в движке.
"@
    [System.IO.File]::WriteAllText((Join-Path $packagePath 'README_RU.txt'),$readmeText,[System.Text.UTF8Encoding]::new($false))
    $zipPath=Join-Path $releasePath "$($entry.name).$($entry.world).zip"
    Compress-Archive -Path (Join-Path $packagePath '*') -DestinationPath $zipPath -Force
    $manifest += [pscustomobject]@{mission=$entry.title;slots=$entry.commanderSlots;sectors=$entry.sectors;pbo=$pboName;sha256=(Get-FileHash -LiteralPath (Join-Path $releasePath $pboName)).Hash;zip=$zipPath;engineVerified=$false}
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $releasePath 'manifest.json') -Encoding UTF8
