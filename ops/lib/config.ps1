function Get-OperionConfig {
  param([string]$OpsDir,[string]$Profile)
  $ErrorActionPreference='Stop'
  if (-not $OpsDir) { $OpsDir = Split-Path $PSCommandPath -Parent }
  $cfgPath = Join-Path $OpsDir 'config.psd1'
  if (!(Test-Path $cfgPath)) { throw "Missing config: $cfgPath" }
  $cfgAll = Import-PowerShellDataFile -Path $cfgPath
  if (-not $Profile) { $Profile = $cfgAll.ActiveProfile }
  if (-not $Profile) { $Profile = 'default' }
  $p = $cfgAll.Profiles[$Profile]
  if (-not $p) { throw "Profile not found: $Profile" }

  $resolve = {
    param($base,$p)
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ([System.IO.Path]::IsPathRooted($p)) { return (Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue)?.Path ?? $p }
    $abs = Join-Path $base $p
    return (Resolve-Path -LiteralPath $abs -ErrorAction SilentlyContinue)?.Path ?? $abs
  }

  $root = Split-Path $OpsDir -Parent
  $out  = [ordered]@{}
  $out.Pin                 = "$($p.Pin)"
  $out.EnableDangerButtons = [bool]$p.EnableDangerButtons
  $out.LogsPath            = & $resolve $root $p.LogsPath
  $out.LauncherPath        = & $resolve $root $p.LauncherPath

  # Fallback launcher discovery if not found
  if (-not ($out.LauncherPath -and (Test-Path $out.LauncherPath))) {
    $cand = Get-ChildItem -Path $root -Recurse -Filter 'run.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $out.LauncherPath = $cand.FullName }
    if (-not $cand) {
      $cmd = Get-ChildItem -Path $root -Recurse -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|start|run' } | Select-Object -First 1
      if ($cmd) { $out.LauncherPath = $cmd.FullName }
    }
  }

  if (-not $out.LogsPath) { $out.LogsPath = Join-Path $root '_logs' }
  New-Item -ItemType Directory -Force -Path $out.LogsPath | Out-Null
  return [pscustomobject]$out
}
Export-ModuleMember -Function Get-OperionConfig
