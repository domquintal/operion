param([string]$Message = "patch: update")
$ErrorActionPreference='Stop'
git add -A
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
# commit may no-op if nothing changed — that's fine
git commit -m "$Message ($stamp)" 2>$null | Out-Null
git push
Write-Host "✔ Pushed: $Message ($stamp)" -ForegroundColor Green
