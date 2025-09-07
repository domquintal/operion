$ErrorActionPreference="Stop"

function New-LogFile {
  param([string]$Prefix="run")
  $dir = Join-Path $PSScriptRoot "..\_logs"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  Join-Path $dir "$Prefix`_$stamp.log"
}

function Write-Log([string]$msg,[string]$lvl="INFO",[string]$file){
  $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $lvl, $msg
  if ($file) { Add-Content -LiteralPath $file -Value $line }
  Write-Host $line
}

function Git-IsClean {
  $porcelain = git status --porcelain 2>$null
  if ($porcelain) { return $false } else { return $true }
}
function Git-Branch { (git rev-parse --abbrev-ref HEAD) 2>$null }
function Git-Short  { (git rev-parse --short HEAD) 2>$null }
