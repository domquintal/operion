param(
  [ValidateSet("default")] [string]$Profile = "default"
)
$ErrorActionPreference='Stop'
$Ops = Split-Path $PSCommandPath -Parent
. (Join-Path $Ops 'lib\config.ps1')
$CFG = Get-OperionConfig -OpsDir $Ops -Profile $Profile

function Pause-Enter { Write-Host ""; Read-Host "Press ENTER to continue" | Out-Null }

function Do-Launch      { $lr=Join-Path $Ops 'log_retention.ps1'; if(Test-Path $lr){ & $lr 2>$null }; if($CFG.LauncherPath -and (Test-Path $CFG.LauncherPath)){ & $CFG.LauncherPath } else { Write-Host "No launcher found." -Foreground Yellow } }
function Do-Lint        { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'lint.ps1') }
function Do-SelfTest    { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'self_test.ps1') -CI }
function Do-Parity      { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'parity_check.ps1') }
function Do-Snapshot    { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'snapshot.ps1') }
function Do-PushLocal   { if($CFG.EnableDangerButtons){ pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'actions\push_local.ps1') } else { Write-Host "Disabled in config." -Foreground Yellow } }
function Do-ResetRemote { if($CFG.EnableDangerButtons){ pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'actions\reset_to_remote.ps1') } else { Write-Host "Disabled in config." -Foreground Yellow } }
function Do-Release     { param([string]$Bump='patch'); pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Ops 'release.ps1') -Bump $Bump }

while($true){
  Clear-Host
  Write-Host "== OPERION TASKS (profile: $Profile) ==" -ForegroundColor Cyan
  Write-Host "[1] Launch App"
  Write-Host "[2] Lint"
  Write-Host "[3] Self-test"
  Write-Host "[4] Parity Check"
  Write-Host "[5] Snapshot"
  Write-Host "[6] Force Sync → Push Local"
  Write-Host "[7] Force Sync → Reset to Remote (DANGER)"
  Write-Host "[8] Release (patch)"
  Write-Host "[9] Release (minor)"
  Write-Host "[0] Exit"
  $c = Read-Host "Select"
  switch($c){
    '1' { Do-Launch;      Pause-Enter }
    '2' { Do-Lint;        Pause-Enter }
    '3' { Do-SelfTest;    Pause-Enter }
    '4' { Do-Parity;      Pause-Enter }
    '5' { Do-Snapshot;    Pause-Enter }
    '6' { Do-PushLocal;   Pause-Enter }
    '7' { Do-ResetRemote; Pause-Enter }
    '8' { Do-Release -Bump 'patch'; Pause-Enter }
    '9' { Do-Release -Bump 'minor'; Pause-Enter }
    '0' { break }
    default { }
  }
}
