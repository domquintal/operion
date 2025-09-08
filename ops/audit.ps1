param([string]$Action,[string]$Detail="")
$ErrorActionPreference="Stop"
$root  = Split-Path -Parent $PSScriptRoot
$logd  = Join-Path $root "_logs"
New-Item -ItemType Directory -Force -Path $logd | Out-Null
$audit = Join-Path $logd "audit.csv"
if (-not (Test-Path $audit)) { "timestamp,user,action,detail" | Out-File -Encoding UTF8 -LiteralPath $audit }
("{0},{1},{2},{3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$env:USERNAME,('"' + $Action.Replace('"','""') + '"'),('"' + $Detail.Replace('"','""') + '"')) | Add-Content -LiteralPath $audit
