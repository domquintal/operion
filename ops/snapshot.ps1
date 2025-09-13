$ErrorActionPreference='Stop'
$root = Split-Path $PSCommandPath -Parent | Split-Path -Parent
$logRoot = Join-Path $root "_logs\snapshots"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outDir = Join-Path $logRoot $stamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# tree (paths)
Get-ChildItem -Recurse -File $root | ForEach-Object {
  $rel = $_.FullName.Substring($root.Length+1)
  $rel
} | Sort-Object | Out-File -Encoding UTF8 (Join-Path $outDir 'tree.txt')

# hashes
Get-ChildItem -Recurse -File $root | ForEach-Object {
  $h = Get-FileHash $_.FullName -Algorithm SHA1
  '{0}  {1}' -f $h.Hash, ($_.FullName.Substring($root.Length+1))
} | Sort-Object | Out-File -Encoding UTF8 (Join-Path $outDir 'hashes.sha1')

# git status
$gitTxt = Join-Path $outDir 'git.txt'
try {
  Push-Location $root
  "branch: $(git rev-parse --abbrev-ref HEAD)" | Out-File -Encoding UTF8 $gitTxt
  "local:  $(git rev-parse HEAD)"             | Add-Content -Encoding UTF8 $gitTxt
  try { "remote: $(git rev-parse origin/$(git rev-parse --abbrev-ref HEAD) 2>$null)" | Add-Content -Encoding UTF8 $gitTxt } catch {}
  "`nstatus --porcelain:" | Add-Content -Encoding UTF8 $gitTxt
  (git status --porcelain) | Add-Content -Encoding UTF8 $gitTxt
} finally { Pop-Location }

Write-Host "Snapshot saved -> $outDir" -ForegroundColor Green
