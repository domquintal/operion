param([switch]$FailOnWarn)
$ErrorActionPreference='Stop'
$errs=@(); $warns=@()
Get-ChildItem -Recurse -File -Include *.ps1 | ForEach-Object {
  $tokens=$null; $parseErr=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$parseErr)
  if($parseErr){ $parseErr | ForEach-Object { $errs += "[ERR] $($_.Extent.File):$($_.Extent.StartLineNumber):$($_.Message)" } }
}
if($errs.Count){ $errs | ForEach-Object { Write-Host $_ -ForegroundColor Red }; exit 1 }
if($FailOnWarn -and $warns.Count){ $warns | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }; exit 2 }
Write-Host "[ OK ] lint: no syntax errors"
