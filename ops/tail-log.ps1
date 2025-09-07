$ErrorActionPreference="Stop"
$logs = Join-Path $PSScriptRoot "..\_logs"
if (-not (Test-Path $logs)) { throw "No _logs folder yet." }
$lf = Get-ChildItem $logs -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1
if (-not $lf) { Write-Host "No logs yet."; exit 0 }
Get-Content -Path $lf.FullName -Wait -Tail 200
