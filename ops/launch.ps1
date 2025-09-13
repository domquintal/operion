$ErrorActionPreference='Stop'
$Root = Split-Path $PSCommandPath -Parent | Split-Path -Parent
$Run  = Join-Path $Root 'run.ps1'
if(Test-Path $Run){ & $Run } else { Write-Host "run.ps1 not found at $Run" -ForegroundColor Yellow; exit 1 }
