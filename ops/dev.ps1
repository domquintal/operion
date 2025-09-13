$ErrorActionPreference='Stop'

function Wait-Pause { Read-Host 'Press Enter to continue...' | Out-Null }

function Menu {
  param([string]$Title, [string[]]$Items)
  Write-Host ''
  Write-Host "=== $Title ===" -ForegroundColor Cyan
  for ($i=0; $i -lt $Items.Count; $i++) { '{0}) {1}' -f ($i+1), $Items[$i] | Write-Host }
  '0) Exit' | Write-Host
  Read-Host 'Select'
}

$root = Split-Path $PSCommandPath -Parent | Split-Path -Parent
Set-Location $root

$items = @(
  'Self-test (ops/self_test.ps1 -CI)',
  'Parity check',
  'Open logs folder',
  'Push local → remote (safe when local is truth)',
  'Reset local ← remote (destructive!)',
  'Snapshot tree + hashes',
  'Cut release (tag + CHANGELOG)'
)

while ($true) {
  $sel = Menu 'Operion Dev' $items
  switch ($sel) {
    '1' { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/self_test.ps1' -CI; Wait-Pause }
    '2' { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/parity_check.ps1'; Wait-Pause }
    '3' { $logs = Join-Path $root '_logs'; if (Test-Path $logs) { Start-Process explorer.exe "$logs" } else { Write-Host 'No _logs folder.' -ForegroundColor Yellow }; Wait-Pause }
    '4' { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/force_sync.ps1' -Mode push_local -Yes; Wait-Pause }
    '5' { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/force_sync.ps1' -Mode reset_to_remote -Yes; Wait-Pause }
    '6' { pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/snapshot.ps1'; Wait-Pause }
    '7' {
          $yn = Read-Host 'Dry run first? y/N'
          $tag = Read-Host 'Version tag (e.g., v0.1.0)'
          if ($yn -match '^[yY]') {
            pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/release.ps1' -Version "$tag" -DryRun
          } else {
            pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File 'ops/release.ps1' -Version "$tag"
          }
          Wait-Pause
        }
    '0' { break }
    default { Write-Host 'Invalid selection.' -ForegroundColor Yellow }
  }
}
