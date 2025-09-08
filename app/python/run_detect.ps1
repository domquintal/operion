param([switch]$NoInstall)
$ErrorActionPreference="Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$venv = Join-Path $Here ".venv"
if(-not (Test-Path $venv)){ py -m venv $venv }
$pex = Join-Path $venv "Scripts\python.exe"
if(-not $NoInstall){
  & $pex -m pip install --upgrade pip
  & $pex -m pip install -r (Join-Path $Here "requirements.txt")
}
& $pex (Join-Path $Here "engine\ingest.py")
