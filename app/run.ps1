$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = Split-Path -Parent $Root

# Settings with safe defaults
$SettingsPath = Join-Path $Repo "app\settings.json"
$settings = $null
try { $settings = (Get-Content -Raw -LiteralPath $SettingsPath | ConvertFrom-Json) } catch { }
if (-not $settings) { $settings = @{ appName = "Operion"; heartbeatSeconds = 3; logRetentionDays = 14 } }

# Logging
$logDir = Join-Path $Repo "_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$log = Join-Path $logDir ("app_{0}.log" -f $stamp)

"Starting $($settings.appName) runloop..." | Tee-Object -FilePath $log
$beat = [int]$settings.heartbeatSeconds
if ($beat -lt 1) { $beat = 3 }

# Retention
$keep = [int]$settings.logRetentionDays
if ($keep -gt 0) {
  Get-ChildItem $logDir -Filter "app_*.log" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$keep) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
}

try {
  while ($true) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "$ts heartbeat pid=$PID"
    $msg | Tee-Object -FilePath $log -Append
    Start-Sleep -Seconds $beat
  }
} catch {
  "CRASH: $($_.Exception.Message)" | Tee-Object -FilePath $log -Append
  exit 1
}
