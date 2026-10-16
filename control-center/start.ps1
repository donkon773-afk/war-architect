param([ValidateSet('launcher','designer','operations','ground','campaign')][string]$View='launcher')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'operations-start.ps1') -NoBrowser
$currentShell=Join-Path $PSHOME 'pwsh.exe'
if (Test-Path -LiteralPath $currentShell) {$env:NEROAI_PWSH=$currentShell}
$sessionPath=Join-Path $PSScriptRoot 'data\session.json'
$ready=$false
if (Test-Path -LiteralPath $sessionPath) {
    $session=Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    $processInfo=Get-CimInstance Win32_Process -Filter "ProcessId=$($session.pid)" -ErrorAction SilentlyContinue
    if ($processInfo -and $processInfo.CommandLine -and $processInfo.CommandLine.Contains((Join-Path $PSScriptRoot 'server.js'))) {
        try {$response=Invoke-WebRequest -Uri "http://127.0.0.1:$($session.port)/" -TimeoutSec 2; $ready=$response.StatusCode -eq 200} catch {}
        # Node keeps the server code it started with. When the panel code is newer than the
        # running (hidden) process, stop it so the shortcut always opens the current panel.
        $newestCode=(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.js' -File | Measure-Object -Property LastWriteTime -Maximum).Maximum
        if ($ready -and $newestCode -gt $processInfo.CreationDate) {
            Stop-Process -Id $session.pid -ErrorAction Stop
            Start-Sleep -Milliseconds 500
            $ready=$false
        }
    }
}
if (-not $ready) {
    $node=(Get-Command node -ErrorAction Stop).Source
    $logPath=Join-Path $PSScriptRoot 'logs'
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    $app=Start-Process -FilePath $node -ArgumentList ('"'+(Join-Path $PSScriptRoot 'server.js')+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logPath 'app.stdout.log') -RedirectStandardError (Join-Path $logPath 'app.stderr.log')
    for ($attempt=0;$attempt -lt 30;$attempt++) {
        Start-Sleep -Milliseconds 200
        $app.Refresh()
        if ($app.HasExited) {throw 'Control Center failed to start'}
        if (Test-Path -LiteralPath $sessionPath) {$session=Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json; if ($session.pid -eq $app.Id) {$ready=$true;break}}
    }
    if (-not $ready) {throw 'Control Center startup timed out'}
}
$revision=(Get-Item -LiteralPath (Join-Path $PSScriptRoot 'index.html')).LastWriteTimeUtc.Ticks
$url="http://127.0.0.1:$($session.port)/?v=$revision"
if ($View -eq 'designer') {
    $saved=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'data\profiles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $worldId=[Uri]::EscapeDataString([string]$saved.selected.map)
    $url="http://127.0.0.1:$($session.port)/?tab=maps&world=$worldId&v=$revision"
}
if ($View -in @("operations","ground","campaign")) {$url="http://127.0.0.1:$($session.port)/?tab=operations&operation=$View&v=$revision"}
$edgePath=Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
if (Test-Path -LiteralPath $edgePath) {Start-Process -FilePath $edgePath -ArgumentList @('--app='+$url) -WindowStyle Normal | Out-Null} else {Start-Process $url | Out-Null}
