param([Parameter(Mandatory=$true)][string]$RequestFile)
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$OutputEncoding=[Console]::OutputEncoding
if (@(Get-Process -Name arma3_x64,arma3server_x64,arma3battleye -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Arma уже открыта. Закройте её сами перед запуском операции с нужными модами.'}
if (@(Get-Process -Name arma3launcher -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Открыт лаунчер Arma. Закройте его и повторите запуск операции.'}
$request=Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 | ConvertFrom-Json
$armaRoot='H:\SteamLibrary\steamapps\common\Arma 3'
$resolvedRoot=[IO.Path]::GetFullPath($armaRoot).TrimEnd('\')+'\'
$strategicRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dist\strategic-compat\@NeroAI_Strategic'))
$strategicCandidatesRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dist\strategic-candidates'))
$airDefenseRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dist\air-defense-candidates'))
$missileProfilesRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\dist\missile-profile-candidates'))
$modList=@()
foreach ($modPath in $request.mods) {
    $resolvedMod=[IO.Path]::GetFullPath([string]$modPath)
    $isStrategic=$resolvedMod.TrimEnd('\').Equals($strategicRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)
    $isStrategic=$isStrategic -or ([IO.Path]::GetDirectoryName($resolvedMod.TrimEnd('\')).Equals($strategicCandidatesRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedMod.TrimEnd('\')) -cmatch '^@NeroAI_Strategic_[a-f0-9]{12}$')
    $isAirDefense=([IO.Path]::GetDirectoryName($resolvedMod.TrimEnd('\')).Equals($airDefenseRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedMod.TrimEnd('\')) -cmatch '^@NeroAI_AirDefense_[a-f0-9]{12}$')
    $isMissileProfiles=([IO.Path]::GetDirectoryName($resolvedMod.TrimEnd('\')).Equals($missileProfilesRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedMod.TrimEnd('\')) -cmatch '^@NeroAI_Missiles_[a-f0-9]{12}$')
    if ((-not $resolvedMod.StartsWith($resolvedRoot,[StringComparison]::OrdinalIgnoreCase) -and -not $isStrategic -and -not $isAirDefense -and -not $isMissileProfiles) -or $resolvedMod.Contains(';') -or $resolvedMod.Contains('"')) {throw "Недопустимый путь мода операции: $resolvedMod"}
    if (-not (Test-Path -LiteralPath $resolvedMod -PathType Container)) {throw "Недоступна папка мода операции: $resolvedMod"}
    if ($isStrategic -and -not (Test-Path -LiteralPath (Join-Path $resolvedMod 'addons\NeroStrategic.pbo') -PathType Leaf)) {throw "Не найден дополнительный мод NeroAI Strategic: $resolvedMod"}
    if ($isAirDefense -and -not (Test-Path -LiteralPath (Join-Path $resolvedMod 'addons\NeroAirDefense.pbo') -PathType Leaf)) {throw "Не найден дополнительный мод сети ПВО: $resolvedMod"}
    if ($isMissileProfiles -and -not (Test-Path -LiteralPath (Join-Path $resolvedMod 'addons\NeroMissileProfiles.pbo') -PathType Leaf)) {throw "Не найден дополнительный мод ракет: $resolvedMod"}
    $modList+=$resolvedMod
}
foreach ($requiredName in @('@ace','@CBA_A3')) {
    $requiredPath=[IO.Path]::GetFullPath((Join-Path $armaRoot ('!Workshop\'+$requiredName)))
    if (-not (@($request.mods | ForEach-Object {[IO.Path]::GetFullPath([string]$_)}) -contains $requiredPath)) {throw "Не подключён обязательный мод $requiredName. Пересоберите миссию."}
}
foreach ($required in $request.requiredMods) {
    if ($required.path -notin $request.mods) {throw "Не подключён обязательный мод $($required.label)."}
    foreach ($requiredFile in $required.files) {if (-not (Test-Path -LiteralPath (Join-Path $required.path ('addons\'+$requiredFile)) -PathType Leaf)) {throw "Неполный обязательный мод $($required.label): $requiredFile"}}
}
$steam=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
if (-not $steam -or -not (Test-Path -LiteralPath $steam)) {$steam='C:\Program Files (x86)\Steam\steam.exe'}
if (-not (Test-Path -LiteralPath $steam)) {throw 'Steam не найден.'}
$parameterFile=Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($RequestFile))) ('operations-parameters-'+[Guid]::NewGuid().ToString('N')+'.txt')
$parameterMods=@($modList | ForEach-Object {if ($_.StartsWith($resolvedRoot,[StringComparison]::OrdinalIgnoreCase)) {$_.Substring($resolvedRoot.Length)} else {$_}})
$parameterText="-skipIntro`r`n-noSplash`r`n-world=empty`r`n-mod=`""+($parameterMods -join ';')+"`"`r`n"
if ([Text.Encoding]::UTF8.GetByteCount($parameterText) -ge 4000) {throw 'Список модов слишком длинный даже после сокращения путей. Уменьшите число дополнительных модов.'}
[IO.File]::WriteAllText($parameterFile,$parameterText,[Text.UTF8Encoding]::new($false))
$arguments='-applaunch 107410 -noLauncher -win64 -useBE "-par='+$parameterFile+'"'
$launchStarted=(Get-Date).ToUniversalTime()
Start-Process -FilePath $steam -ArgumentList $arguments -WindowStyle Hidden | Out-Null
$launchDeadline=$launchStarted.AddSeconds(90)
do {
    Start-Sleep -Milliseconds 400
    $game=Get-CimInstance Win32_Process -Filter "Name='arma3_x64.exe'" | Select-Object -First 1
    if ($game) {
        $verifiedBy=$null
        if (-not [string]::IsNullOrWhiteSpace([string]$game.CommandLine)) {
            if ($game.CommandLine.IndexOf($parameterFile,[StringComparison]::OrdinalIgnoreCase) -ge 0) {$verifiedBy='parameterFile'}
            else {
                foreach ($expectedMod in $modList) {if ($game.CommandLine.IndexOf($expectedMod,[StringComparison]::OrdinalIgnoreCase) -lt 0) {throw 'Arma запущена с другим набором модов. Проверьте параметры запуска в Steam.'}}
                $verifiedBy='commandLine'
            }
        } else {
            $report=Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Arma 3') -Filter 'Arma3_x64_*.rpt' -File -ErrorAction SilentlyContinue | Where-Object {$_.CreationTimeUtc -ge $launchStarted} | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            if ($report) {
                $header=(Get-Content -LiteralPath $report.FullName -TotalCount 4 -Encoding UTF8 -ErrorAction SilentlyContinue) -join "`n"
                if ($header.IndexOf($parameterFile,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $header.IndexOf((Join-Path $armaRoot 'arma3_x64.exe'),[StringComparison]::OrdinalIgnoreCase) -ge 0) {$verifiedBy='freshReport'}
            }
        }
        if ($verifiedBy) {
            @{launched=$true;pid=$game.ProcessId;title=$request.title;mods=$modList.Count;verification=$verifiedBy;parameters=$parameterFile} | ConvertTo-Json -Compress | Write-Output
            exit 0
        }
    }
} while ((Get-Date).ToUniversalTime() -lt $launchDeadline)
if (@(Get-Process -Name arma3launcher -ErrorAction SilentlyContinue).Count -gt 0) {throw 'Steam открыл лаунчер вместо игры. Закройте лаунчер и проверьте параметры запуска Steam.'}
if ($game) {throw 'Arma запущена, но её набор модов не удалось подтвердить по процессу или свежему журналу. Не запускайте вторую копию; проверьте текущее окно игры.'}
throw 'Steam получил запрос, но процесс Arma не появился за 90 секунд. Проверьте окно Steam и сообщение BattlEye.'
