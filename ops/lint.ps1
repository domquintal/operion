$ErrorActionPreference='Stop'
# Ensure analyzer
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
  try { Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop | Out-Null } catch { }
}
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
  Write-Host "[WARN] PSScriptAnalyzer not installed; skipping lint." -ForegroundColor Yellow
  exit 0
}
Import-Module PSScriptAnalyzer
$targets = Get-ChildItem -Recurse -Include *.ps1 -File | Where-Object { $_.FullName -notmatch '\\\.git\\' }
$results = Invoke-ScriptAnalyzer -Path $targets.FullName -Recurse -Severity Error,Warning -Verbose:$false -ErrorAction Continue
if ($results) {
  $out = Join-Path (Join-Path $PSScriptRoot '..\_logs') ("lint_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  $results | Format-Table -AutoSize | Out-String | Out-File -FilePath $out -Encoding UTF8
  Write-Host "[FAIL] Lint issues found. See: $out" -ForegroundColor Red
  $results | ForEach-Object { "{0} {1}:{2} {3}" -f $_.Severity,$_.ScriptPath,$_.Line,$_.RuleName } | Write-Host -ForegroundColor Red
  exit 2
} else {
  Write-Host "[ OK ] Lint clean"
}
