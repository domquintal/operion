param(
  [Parameter(Mandatory=$true)][string]$Version,  # e.g. v0.1.0  (must start with "v")
  [switch]$DryRun
)
$ErrorActionPreference='Stop'
if ($Version -notmatch '^v\d+\.\d+\.\d+$') { throw 'Version must look like v0.1.0' }

# sanity
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { throw 'Not a git repo' }
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'main') { throw "Release only from main (current: $branch)" }
$dirty = git status --porcelain
if ($dirty) { throw 'Working tree not clean' }

# get previous tag (optional)
$prev = ''
try { $prev = (git describe --tags --abbrev=0).Trim() } catch {}

# build changelog section
$today = (Get-Date).ToString('yyyy-MM-dd')
$changelogPath = Join-Path (Get-Location) 'CHANGELOG.md'
$header = "## $Version - $today"
$range = if ($prev) { "$prev..HEAD" } else { "" }
$items = if ($prev) { (git log --pretty='- %s' $range) } else { (git log --pretty='- %s') }
if (-not $items) { $items = @('- Initial release') }

# update CHANGELOG.md (prepend)
$tmp = New-TemporaryFile
$nl = [Environment]::NewLine
"$header$nl$($items -join $nl)$nl$nl" | Out-File -FilePath $tmp -Encoding UTF8
if (Test-Path $changelogPath) { Get-Content $changelogPath -Raw | Add-Content -Path $tmp -Encoding UTF8 }
Move-Item $tmp $changelogPath -Force

if ($DryRun) {
  Write-Host "[DRY] Would commit CHANGELOG and tag $Version" -ForegroundColor Yellow
  Write-Host "[DRY] Preview of CHANGELOG.md:" -ForegroundColor Yellow
  Get-Content $changelogPath -TotalCount 30 | ForEach-Object { Write-Host $_ }
  exit 0
}

git add CHANGELOG.md
git commit -m "chore(release): $Version changelog"
git tag -a "$Version" -m "$Version"
git push origin main
git push origin "$Version"
Write-Host "Released $Version" -ForegroundColor Green
