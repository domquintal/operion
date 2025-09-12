$ErrorActionPreference = 'Stop'
$Logs = 'C:\\Users\\Domin\\Operion\\_logs'
if (!(Test-Path $Logs)) { exit 0 }
Get-ChildItem -Path $Logs -File -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
  Remove-Item -Force -ErrorAction SilentlyContinue
