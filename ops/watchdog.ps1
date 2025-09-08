param([string]$ScriptPath="$(Join-Path (Split-Path -Parent $PSScriptRoot) 'app\run.ps1')",[int]$Delay=2)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $root "_logs"; New-Item -ItemType Directory -Force -Path $logs | Out-Null
$wlog = Join-Path $logs ("watchdog_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"Watchdog starting for $ScriptPath" | Tee-Object -FilePath $wlog
function Shell(){ $pw=Get-Command pwsh -EA SilentlyContinue; if($pw){$pw.Path}else{(Get-Command powershell -EA Stop).Path} }
while ($true) {
  try{
    $p = Start-Process (Shell) -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $ScriptPath) -PassThru
    $p.WaitForExit()
    "Child exited with $($p.ExitCode). Restarting in $Delay s..." | Tee-Object -FilePath $wlog -Append
    & "$root\ops\audit.ps1" -Action "watchdog_restart" -Detail "exit=$($p.ExitCode)"
    Start-Sleep -Seconds $Delay
  } catch {
    "Watchdog error: $($_.Exception.Message)" | Tee-Object -FilePath $wlog -Append
    Start-Sleep -Seconds $Delay
  }
}
