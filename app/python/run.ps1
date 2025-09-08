param([switch]$NoInstall)
$ErrorActionPreference="Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$venv = Join-Path $Here ".venv"
$py = (Get-Command py -EA SilentlyContinue)
if($py){ $py = "py" } elseif(Get-Command python -EA SilentlyContinue){ $py = "python" } else { throw "Python not found. Install Python 3.10+." }
if(-not (Test-Path $venv)){ & $py -m venv $venv }
$pex = Join-Path $venv "Scripts\python.exe"
if(-not $NoInstall){ & $pex -m pip install --upgrade pip ; & $pex -m pip install -r (Join-Path $Here "requirements.txt") }
& $pex (Join-Path $Here "main.py")
