$ErrorActionPreference='Stop'
$p = Join-Path "C:\Users\Domin\Operion\ops" 'parity_check.ps1'
if (Test-Path $p) { & $p } else { Write-Host 'parity_check.ps1 not found.' -ForegroundColor Yellow; exit 1 }
