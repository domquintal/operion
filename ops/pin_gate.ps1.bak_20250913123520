$ErrorActionPreference = 'Stop'
$Pin = '0000'            # change if needed
$MaxTries = 3
$LogDir = 'C:\\Users\\Domin\\Operion\\_logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Audit = Join-Path $LogDir ("pin_gate_" + (Get-Date -Format 'yyyyMMdd') + ".log")

function Write-Log($msg) {
  "2025-09-12 16:31:41" + "  " + $msg | Out-File -FilePath $Audit -Append -Encoding UTF8
}

Write-Log "PIN gate invoked"
for ($i=1; $i -le $MaxTries; $i++) {
  $secure = Read-Host "Enter PIN (attempt $i of $MaxTries)" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { $entered = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) } finally { if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) } }
  if ($entered -eq $Pin) {
    Write-Log "PIN OK"
    # Call log retention before launch
    & "C:\\Users\\Domin\\Operion\\ops\\log_retention.ps1" 2>
    # Launch real app
    & "C:\\Users\\Domin\\Operion\\app\\run.ps1"
    exit 0
  } else {
    Write-Log "PIN FAIL"
  }
}
Write-Host "Too many invalid attempts." -ForegroundColor Red
Write-Log "PIN lockout"
exit 1
