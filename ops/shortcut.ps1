$ErrorActionPreference = 'Stop'
$Repo    = 'C:\Users\Domin\Operion'
$Ops     = Join-Path $Repo 'ops'
$PinGate = Join-Path $Ops 'pin_gate.ps1'
$Desktop = [Environment]::GetFolderPath('Desktop')

# pick host
$PsExeCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($PsExeCmd) { $PsExe = $PsExeCmd.Source } else {
  $PsExeCmd = Get-Command powershell -ErrorAction SilentlyContinue
  if ($PsExeCmd) { $PsExe = $PsExeCmd.Source } else {
    $PsExe = "C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"
  }
}
if (-not (Test-Path $PsExe)) { throw "PowerShell executable not found." }

# icon
$IconGuess = Get-ChildItem -Path $Repo -Recurse -Include *.ico,*.png -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|logo|icon' } | Select-Object -First 1
$IconPath = if ($IconGuess) { $IconGuess.FullName } else { $null }

# maker
function New-OperionShortcut {
  param(
    [Parameter(Mandatory=$true)][string]$LnkPath,
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$ShortcutArgs,
    [string]$Icon
  )
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut     = $WScriptShell.CreateShortcut($LnkPath)
  $Shortcut.TargetPath = $Target
  if ($ShortcutArgs) { $Shortcut.Arguments = [string]$ShortcutArgs }
  if ($Icon -and (Test-Path $Icon)) { $Shortcut.IconLocation = $Icon }
  $Shortcut.WorkingDirectory = $Repo
  $Shortcut.Save()
}

# create
$Lnk = Join-Path $Desktop 'Operion.lnk'
if (Test-Path $Lnk) { Remove-Item $Lnk -Force -ErrorAction SilentlyContinue }
$ShortcutArgs = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $PinGate + '"'
New-OperionShortcut -LnkPath $Lnk -Target $PsExe -ShortcutArgs $ShortcutArgs -Icon $IconPath
if (!(Test-Path $Lnk)) { throw "Shortcut creation failed: $Lnk" } else { Write-Host "Shortcut OK -> $Lnk" -ForegroundColor Green }
