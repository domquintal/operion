param(
  [ValidateSet("patch","minor","major")] [string]$Bump = "patch"
)
$ErrorActionPreference='Stop'
$Root = (git rev-parse --show-toplevel 2>$null); if(-not $Root){ $Root = Split-Path $PSCommandPath -Parent | Split-Path -Parent }
Set-Location $Root

# Guards
if(-not (Get-Command git -ErrorAction SilentlyContinue)){ throw "git missing" }
$dirty = git status --porcelain
if($dirty){ throw "Working tree not clean. Commit/stash before release." }

# Ensure tests & lint pass
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'ops\lint.ps1')
if($LASTEXITCODE -ne 0){ throw "lint failed" }
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'ops\self_test.ps1') -CI
if($LASTEXITCODE -ne 0){ throw "self_test failed" }

# Semver file
$verFile = Join-Path $Root 'VERSION'
if(-not (Test-Path $verFile)){ '0.1.0' | Set-Content -Encoding ASCII $verFile }
$cur = (Get-Content $verFile -Raw).Trim()
$parts = $cur -split '\.'
[int]$maj=[int]$parts[0]; [int]$min=[int]$parts[1]; [int]$pat=[int]$parts[2]
switch ($Bump) {
  'patch' { $pat++ }
  'minor' { $min++; $pat=0 }
  'major' { $maj++; $min=0; $pat=0 }
}
$new = "$maj.$min.$pat"
$new | Set-Content -Encoding ASCII $verFile

# Changelog from last tag
$lastTag = (git describe --tags --abbrev=0 2>$null)
$range = if($lastTag){ "$lastTag..HEAD" } else { "" }
$cl = Join-Path $Root 'CHANGELOG.md'
$hdr = "## v$new - $(Get-Date -Format yyyy-MM-dd)"
$log = if($range){ git log --pretty=format:"* %s (%h)" $range } else { @("* initial release") }
Add-Content -Encoding UTF8 -Path $cl -Value @("","# "+(Split-Path $Root -Leaf),"",$hdr) -ErrorAction SilentlyContinue
Add-Content -Encoding UTF8 -Path $cl -Value $log

# Commit, tag, push
git add VERSION CHANGELOG.md
git commit -m "release: v$new"
git tag -a "v$new" -m "Operion v$new"
git push
git push --tags
Write-Host "Released v$new" -ForegroundColor Green
