param([Parameter(Mandatory=$true)][string]$RequestFile)
$ErrorActionPreference='Stop'
$controlPath=$PSScriptRoot
$warlordsPath=(Resolve-Path -LiteralPath (Join-Path $controlPath '..')).Path
$antistasiPath=Join-Path (Split-Path -Parent $warlordsPath) 'NeroAI_5.0-antistasi'
$requestPath=(Resolve-Path -LiteralPath $RequestFile).Path
$runtimePath=Join-Path $controlPath 'data\runtime'
if (-not $requestPath.StartsWith($runtimePath+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Request must belong to this Control Center'}
$request=Get-Content -LiteralPath $requestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($request.scenario -notin @('warlords','antistasi')) {throw 'Invalid scenario'}
$games=@(Get-Process -Name arma3_x64,arma3server_x64,arma3battleye,arma3launcher -ErrorAction SilentlyContinue)
if ($games.Count) {throw 'Arma is running. Close it yourself before updating or launching.'}
$projectPath=if ($request.scenario -eq 'warlords') {$warlordsPath} else {$antistasiPath}
$launchPath=Join-Path $projectPath ('tools\'+$request.scenario+'-launch.json')
$settings=Get-Content -LiteralPath $launchPath -Raw -Encoding UTF8 | ConvertFrom-Json
$configPath=(Resolve-Path -LiteralPath $request.configPath).Path
if (-not $configPath.StartsWith($runtimePath+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Config must belong to this Control Center'}
$node=(Get-Command node -ErrorAction Stop).Source
$env:NEROAI3_CONFIG=$configPath
$env:NEROAI3_DISABLE_ENDPOINTS=''
$env:NEROAI3_PROFILE='control-center'
# 9.10: standard Arma AI mode — no model check and no bridge.
$vanilla=($request.scenario -eq 'warlords' -and $request.mode -eq 'vanilla')
# 11.10: tactical AI without LLM — the addon commands the bots itself; no model check, no bridge, LAMBS kept.
$tactical=($request.scenario -eq 'warlords' -and $request.mode -eq 'tactical')
$noBridge=($vanilla -or $tactical)
if (-not $noBridge) {
    & $node (Join-Path $projectPath 'tools\check-brains.js') --config $configPath
    if ($LASTEXITCODE -ne 0) {throw 'Selected model failed a real completion check'}
}
$armaRoot=$settings.armaRoot
$mods=@($settings.mods)
if ($request.scenario -eq 'warlords') {
    $workshopRoot=(Join-Path $armaRoot '!Workshop')+'\'
    foreach ($extraPath in $request.extraMods) {
        $absolute=[IO.Path]::GetFullPath($extraPath)
        if (-not $absolute.StartsWith($workshopRoot,[StringComparison]::OrdinalIgnoreCase) -or $absolute -match '[";\r\n]') {throw 'Invalid catalog mod path'}
        if ($absolute -notin $mods) {$mods += $absolute}
    }
}
$addonFolder=if ($request.scenario -eq 'warlords') {'@NeroAI_Warlords'} else {'@NeroAI_Antistasi'}
$addonName=if ($request.scenario -eq 'warlords') {'NeroWL.pbo'} else {'NeroAI5.pbo'}
$addonPrefix=if ($request.scenario -eq 'warlords') {'NeroWL'} else {'NeroAI5'}
$addonMod=Join-Path $armaRoot $addonFolder
if ($addonMod -notin $mods) {$mods += $addonMod}
if ($request.ace -or $request.scenario -eq 'warlords') {
    $acePath=Join-Path $armaRoot '!Workshop\@ace'
    if ($acePath -notin $mods) {$mods += $acePath}
} else {$mods=@($mods | Where-Object {(Split-Path -Leaf $_) -ne '@ace'})}
if ($request.scenario -eq 'warlords') {
    $cbaPath=Join-Path $armaRoot '!Workshop\@CBA_A3'
    if ($cbaPath -notin $mods) {$mods += $cbaPath}
}
if ($vanilla -and -not $request.vanillaLambs) {$mods=@($mods | Where-Object {(Split-Path -Leaf $_) -ne '@LAMBS_Danger.fsm'})}
foreach ($modPath in $mods) {if (-not (Test-Path -LiteralPath $modPath -PathType Container)) {throw "Missing mod: $modPath"}}
$addonSourceName=if ($request.scenario -eq 'warlords') {'NeroAI3'} else {'NeroAI5'}
$candidate=Join-Path $projectPath ('dist\candidate\'+$addonName)
    & $node (Join-Path $projectPath 'tools\verify-pbo.js') $candidate (Join-Path $projectPath ('addons\'+$addonSourceName)) $addonPrefix
    if ($LASTEXITCODE -ne 0) {throw 'Candidate addon does not match source'}
    $backupPath=Join-Path $projectPath ('backups\control-center-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    $addonPath=Join-Path $addonMod ('addons\'+$addonName)
    New-Item -ItemType Directory -Path (Split-Path -Parent $addonPath) -Force | Out-Null
    if (Test-Path -LiteralPath $addonPath) {Copy-Item -LiteralPath $addonPath -Destination $backupPath}
    Copy-Item -LiteralPath $candidate -Destination $addonPath -Force
    Copy-Item -LiteralPath $candidate -Destination (Join-Path $projectPath ('dist\'+$addonName)) -Force
    if ((Get-FileHash -LiteralPath $candidate).Hash -ne (Get-FileHash -LiteralPath $addonPath).Hash) {throw 'Addon copy verification failed'}
if ($request.scenario -eq 'warlords') {
    foreach ($missionName in $request.missionFiles) {
        if ($missionName -notmatch '^[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.pbo$') {throw 'Invalid mission filename'}
        $missionPbo=Get-Item -LiteralPath (Join-Path (Join-Path $runtimePath 'missions') $missionName) -ErrorAction Stop
        $targetPath=Join-Path (Join-Path $armaRoot 'MPMissions') $missionPbo.Name
        if (Test-Path -LiteralPath $targetPath) {Copy-Item -LiteralPath $targetPath -Destination $backupPath}
        Copy-Item -LiteralPath $missionPbo.FullName -Destination $targetPath -Force
        if ((Get-FileHash -LiteralPath $missionPbo.FullName).Hash -ne (Get-FileHash -LiteralPath $targetPath).Hash) {throw 'Mission copy verification failed'}
    }
}
# Stop only known bridge processes, after the game-close gate. No queue deletion.
$bridgePaths=@((Join-Path $warlordsPath 'bridge\server.js'),(Join-Path $antistasiPath 'bridge\server.js'))
foreach ($processInfo in Get-CimInstance Win32_Process -Filter "Name='node.exe'") {
    if ($processInfo.CommandLine) {
        foreach ($knownPath in $bridgePaths) {
            if ($processInfo.CommandLine.Replace('/','\').IndexOf($knownPath,[StringComparison]::OrdinalIgnoreCase) -ge 0) {Stop-Process -Id $processInfo.ProcessId -ErrorAction Stop; break}
        }
    }
}
$logPath=Join-Path $controlPath 'logs'
New-Item -ItemType Directory -Path $logPath -Force | Out-Null
$env:NEROAI_LOG_FILE=Join-Path $logPath ($request.scenario+'-bridge.log')
$bridgePid=$null
if (-not $noBridge) {
    $bridgePath=Join-Path $projectPath 'bridge\server.js'
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $bridge=Start-Process -FilePath $node -ArgumentList ('"'+$bridgePath+'" --debug') -WorkingDirectory $projectPath -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logPath "bridge-$stamp.stdout.log") -RedirectStandardError (Join-Path $logPath "bridge-$stamp.stderr.log")
    Start-Sleep -Seconds 2
    $bridge.Refresh()
    if ($bridge.HasExited) {throw 'Bridge exited during startup'}
    $bridgePid=$bridge.Id
}
$steamSettings=Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction Stop
$steamPath=$steamSettings.SteamExe
if (-not (Test-Path -LiteralPath $steamPath)) {throw 'Steam executable missing'}
$argsList=@('-applaunch','107410','-noLauncher','-useBE','-win64','-noSplash','-skipIntro','-world=empty',('-name='+$request.profile),('-mod='+($mods -join ';')))
foreach ($argument in $argsList) {if ($argument -match '["\r\n]' -or $argument.EndsWith('\')) {throw 'Invalid game launch argument'}}
$quoted=($argsList | ForEach-Object {'"'+$_+'"'}) -join ' '
if ($quoted.Length -gt 30000) {throw 'Mod list is too long'}
Start-Process -FilePath $steamPath -ArgumentList $quoted -WorkingDirectory (Split-Path -Parent $steamPath) -WindowStyle Normal | Out-Null
@{scenario=$request.scenario;mode=$request.mode;profile=$request.profile;modCount=$mods.Count;bridgePid=$bridgePid;standardAI=$vanilla;tacticalAI=$tactical;timestamp=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logPath 'last-launch.json') -Encoding UTF8
