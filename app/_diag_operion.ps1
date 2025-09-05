$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Diag([string]$m){
  # Emit a distinctive prefix so our wrapper log shows it's diagnostic
  Write-Host "[DIAG] $m"
}

# Environment snapshot
Write-Diag "Machine: $(DESKTOP-PFMKA4E)"
Write-Diag "User: $([Environment]::UserName)"
Write-Diag "PSVersion: $(System.Collections.Hashtable.PSVersion)"
Write-Diag "CLR: $([Environment]::Version)"
Write-Diag "OS: $([Environment]::OSVersion.VersionString)"
Write-Diag "PWD: $(Get-Location)"

# Real starter we will run:
$Real = ""
Write-Diag "Real target -> $Real"

$ext = [IO.Path]::GetExtension($Real).ToLowerInvariant()
$exit = 0

try {
  if ($ext -eq ".ps1") {
    Write-Diag "Invoking PowerShell script…"
    & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$Real" 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        Write-Host "[CHILD-ERR] $_"
        if ($_.Exception) { Write-Host "[CHILD-EXC] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message }
        if ($_.InvocationInfo) { Write-Host "[CHILD-STACK] " + $_.InvocationInfo.PositionMessage }
      } else {
        Write-Host "[CHILD-OUT] $_"
      }
    }
    $exit = $LASTEXITCODE
  }
  elseif ($ext -in ".cmd",".bat",".exe") {
    Write-Diag "Invoking native process…"
    & "$Real" 2>&1 | ForEach-Object { Write-Host "[CHILD] $_" }
    $exit = $LASTEXITCODE
  }
  else {
    Write-Diag "Unknown extension ($ext). Trying as PowerShell…"
    & "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$Real" 2>&1 | ForEach-Object { Write-Host "[CHILD-OUT] $_" }
    $exit = $LASTEXITCODE
  }
}
catch {
  Write-Host "[CATCH] $(.Exception.GetType().FullName): $(.Exception.Message)"
  if ($_.ScriptStackTrace) { Write-Host "[STACK] $(.ScriptStackTrace)" }
  $exit = 999
}

Write-Diag "Child exit code: $exit"
exit $exit
