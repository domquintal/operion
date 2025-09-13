$ErrorActionPreference='Stop'
$PinCode = "0000"
$Max = 3
for($i=1;$i -le $Max;$i++){
  $s = Read-Host "Enter PIN ($i/$Max)" -AsSecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try   { $entered = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
  finally { if($b -ne [IntPtr]::Zero){ [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) } }
  if($entered -eq $PinCode){
    & (Join-Path (Split-Path $PSCommandPath -Parent) 'launch.ps1')
    exit $LASTEXITCODE
  }
}
Write-Host "Too many invalid attempts." -ForegroundColor Red
exit 1
