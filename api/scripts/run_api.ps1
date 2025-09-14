param([int]$Port = 8000)
$ErrorActionPreference="Stop"
$here = Split-Path -Parent $PSCommandPath
$api  = Split-Path -Parent $here
$venv = Join-Path $api ".venv"
$pip  = Join-Path $venv "Scripts\pip.exe"
$py   = Join-Path $venv "Scripts\python.exe"
& $pip install -r (Join-Path $api "requirements.txt")
& (Join-Path $venv "Scripts\uvicorn.exe") "src.main:app" --host 0.0.0.0 --port $Port
