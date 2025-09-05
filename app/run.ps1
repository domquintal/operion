param()
$ErrorActionPreference="Stop"

$here = Split-Path -Parent $PSCommandPath
$venv = Join-Path $here ".venv"
$py   = Join-Path $venv "Scripts\python.exe"
$pip  = Join-Path $venv "Scripts\pip.exe"
$req  = Join-Path $here "python\requirements.txt"
$main = Join-Path $here "python\main.py"

# Create venv if missing
if (!(Test-Path $py)) {
  Write-Host "[SETUP] Creating venv..."
  & py -3 -m venv $venv
}

# Install deps if needed
Write-Host "[SETUP] Installing requirements..."
& $pip install -r $req

# Launch app
Write-Host "[RUN] Starting Operion Python GUI..."
& $py $main
$code = $LASTEXITCODE
Write-Host "[RUN] App exit code: $code"
exit $code
