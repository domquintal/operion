$ErrorActionPreference="Stop"

function New-LogFile {
  param([string]$Prefix="run")
  $dir = Join-Path $PSScriptRoot "..\_logs"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  Join-Path $dir "$Prefix`_$stamp.log"
}

function Write-Log([string]$msg,[string]$lvl="INFO",[string]$file) {
  $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $lvl, $msg
  if ($file) { Add-Content -LiteralPath $file -Value $line }
  Write-Host $line
}

function Git-IsClean {
  $p = git status --porcelain 2>$null
  if ($p) { return $false } else { return $true }
}
function Git-Branch { (git rev-parse --abbrev-ref HEAD) 2>$null }
function Git-Short  { (git rev-parse --short HEAD) 2>$null }

function Read-Json($path) {
  if (-not (Test-Path $path)) { return $null }
  return (Get-Content -Raw -LiteralPath $path | ConvertFrom-Json)
}

function Ensure-Shortcut {
  param([string]$LnkPath,[string]$Target,[string]$Args,[string]$WorkingDir,[string]$Icon="")
  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut($LnkPath)
  $lnk.TargetPath   = $Target
  if ($Args)       { $lnk.Arguments   = $Args }
  if ($WorkingDir) { $lnk.WorkingDirectory = $WorkingDir }
  if ($Icon)       { $lnk.IconLocation = $Icon }
  $lnk.Save()
}
