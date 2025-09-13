$ErrorActionPreference='Stop'
$f = Join-Path "C:\Users\Domin\Operion\ops" 'force_sync.ps1'
if (!(Test-Path $f)) { Write-Host 'force_sync.ps1 not found.' -ForegroundColor Yellow; exit 1 }
& $f -Mode push_local -Yes
