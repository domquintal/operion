# app/ui/Open_Control.ps1
$ErrorActionPreference="Stop"
$pw = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pw) {
  & $pw.Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Control.ps1")
} else {
  & (Get-Command powershell -EA Stop).Path -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Control.ps1")
}
