function Get-OperionConfig {
  param([string]$OpsDir)
  $ErrorActionPreference = 'Stop'

  if (-not $OpsDir) { $OpsDir = Split-Path $PSCommandPath -Parent } # likely ops\lib

  $cand1 = Join-Path $OpsDir 'config.psd1'                           # if OpsDir == ops
  $cand2 = Join-Path (Split-Path $OpsDir -Parent) 'config.psd1'      # if OpsDir == ops\lib

  $cfgPath = $null
  if (Test-Path $cand1) { $cfgPath = $cand1 }
  elseif (Test-Path $cand2) { $cfgPath = $cand2 }
  else { throw "Missing config: $cand1 OR $cand2" }

  $h = Import-PowerShellDataFile -Path $cfgPath

  $resolve = {
    param($base,$p)
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ([System.IO.Path]::IsPathRooted($p)) {
      try { return (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { return $p }
    }
    $abs = Join-Path $base $p
    try { return (Resolve-Path -LiteralPath $abs -ErrorAction Stop).Path } catch { return $abs }
  }

  # If OpsDir points at ops\lib, base for relative paths should be ops
  $opsBase = if (Test-Path (Join-Path $OpsDir 'config.psd1')) { $OpsDir } else { Split-Path $OpsDir -Parent }
  $repoRoot = Split-Path $opsBase -Parent

  $out = [ordered]@{}
  $out.Pin                 = "$($h.Pin)"
  $out.EnableDangerButtons = [bool]$h.EnableDangerButtons
  $out.LogsPath            = & $resolve $opsBase $h.LogsPath
  $out.LauncherPath        = & $resolve $opsBase $h.LauncherPath

  if (-not $out.LogsPath) { $out.LogsPath = Join-Path $repoRoot '_logs' }
  New-Item -ItemType Directory -Force -Path $out.LogsPath | Out-Null

  return [pscustomobject]$out
}
Export-ModuleMember -Function Get-OperionConfig
