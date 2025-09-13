$ErrorActionPreference='Stop'
function Ok($m){Write-Host "[ OK ] $m" -ForegroundColor Green}
function Warn($m){Write-Host "[WARN] $m" -ForegroundColor Yellow}
function Err($m){Write-Host "[ERR] $m" -ForegroundColor Red}
$root = Split-Path (Split-Path $PSCommandPath -Parent) -Parent
$ops  = Split-Path $PSCommandPath -Parent
$logs = Join-Path $root '_logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

# Git & repo
if(-not (Get-Command git -ErrorAction SilentlyContinue)){ Err "git not found in PATH"; exit 1 } else { Ok "git present" }
Set-Location $root
if(-not (Test-Path .git)){ Err "not a git repo: $root"; exit 1 } else { Ok "git repo ok" }

# Remote/branch
try { git fetch origin 2>$null | Out-Null; Ok "git fetch origin ok" } catch { Warn "git fetch origin failed: $($_.Exception.Message)" }
$branch=(git rev-parse --abbrev-ref HEAD).Trim()
if([string]::IsNullOrWhiteSpace($branch)){ Err "no current branch"; exit 1 } else { Ok "branch: $branch" }
$counts=''; try{$counts=(git rev-list --left-right --count origin/$branch...HEAD)}catch{$counts=''}
if($counts){$p=$counts -split '\s+'; $behind=[int]$p[0]; $ahead=[int]$p[1]; Write-Host "Ahead=$ahead Behind=$behind"} else { Warn "couldn't compute ahead/behind" }

# Launcher discovery
$launcher = Join-Path $root 'run.ps1'
if(-not (Test-Path $launcher)){
  $cand = Get-ChildItem -Path $root -Recurse -Filter 'run.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if($cand){ $launcher=$cand.FullName } else {
    $cmd = Get-ChildItem -Path $root -Recurse -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|start|run' } | Select-Object -First 1
    if($cmd){ $launcher=$cmd.FullName } else {
      $py = Get-ChildItem -Path $root -Recurse -Include 'main.py','app.py' -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if($py){ $launcher=$py.FullName } else { $launcher=$null }
}}}
if($launcher){ Ok "launcher found: $launcher" } else { Warn "no launcher located (run.ps1 / *.cmd / main.py)"; }

# Logs writable + retention
$probe = Join-Path $logs ("write_test_" + (Get-Date -Format 'HHmmss') + ".log")
"test" | Out-File -FilePath $probe -Encoding UTF8
if(Test-Path $probe){ Ok "logs writable: $logs"; Remove-Item $probe -Force -ErrorAction SilentlyContinue } else { Err "cannot write to $logs" }

$ret = Join-Path $ops 'log_retention.ps1'
if(Test-Path $ret){ try{ & $ret; Ok "log retention ran" } catch { Warn "log retention error: $($_.Exception.Message)" } } else { Warn "log_retention.ps1 missing" }

# Parity & push plumbing
$par = Join-Path $ops 'parity_check.ps1'
if(Test-Path $par){ try{ & $par; Ok "parity_check ran" } catch { Warn "parity_check error: $($_.Exception.Message)" } } else { Warn "parity_check.ps1 missing" }

$fs = Join-Path $ops 'force_sync.ps1'
if(Test-Path $fs){ Ok "force_sync present (not executing)"} else { Warn "force_sync.ps1 missing" }

Write-Host "`n=== Self-test complete ==="
