param([string]$OutDir = "$(Join-Path $PSScriptRoot '..\dist')")

$ErrorActionPreference = "Stop"

# resolve repo + version
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$VerF = Join-Path $Repo "VERSION.txt"
if (-not (Test-Path $VerF)) { "0.1.0" | Out-File -Encoding utf8 -LiteralPath $VerF }
$Version = (Get-Content -Raw -LiteralPath $VerF).Trim()

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"
$zip   = Join-Path $OutDir ("operion-{0}-{1}.zip" -f $Version, $stamp)

# Gather files (exclude .git, dist, _logs)
$files = Get-ChildItem -Path $Repo -Recurse -File |
  Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '\\dist\\'  -and
    $_.FullName -notmatch '\\_logs\\'
  }

if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $files.FullName -DestinationPath $zip
Write-Host "Release created: $zip"
