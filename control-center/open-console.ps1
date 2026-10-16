$ErrorActionPreference='Stop'
$taskShell=(Get-Process -Id $PID).Path
$taskScript=Join-Path $PSScriptRoot 'log-console.ps1'
Start-Process -FilePath $taskShell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File',('"'+$taskScript+'"')) -WindowStyle Normal | Out-Null
