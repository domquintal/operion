param([switch]$CI)
$ErrorActionPreference="Stop"

# robust script dir
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
  $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  if (-not $ScriptDir) { $ScriptDir = (Resolve-Path ".\ops").Path }
}

try { . "$ScriptDir\common.ps1" } catch {
  $d = Join-Path $ScriptDir "..\_logs"
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  $f = Join-Path $d ("sanity_fallback_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  "Failed to load common.ps1: $($_.Exception.Message)" | Out-File -Encoding UTF8 -LiteralPath $f
  "SANITY: FAIL (see $f)"; exit 2
}

$log   = New-LogFile -Prefix "sanity"
$pass  = $true
$checks = New-Object System.Text.StringBuilder
function AddCheck($ok,$label){ $null=$checks.AppendLine(('  {0} {1}' -f ($(if($ok){"✓"}else{"✗"}),$label))); if(-not $ok){$script:pass=$false} }

# 1) repo
$repo = Test-Path (Join-Path $ScriptDir "..\.git"); AddCheck $repo "Git repo present"
if ($repo) {
  $clean = Git-IsClean; AddCheck $clean "Git working tree clean"
  $branch = Git-Branch; $short = Git-Short
  Add-Content -LiteralPath $log -Value ("branch: {0} @ {1}" -f $branch, $short)
}

# 2) version
$verPath = Join-Path $ScriptDir "..\VERSION.txt"
if (-not (Test-Path $verPath)) { "0.1.0" | Out-File -Encoding utf8 -LiteralPath $verPath }
$ver = (Get-Content -Raw -LiteralPath $verPath).Trim()
AddCheck ($ver -match '^\d+\.\d+\.\d+$') "VERSION.txt present ($ver)"

# 3) _logs writable
try {
  $probeDir = Join-Path $ScriptDir "..\_logs"
  New-Item -ItemType Directory -Force -Path $probeDir | Out-Null
  $probe = Join-Path $probeDir "._probe"
  "ok" | Out-File -LiteralPath $probe -Encoding ascii -Force
  Remove-Item -LiteralPath $probe -Force
  $writable = $true
} catch { $writable = $false }
AddCheck $writable "_logs writable"

$banner = if ($pass) { "PASS" } else { "FAIL" }
"=== Operion Sanity =============================" | Tee-Object -FilePath $log
("Result : {0}" -f $banner)                        | Tee-Object -FilePath $log -Append
("Version: {0}" -f $ver)                           | Tee-Object -FilePath $log -Append
"Checks :"                                         | Tee-Object -FilePath $log -Append
$checks.ToString().TrimEnd()                        | Tee-Object -FilePath $log -Append
("Log    : {0}" -f $log)                           | Tee-Object -FilePath $log -Append

if ($CI) { exit ($(if($pass){0}else{1})) } else { exit ($(if($pass){0}else{2})) }
