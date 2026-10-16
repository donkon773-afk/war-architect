$ErrorActionPreference='Stop'
$Host.UI.RawUI.WindowTitle='NeroAI - LLM input/output and Arma execution'
$projectPath=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$viewerPath=Join-Path $PSScriptRoot 'journal-cli.js'
$nodePath=(Get-Command node -ErrorAction Stop).Source
Write-Host 'NeroAI LLM journal: game input -> model -> validated commands -> Arma result. Ctrl+C to close.' -ForegroundColor Cyan
& $nodePath $viewerPath
