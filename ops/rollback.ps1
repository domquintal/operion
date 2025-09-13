param(
  [Parameter(Mandatory=$true)][string]$To,   # tag or commit (e.g., v0.1.0 or 63ec845)
  [switch]$Push                              # also push to origin (danger)
)
$ErrorActionPreference='Stop'
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { throw 'Not a git repo' }
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { throw "Rollback only from main (current: $branch)" }
$dirty = git status --porcelain
if ($dirty) { throw 'Working tree not clean' }

Write-Host "Checking out $To (detached) just to verify..." -ForegroundColor Yellow
git rev-parse "$To" *> $null
if ($LASTEXITCODE -ne 0) { throw "Unknown ref: $To" }

Write-Host "Hard resetting main to $To" -ForegroundColor Yellow
git reset --hard "$To"
Write-Host "Main now at $(git rev-parse HEAD)" -ForegroundColor Green

if ($Push) {
  Write-Host "Pushing rollback to origin/main (forced)..." -ForegroundColor Red
  git push -f origin main
}
