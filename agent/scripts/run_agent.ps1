param(
  [switch]$Debug
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)  # ...\agent
$repo = Split-Path -Parent $root                                # repo root
$logs = Join-Path $repo "_logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

# Log rotation: keep 10 newest agent_run_*.log
Get-ChildItem $logs -Filter "agent_run_*.log" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 | Remove-Item -Force -ErrorAction SilentlyContinue

$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile = Join-Path $logs "agent_run_$stamp.log"
Start-Transcript -Path $logFile -Force | Out-Null

# Python & venv
$py = (Get-Command python -ErrorAction SilentlyContinue)?.Source
if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue)?.Source }
if (-not $py) { throw "Python not found on PATH. Install Python 3.11+." }

$venvPath = Join-Path $root ".venv"
if (-not (Test-Path $venvPath)) {
  & $py -m venv $venvPath
}
$pip = Join-Path $venvPath "Scripts\pip.exe"
$python = Join-Path $venvPath "Scripts\python.exe"

# Install requirements if present
$reqs = @(
  (Join-Path $root "src\requirements.txt"),
  (Join-Path $repo "api\requirements.txt")
) | Where-Object { Test-Path $_ }

foreach ($r in $reqs) {
  & $pip install -r $r
}

# Choose entrypoint: prefer main_ttk.py then main.py
$mainTTK = Join-Path $root "src\main_ttk.py"
$mainPy  = Join-Path $root "src\main.py"
$entry = if (Test-Path $mainTTK) { $mainTTK } elseif (Test-Path $mainPy) { $mainPy } else { $null }
if (-not $entry) { Write-Warning "No main_ttk.py or main.py found in agent\src. Exiting."; Stop-Transcript | Out-Null; exit 0 }

# Run the agent UI/app
$args = @()
if ($Debug) { $args += "--debug" }
& $python $entry @args

Stop-Transcript | Out-Null
