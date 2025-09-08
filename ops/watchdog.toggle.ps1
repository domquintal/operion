param([switch]$Enable)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pol = Join-Path $root "app\policy.json"
if(-not (Test-Path $pol)){ throw "policy.json missing" }
$p = Get-Content -Raw -LiteralPath $pol | ConvertFrom-Json
$p.watchdog.enabled = [bool]$Enable
$p | ConvertTo-Json -Depth 4 | Out-File -Encoding UTF8 -LiteralPath $pol
Write-Host ("Watchdog " + ($(if($Enable){"ENABLED"}else{"DISABLED"})))
