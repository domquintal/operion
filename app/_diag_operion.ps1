$ErrorActionPreference = "Stop"

function W([string]$m){ Write-Host "[DIAG] $m" }

# Real starter resolved at shim creation time:
$Real = "C:\\Users\\Domin\\operion_repo\\app\\operion_app\.ps1"
W "Real target -> $Real"

$ext = [IO.Path]::GetExtension($Real).ToLowerInvariant()
$exit = 0

try {
  if ($ext -eq ".ps1") {
    W "Invoking PowerShell script..."
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Real 2>&1 |
      ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
          Write-Host "[CHILD-ERR] $_"
          if ($_.Exception) { Write-Host ("[CHILD-EXC] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message) }
        } else { Write-Host "[CHILD-OUT] $_" }
      }
    $exit = $LASTEXITCODE
  }
  elseif ($ext -eq ".cmd" -or $ext -eq ".bat" -or $ext -eq ".exe") {
    W "Invoking native process..."
    & $Real 2>&1 | ForEach-Object { Write-Host "[CHILD] $_" }
    $exit = $LASTEXITCODE
  }
  else {
    W ("Unknown extension (" + $ext + "). Trying as PowerShell...")
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $Real 2>&1 |
      ForEach-Object { Write-Host "[CHILD-OUT] $_" }
    $exit = $LASTEXITCODE
  }
}
catch {
  Write-Host ("[CATCH] " + $_.Exception.GetType().FullName + ": " + $_.Exception.Message)
  $exit = 999
}

W ("Child exit code: " + $exit)
exit $exit
