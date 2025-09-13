param([switch]$CI)
$ErrorActionPreference='Stop'

# If inside repo, normalize working dir
$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -eq 0 -and $top) { Set-Location $top }

# Paths to exclude from lint
$excludeRegex = '(\\|/)(ops\\z_parked|\.git|venv|\.venv)(\\|/)'  # skip parked + env + .git

$files = Get-ChildItem -Recurse -File -Filter *.ps1 | Where-Object {
  $_.FullName -notmatch $excludeRegex
}
$errs = @()
foreach($f in $files){
  $t=$null;$e=$null
  [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$t,[ref]$e) | Out-Null
  if($e){
    $errs += $e | ForEach-Object {
      "[ERR] {0}:{1}:{2}" -f $f.FullName,$_.Extent.StartLineNumber,$_.Message
    }
  }
}
if($errs.Count){
  $errs | ForEach-Object { Write-Host $_ -ForegroundColor Red }
  exit 1
}else{
  Write-Host "[OK] Lint passed ($($files.Count) files)"
  exit 0
}
