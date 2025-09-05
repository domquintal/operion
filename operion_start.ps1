param()
$ErrorActionPreference='Stop'

function Write-Log([string]$m){
  [IO.File]::AppendAllText($Global:Log, "[ $((Get-Date).ToString('o')) ] $m
", [Text.Encoding]::UTF8)
}

# Discover base directory without PSCommandPath
$KnownRoots = @("C:\Users\Domin\Operion", "C:\Users\Domin\operion")
$Base = $null

# 1) If this script's parent folder matches a known root, use it
try {
  $guess = Split-Path -Parent $MyInvocation.MyCommand.Path
  if(-not [string]::IsNullOrWhiteSpace($guess) -and (Test-Path $guess)){
    foreach($kr in $KnownRoots){
      if((Resolve-Path $guess).Path -ieq (Resolve-Path $kr).Path){ $Base = $kr; break }
    }
    if(-not $Base){ $Base = $guess }
  }
} catch {}

# 2) Fall back to repo roots
if(-not $Base){
  foreach($kr in $KnownRoots){ if(Test-Path $kr){ $Base = $kr; break } }
}

# 3) Last resort: current directory
if(-not $Base){ $Base = (Get-Location).Path }

# Paths
$Cfg  = Join-Path $Base 'start.target'
$Logs = Join-Path $Base '_logs'
[void][IO.Directory]::CreateDirectory($Logs)

$Global:Log = Join-Path $Logs ("manual_run_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
[IO.File]::WriteAllText($Global:Log, "===== LOG STARTED $((Get-Date).ToString('o')) =====
", [Text.Encoding]::UTF8)

if(-not (Test-Path $Cfg)){ Write-Log "Missing start.target at $Cfg"; exit 2 }
$rel = (Get-Content -Raw $Cfg).Trim()
if([string]::IsNullOrWhiteSpace($rel)){ Write-Log "start.target empty"; exit 2 }

# Resolve target: prefer relative to $Base, else literal
$Target = Convert-Path (Join-Path $Base $rel) -ErrorAction SilentlyContinue
if(-not $Target -and (Test-Path $rel)){ $Target = Convert-Path $rel -ErrorAction SilentlyContinue }
if(-not $Target -or -not (Test-Path $Target)){ Write-Log "Target missing: $rel"; exit 2 }

Write-Log "Launching -> $Target"

# Launch with call operator & ; capture stdout+stderr combined
$ext = [IO.Path]::GetExtension($Target).ToLowerInvariant()
$combined = ""
try{
  if($ext -eq ".ps1"){
    $combined = & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  } elseif($ext -in ".cmd",".bat",".exe"){
    $combined = & $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  } else {
    $combined = & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Target 2>&1 | Out-String
    $code = $LASTEXITCODE
  }
  if(-not [string]::IsNullOrWhiteSpace($combined)){
    Write-Log "--- CHILD OUTPUT (combined) ---"
    [IO.File]::AppendAllText($Global:Log, $combined + "
", [Text.Encoding]::UTF8)
  }
  Write-Log ("Child exit code: " + ($code -as [int]))
} catch {
  Write-Log ("EXCEPTION: " + $_.Exception.Message)
}
Write-Log "Wrapper end."
