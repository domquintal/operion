param([ValidateSet("patch","minor","major")]$Bump="patch")
$ErrorActionPreference="Stop"; . "$PSScriptRoot\common.ps1"
if (-not (Git-IsClean)) { throw "Working tree dirty. Commit or stash before update." }
$log=New-LogFile -Prefix "update"
$b=(git rev-parse --abbrev-ref HEAD).Trim()
Write-Log "Pulling origin/$b..." "INFO" $log; git pull origin $b | Out-Null
# bump version
$verPath=Join-Path $PSScriptRoot "..\VERSION.txt"; if(-not(Test-Path $verPath)){"0.1.0"|Out-File -Encoding utf8 -LiteralPath $verPath}
$ver=(Get-Content -Raw -LiteralPath $verPath).Trim()
$parts=@([int]$ver.Split('.')[0],[int]$ver.Split('.')[1],[int]$ver.Split('.')[2])
switch($Bump){"major"{$parts[0]++;$parts[1]=0;$parts[2]=0}"minor"{$parts[1]++;$parts[2]=0}default{$parts[2]++}}
$new="$($parts[0]).$($parts[1]).$($parts[2])"; $new | Out-File -Encoding utf8 -LiteralPath $verPath
Write-Log "Version -> $new" "INFO" $log
# sanity
Write-Log "Running sanity..." "INFO" $log; & "$PSScriptRoot\sanity.ps1" | Out-Null; $ok=($LASTEXITCODE -eq 0)
if($ok){ git add -A; git commit -m "chore: update → sanity PASS ($new)" | Out-Null; git push origin $b; Write-Log "DONE ✅ (sanity PASS)" "OK" $log; exit 0 } else { Write-Log "ABORT ❌ (sanity FAIL). Not pushing." "ERROR" $log; exit 2 }
