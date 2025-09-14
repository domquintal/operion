param([int]$Port = 8000)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSCommandPath
$api  = Split-Path -Parent $root
$repo = Split-Path -Parent $api

$venv = Join-Path $api ".venv"
$pyExe = if (Test-Path (Join-Path $venv "Scripts\python.exe")) {
  Join-Path $venv "Scripts\python.exe"
} else {
  (Get-Command python -ErrorAction SilentlyContinue)?.Source
}
if (-not $pyExe) { throw "Python not found. Install Python 3.11+." }

# Create venv for API if missing and install deps
if (-not (Test-Path $venv)) {
  & $pyExe -m venv $venv
}
$pip = Join-Path $venv "Scripts\pip.exe"
& $pip install -r (Join-Path $api "requirements.txt")

$uvicorn = Join-Path $venv "Scripts\uvicorn.exe"
& $uvicorn "src.main:app" --host 0.0.0.0 --port $Port
