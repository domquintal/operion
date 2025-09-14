param([switch]$Debug)
$ErrorActionPreference="Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)  # ...\agent
$repo = Split-Path -Parent $root
$logs = Join-Path $repo "_logs"; New-Item -ItemType Directory -Force -Path $logs | Out-Null
Get-ChildItem $logs -Filter "agent_run_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force -ErrorAction SilentlyContinue
$stamp=(Get-Date).ToString("yyyyMMdd_HHmmss"); $logFile=Join-Path $logs "agent_run_$stamp.log"; Start-Transcript -Path $logFile -Force | Out-Null
$py = (Get-Command python -ErrorAction SilentlyContinue)?.Source; if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue)?.Source }
$venvPath = Join-Path $root ".venv"; if (-not (Test-Path $venvPath)) { & $py -m venv $venvPath }
$pip=Join-Path $venvPath "Scripts\pip.exe"; $python=Join-Path $venvPath "Scripts\python.exe"
& $pip install -r (Join-Path $root "src\requirements.txt")
& $pip install -r (Join-Path $repo "api\requirements.txt")
$null = Start-Job -ScriptBlock { param($p) & $p } -ArgumentList (Join-Path $root "scripts\heartbeat.ps1")
$uiDesktop = Join-Path $root "src\ui_desktop.py"; if (-not (Test-Path $uiDesktop)) { Write-Warning "ui_desktop.py missing"; Stop-Transcript | Out-Null; exit 0 }
$args = @(); if ($Debug) { $args += "--debug" }
& $python $uiDesktop @args
Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
Stop-Transcript | Out-Null
