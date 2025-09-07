# Opens the Operion Control window
$ErrorActionPreference="Stop"
& (Get-Command pwsh -EA SilentlyContinue)?.Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Control.ps1") `
  2>$null; if($LASTEXITCODE -ne 0){
  & (Get-Command powershell -EA Stop).Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Control.ps1")
}
