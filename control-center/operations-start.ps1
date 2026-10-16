param([switch]$NoBrowser,[ValidateSet('operations','ground','campaign')][string]$Page='operations')
$ErrorActionPreference='Stop'
$ready=$false
$operationsPort=18792
$occupiedOperationsPorts=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LocalPort)
foreach($candidatePort in @(18792,18793,18794,18795,18796,18797,18798,18799,18786)){
 if($candidatePort -notin $occupiedOperationsPorts){continue}
 try {$health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$candidatePort+'/health') -TimeoutSec 1;if($health.application -eq 'NeroAI Operations' -and $health.features -eq 'campaign-strategic-v6' -and $health.workspaceEmbed -eq $true){$operationsPort=$candidatePort;$ready=$true;break}} catch {}
}
if (-not $ready) {
    $availablePort=@(18792,18793,18794,18795,18796,18797,18798,18799,18786) | Where-Object {$_ -notin $occupiedOperationsPorts} | Select-Object -First 1
    if (-not $availablePort) {throw 'Все порты конструктора операций заняты. Работающие окна сохранены.'}
    $operationsPort=[int]$availablePort
    $node=(Get-Command node -ErrorAction Stop).Source
    $currentShell=Join-Path $PSHOME 'pwsh.exe'
    if (Test-Path -LiteralPath $currentShell) {$env:NEROAI_PWSH=$currentShell}
    $logs=Join-Path $PSScriptRoot 'logs'
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    $previousOperationsPort=$env:NEROAI_OPERATIONS_PORT
    $env:NEROAI_OPERATIONS_PORT=[string]$operationsPort
    $app=Start-Process -FilePath $node -ArgumentList ('"'+(Join-Path $PSScriptRoot 'operations-server.js')+'"') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs "operations-$operationsPort.stdout.log") -RedirectStandardError (Join-Path $logs "operations-$operationsPort.stderr.log")
    $env:NEROAI_OPERATIONS_PORT=$previousOperationsPort
    for ($attempt=0;$attempt -lt 30;$attempt++) {
        Start-Sleep -Milliseconds 200
        $app.Refresh()
        if ($app.HasExited) {throw 'Не удалось открыть конструктор операций. Порт 18786 может быть занят.'}
        try {$health=Invoke-RestMethod -Uri ('http://127.0.0.1:'+$operationsPort+'/health') -TimeoutSec 1;if ($health.application -eq 'NeroAI Operations' -and $health.pid -eq $app.Id) {$ready=$true;break}} catch {}
    }
    if (-not $ready) {throw 'Конструктор операций не ответил.'}
}
if (-not $NoBrowser) {& (Join-Path $PSScriptRoot 'start.ps1') -View $Page}
