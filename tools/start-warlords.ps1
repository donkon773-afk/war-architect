param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$launch = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'warlords-launch.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$configPath = Join-Path $root 'bridge\neroai3.config.json'
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($config.transport.outboxDb -ne 'NeroWL_out' -or $config.transport.inboxDb -ne 'NeroWL_in') { throw 'Warlords bridge namespace is invalid.' }
$arma = $launch.armaRoot
$mod = Join-Path $arma '@NeroAI_Warlords'
$installed = Join-Path $mod 'addons\NeroWL.pbo'
$built = Join-Path $root 'dist\NeroWL.pbo'
foreach ($file in @($configPath,$installed,$built,(Join-Path $arma 'arma3_x64.exe'))) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing Warlords component: $file" } }
if ((Get-FileHash -LiteralPath $installed).Hash -ne (Get-FileHash -LiteralPath $built).Hash) { throw 'Installed Warlords PBO does not match the verified build.' }
foreach ($folder in @($launch.mods)+@($mod,$config.transport.iniFolder)) { if (-not (Test-Path -LiteralPath $folder -PathType Container)) { throw "Missing mod or transport directory: $folder" } }
$steamSettings = Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
$steam = if ($steamSettings -and $steamSettings.SteamExe) { $steamSettings.SteamExe } else { Join-Path ${env:ProgramFiles(x86)} 'Steam\steam.exe' }
if (-not (Test-Path -LiteralPath $steam -PathType Leaf)) { throw 'Steam executable not found.' }
$argsList = @('-applaunch','107410','-noLauncher','-useBE','-win64','-noSplash','-skipIntro','-world=empty',('-name=' + $launch.playerProfileName),('-mod=' + ((@($launch.mods)+@($mod)) -join ';')))
foreach ($arg in $argsList) { if ($arg -match '["\r\n]' -or $arg.EndsWith('\')) { throw 'Invalid Steam launch argument.' } }
$quoted = ($argsList | ForEach-Object { '"' + $_ + '"' }) -join ' '
if ($quoted.Length -gt 30000) { throw 'Steam launch command is too long.' }
$summary = @{role=$(if ($config.dualEnemy.enabled) {'warlords-dual-enemy'} else {'warlords-single-mac'});profile=$launch.playerProfileName;modCount=$launch.mods.Count+1;steam=$steam;pboHash=(Get-FileHash -LiteralPath $built).Hash;strategyModel=$(if ($config.dualEnemy.enabled) {$config.dualEnemy.strategy.model} else {$null});tacticalModel=$config.lmStudio.model;arguments=$argsList}
if ($DryRun) { $summary | ConvertTo-Json -Depth 4; return }
$games = @(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('arma3_x64.exe','arma3battleye.exe','arma3launcher.exe','arma3server_x64.exe') })
if ($games.Count) { throw 'Arma is already running. Close the current game before starting Warlords.' }
$node = (Get-Command node -ErrorAction Stop).Source
& $node (Join-Path $PSScriptRoot 'check-brains.js')
if ($LASTEXITCODE -ne 0) { throw 'Configured local LLM readiness check failed.' }
$bridgePath = Join-Path $root 'bridge\server.js'
$other = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Replace('/','\').IndexOf($bridgePath,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
if ($other.Count -gt 1) { throw 'Multiple Warlords bridges found; inspect them before launching.' }
if ($other.Count -eq 1) {
    # No Arma process is running. Replace only this exact bridge to clear old
    # session strategy and transport state before a fresh Warlords mission.
    Stop-Process -Id $other[0].ProcessId -ErrorAction Stop
    Start-Sleep -Milliseconds 500
    if (Get-Process -Id $other[0].ProcessId -ErrorAction SilentlyContinue) { throw 'Previous Warlords bridge did not stop.' }
}
$logs = Join-Path $root 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$env:NEROAI3_CONFIG = $configPath
$env:NEROAI_LOG_FILE = Join-Path $logs 'bridge.log'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bridge = Start-Process -FilePath $node -ArgumentList ('"'+$bridgePath+'" --debug') -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs "bridge-$stamp.stdout.log") -RedirectStandardError (Join-Path $logs "bridge-$stamp.stderr.log")
Start-Sleep -Seconds 2
$bridge.Refresh()
if ($bridge.HasExited) { throw 'Warlords bridge failed during startup; inspect logs.' }
$game = Start-Process -FilePath $steam -ArgumentList $quoted -WorkingDirectory (Split-Path -Parent $steam) -WindowStyle Normal -PassThru
$summary.bridgePid = $bridge.Id
$summary.steamPid = $game.Id
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $logs 'last-launch.json') -Encoding UTF8
Write-Host "Started Warlords client via Steam with profile $($launch.playerProfileName). Select a Warlords mission on any installed map."
