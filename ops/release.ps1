param([string]$Bump = 'patch') # major|minor|patch or explicit x.y.z
$ErrorActionPreference='Stop'
$root = (git rev-parse --show-toplevel 2>$null); if(-not $root){ throw "Not in a git repo" }
Set-Location $root
$verFile = Join-Path $root 'VERSION'
if (Test-Path $verFile) { $v = (Get-Content $verFile -Raw).Trim() } else { $v = '0.0.0' }

function Bump($v,$kind){
  if ($kind -match '^\d+\.\d+\.\d+$') { return $kind }
  $p = $v -split '\.'; if ($p.Count -lt 3) { $p = @('0','0','0') }
  $maj=[int]$p[0]; $min=[int]$p[1]; $pat=[int]$p[2]
  switch($kind){
    'major' { $maj++; $min=0; $pat=0 }
    'minor' { $min++; $pat=0 }
    default { $pat++ }
  }
  return "$maj.$min.$pat"
}
$new = Bump $v $Bump
Set-Content -Encoding ASCII -Path $verFile -Value "$new`n"
git add VERSION
git commit -m "chore: release v$new" 2>$null | Out-Null
git tag -a "v$new" -m "Operion v$new"
git push --follow-tags
Write-Host "Released v$new"
