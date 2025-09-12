$ErrorActionPreference = 'Stop'
$Desktop = [Environment]::GetFolderPath('Desktop')
$Keep    = Join-Path $Desktop 'Operion.lnk'
Get-ChildItem -Path $Desktop -Filter 'Operion*.lnk' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -ne $Keep } |
  Remove-Item -Force -ErrorAction SilentlyContinue
Write-Host 'Kept only:' $Keep
