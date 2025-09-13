$ErrorActionPreference='Stop'
$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { throw "Not in a git repo" }
Set-Location $root
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path '_logs' "snapshot_$stamp.txt"
New-Item -ItemType Directory -Force -Path '_logs' | Out-Null

"=== OPERION SNAPSHOT $stamp ===" | Out-File $log -Encoding UTF8
"HEAD  : $(git rev-parse HEAD)" | Out-File $log -Append -Encoding UTF8
"BRANCH: $(git rev-parse --abbrev-ref HEAD)" | Out-File $log -Append -Encoding UTF8
"`n-- TREE --" | Out-File $log -Append -Encoding UTF8
git ls-files | Out-File $log -Append -Encoding UTF8
"`n-- HASHES --" | Out-File $log -Append -Encoding UTF8
Get-ChildItem -Recurse -File | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA1).Hash
  "$h  .\{0}" -f ($_.FullName.Substring($root.Length+1))
} | Out-File $log -Append -Encoding UTF8

Write-Host "Snapshot: $log"
