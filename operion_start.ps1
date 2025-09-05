param()
$ErrorActionPreference='Stop'
$Cfg = Join-Path (Split-Path -Parent "") 'start.target'
$Logs= Join-Path (Split-Path -Parent "") '_logs'
[void][IO.Directory]::CreateDirectory($Logs)

$stamp=Get-Date
$Global:Log=Join-Path $Logs ("manual_run_{0:yyyyMMdd_HHmmss}.log" -f $stamp)
[IO.File]::WriteAllText($Global:Log,"===== LOG STARTED $((Get-Date).ToString('o')) =====
",[Text.Encoding]::UTF8)
function Write-Log([string]$m){[IO.File]::AppendAllText($Global:Log,"[ $((Get-Date).ToString('o')) ] $m
",[Text.Encoding]::UTF8)}

if(-not(Test-Path $Cfg)){ Write-Log "Missing start.target at $Cfg"; exit 2 }
$RelTarget=(Get-Content -Raw $Cfg).Trim()
if([string]::IsNullOrWhiteSpace($RelTarget)){ Write-Log "start.target empty"; exit 2 }

# Resolve repo-relative path
$RepoRoot = Split-Path -Parent ""
$Target = Convert-Path (Join-Path $RepoRoot $RelTarget) -ErrorAction SilentlyContinue
if(-not $Target -or -not (Test-Path $Target)){ Write-Log "Target missing: $RelTarget -> ($Target)"; exit 2 }

Write-Log "Launching -> $Target"
$ext=[IO.Path]::GetExtension($Target).ToLowerInvariant()
$file = $Target
$args = ""
if($ext -eq ".ps1"){
  $file = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"
  $args = "-NoProfile -ExecutionPolicy Bypass -File "$Target""
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = $file
$psi.Arguments              = $args
$psi.WorkingDirectory       = (Split-Path -Path $Target -Parent)
$psi.UseShellExecute        = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError  = $true
$psi.CreateNoWindow         = $true

try{
  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if(-not [string]::IsNullOrWhiteSpace($stdout)){
    Write-Log '--- CHILD STDOUT ---'
    [IO.File]::AppendAllText($Global:Log, $stdout + "
",[Text.Encoding]::UTF8)
  }
  if(-not [string]::IsNullOrWhiteSpace($stderr)){
    Write-Log '--- CHILD STDERR ---'
    [IO.File]::AppendAllText($Global:Log, $stderr + "
",[Text.Encoding]::UTF8)
  }
  Write-Log ("Child exit code: " + $p.ExitCode)
}catch{
  Write-Log ("EXCEPTION: " + $_.Exception.Message)
}
Write-Log "Wrapper end."
