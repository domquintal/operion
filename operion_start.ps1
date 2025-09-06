param()
$ErrorActionPreference='Stop'

# Resolve script directory even if PSCommandPath is empty
$scriptPath = $PSCommandPath; if ([string]::IsNullOrWhiteSpace($scriptPath)) { $scriptPath = $MyInvocation.MyCommand.Path }
$ScriptDir  = if ([string]::IsNullOrWhiteSpace($scriptPath)) { (Get-Location).Path } else { Split-Path -Parent "" }

$Cfg  = Join-Path $ScriptDir 'start.target'
$Logs = Join-Path $ScriptDir '_logs'
[void][IO.Directory]::CreateDirectory($Logs)

# Logging
$stamp = Get-Date
$Global:Log = Join-Path $Logs ("manual_run_{0:yyyyMMdd_HHmmss}.log" -f $stamp)
[IO.File]::WriteAllText($Global:Log, "===== LOG STARTED $((Get-Date).ToString('o')) =====
",[Text.Encoding]::UTF8)
function Write-Log([string]$m){ [IO.File]::AppendAllText($Global:Log,"[ $((Get-Date).ToString('o')) ] $m
",[Text.Encoding]::UTF8) }

if (-not (Test-Path $Cfg)) { Write-Log "Missing start.target at $Cfg"; exit 2 }
$rel = (Get-Content -Raw $Cfg).Trim()
if ([string]::IsNullOrWhiteSpace($rel)) { Write-Log "start.target empty"; exit 2 }

# Resolve target (prefer relative to wrapper dir)
$Target = Convert-Path (Join-Path $ScriptDir $rel) -ErrorAction SilentlyContinue
if (-not $Target -and (Test-Path $rel)) { $Target = Convert-Path $rel -ErrorAction SilentlyContinue }
if (-not $Target -or -not (Test-Path $Target)) { Write-Log "Target missing: $rel"; exit 2 }

Write-Log "Launching -> $Target"

# Call child and capture combined output
$ext = [IO.Path]::GetExtension($Target).ToLowerInvariant()
$combined = ""
try {
  if ($ext -eq ".ps1") {
    $combined = & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  } elseif ($ext -in ".cmd",".bat",".exe") {
    $combined = & $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  } else {
    $combined = & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  }
  if (-not [string]::IsNullOrWhiteSpace($combined)) {
    Write-Log "--- CHILD OUTPUT (combined) ---"
    [IO.File]::AppendAllText($Global:Log, $combined + "
", [Text.Encoding]::UTF8)
  }
  Write-Log ("Child exit code: " + ($code -as [int]))
} catch {
  Write-Log ("EXCEPTION: " + $_.Exception.Message)
}
Write-Log "Wrapper end."
