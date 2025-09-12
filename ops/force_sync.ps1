$ErrorActionPreference = 'Stop'
param(
  [ValidateSet('push_local','reset_to_remote')][string]$Mode,
  [switch]$Yes
)
$Repo = 'C:\Users\Domin\Operion'
Set-Location $Repo

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git not found" }
if (-not (Test-Path .git)) { throw "Not a git repo: $Repo" }
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
git fetch origin | Out-Null

switch ($Mode) {
  'push_local' {
    # Rebase onto remote first (keeps history clean), then push
    if (-not $Yes) {
      Write-Host "About to rebase local onto origin/$branch and push to remote." -ForegroundColor Yellow
      $c = Read-Host "Type YES to continue"
      if ($c -ne "YES") { throw "Aborted" }
    }
    git pull --rebase origin $branch
    git push origin $branch
    Write-Host "Done: pushed local to remote." -ForegroundColor Green
  }
  'reset_to_remote' {
    # WARNING: local changes will be LOST
    if (-not $Yes) {
      Write-Host "About to HARD RESET local to origin/$branch (LOCAL CHANGES LOST)." -ForegroundColor Red
      $c = Read-Host "Type I_UNDERSTAND to continue"
      if ($c -ne "I_UNDERSTAND") { throw "Aborted" }
    }
    git reset --hard origin/$branch
    Write-Host "Done: local reset to match remote." -ForegroundColor Green
  }
  default { throw "Specify -Mode push_local | reset_to_remote" }
}
