param()
$ErrorActionPreference='Stop'
Write-Host "== opcheck: fetch & status =="
git fetch origin
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { $branch = "main" }
$local  = (git rev-parse $branch).Trim()
$remote = (git rev-parse origin/$branch).Trim()
if ($local -ne $remote) {
  Write-Host "⚠️ Local $branch ($local) != origin/$branch ($remote). Run: git pull --rebase" -ForegroundColor Yellow
} else {
  Write-Host "✔ Local $branch is up to date with origin/$branch" -ForegroundColor Green
}

$must = @('Operion_Start.cmd','operion_start.ps1','start.target','app')
$bad = @()
foreach($m in $must){ if(-not (Test-Path $m)){ $bad += $m } }
if($bad.Count){ throw "Missing required items: $($bad -join ', ')" }

$rel = (Get-Content -Raw .\start.target -ErrorAction Stop).Trim()
if([string]::IsNullOrWhiteSpace($rel)){ throw "start.target is empty" }
$target = Join-Path $PWD $rel
if(-not (Test-Path $target)){ throw "start.target points to missing file: $rel" }
Write-Host "✔ start.target -> $rel (exists)" -ForegroundColor Green
