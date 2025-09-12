$ErrorActionPreference = 'Stop'
$Repo = 'C:\Users\Domin\Operion'
$Logs = 'C:\Users\Domin\Operion\_logs'
Set-Location $Repo

function Line { param([string]$t) "$("="*$t.Length)
$t
$("="*$t.Length)" }

# Ensure git + remote
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git not found" }
if (-not (Test-Path .git)) { throw "Not a git repo: $Repo" }
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { throw "No current branch" }

# Fetch and compute ahead/behind
git fetch origin | Out-Null
$local  = (git rev-parse HEAD).Trim()
try { $remote = (git rev-parse origin/$branch).Trim() } catch { $remote = "" }

# Divergence counts
$counts = ""
try { $counts = (git rev-list --left-right --count origin/$branch...HEAD) } catch {}
$behind = 0; $ahead = 0
if ($counts) {
  $parts = $counts -split "\s+"
  if ($parts.Count -ge 2) { $behind = [int]$parts[0]; $ahead = [int]$parts[1] }
}

# Working tree state
$porcelain = git status --porcelain
$clean = [string]::IsNullOrWhiteSpace($porcelain)

# What differs vs origin
$nameStatus = ""
try { $nameStatus = git diff --name-status origin/$branch...HEAD } catch {}

# Untracked (not ignored)
$untracked = git ls-files --others --exclude-standard

# Build report
$report = @()
$report += Line "OPERION PARITY CHECK"
$report += "Repo: $Repo"
$report += "Branch: $branch"
$report += "Local HEAD:  $local"
$report += "Remote HEAD: $remote"
$report += "Ahead/Behind vs origin/: +$ahead / -$behind"
$report += ""
$report += Line "Working Tree"
$report += ("Clean: " + ($clean -as [string]))
if (-not $clean) { $report += "
Changes:
$porcelain" }

$report += "
" + (Line "Diff vs origin/$branch (name-status)")
if ([string]::IsNullOrWhiteSpace($nameStatus)) { $report += "(none) (in sync or no tracked changes)" } else { $report += $nameStatus }

$report += "
" + (Line "Untracked (not ignored)")
if ([string]::IsNullOrWhiteSpace($untracked)) { $report += "(none)" } else { $report += $untracked }

# Save log
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path $Logs "parity_$stamp.log"
$report -join "
" | Out-File -FilePath $logPath -Encoding UTF8
Write-Host "Parity log:" $logPath -ForegroundColor Cyan

# Also print short summary to console
"
Summary: Branch=$branch Local=$local Remote=$remote Ahead=$ahead Behind=$behind Clean=$clean"
