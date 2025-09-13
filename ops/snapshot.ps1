$ErrorActionPreference='Stop'
$Root = (git rev-parse --show-toplevel 2>$null)
if(-not $Root){ $Root = Split-Path $PSCommandPath -Parent | Split-Path -Parent }
Set-Location $Root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dirOut = Join-Path $Root '_logs\snapshots'
New-Item -ItemType Directory -Force -Path $dirOut | Out-Null
$out = Join-Path $dirOut ("snapshot_"+$stamp+".txt")

$HEAD = (git rev-parse HEAD).Trim() 2>$null
$BR   = (git rev-parse --abbrev-ref HEAD).Trim() 2>$null
$CLEAN = [string]::IsNullOrWhiteSpace((git status --porcelain 2>$null))

$lines = @()
$lines += "OPERION SNAPSHOT"
$lines += ("Time: " + (Get-Date))
$lines += ("Branch: " + $BR)
$lines += ("HEAD: " + $HEAD)
$lines += ("Clean: " + $CLEAN)
$lines += "---- FILE HASHES (SHA1) ----"

Get-ChildItem -Recurse -File |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA1).Hash
    $rel = $_.FullName.Substring($Root.Length+1)
    $lines += ("{0}  {1}" -f $h,$rel)
  }

$lines | Out-File -FilePath $out -Encoding UTF8
Write-Host "Snapshot written: $out" -ForegroundColor Cyan
