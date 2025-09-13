function Get-OperionConfig {
  param([string]$OpsDir)
  $ErrorActionPreference = 'Stop'
  if (-not $OpsDir) { $OpsDir = Split-Path $PSCommandPath -Parent }
  $cfg = Join-Path $OpsDir 'config.psd1'
  if (!(Test-Path $cfg)) { throw "Missing config: $cfg" }
  $h = Import-PowerShellDataFile -Path $cfg
  # resolve relative paths against ops\
  $resolve = {
    param($p)
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    if ([System.IO.Path]::IsPathRooted($p)) { return (Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue)?.Path ?? $p }
    $abs = Join-Path $OpsDir $p
    return (Resolve-Path -LiteralPath $abs -ErrorAction SilentlyContinue)?.Path ?? $abs
  }
  $out = [ordered]@{}
  $out.Pin                 = "$($h.Pin)"
  $out.EnableDangerButtons = [bool]$h.EnableDangerButtons
  $out.LogsPath            = & $resolve $h.LogsPath
  $out.LauncherPath        = & $resolve $h.LauncherPath

  # Fallback launcher discovery if not found
  if (-not ($out.LauncherPath -and (Test-Path $out.LauncherPath))) {
    $root = Split-Path $OpsDir -Parent
    $cand = Get-ChildItem -Path $root -Recurse -Filter 'run.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cand) { $out.LauncherPath = $cand.FullName }
    if (-not $cand) {
      $cmd = Get-ChildItem -Path $root -Recurse -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|start|run' } | Select-Object -First 1
      if ($cmd) { $out.LauncherPath = $cmd.FullName }
    }
    if (-not (Test-Path $out.LauncherPath)) {
      $py = Get-ChildItem -Path $root -Recurse -Include 'main.py','app.py' -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($py) {
        $shim = Join-Path $OpsDir 'launch_shim.ps1'
@"
`$ErrorActionPreference='Stop'
`$Target = '$($py.FullName -replace '\\','\\')'
`$Root   = '$($root -replace '\\','\\')'
`$VenvPy = Join-Path `$Root 'venv\Scripts\python.exe'
if (Test-Path `$VenvPy) { & `$VenvPy "`$Target" } else { & python "`$Target" }
"@ | Set-Content -Encoding UTF8 $shim
        $out.LauncherPath = $shim
      }
    }
  }
  if (-not $out.LogsPath) {
    $out.LogsPath = Join-Path (Split-Path $OpsDir -Parent) '_logs'
  }
  New-Item -ItemType Directory -Force -Path $out.LogsPath | Out-Null
  return [pscustomobject]$out
}
Export-ModuleMember -Function Get-OperionConfig
