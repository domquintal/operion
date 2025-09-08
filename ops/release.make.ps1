$ErrorActionPreference="Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent $root
$ver  = (Get-Content -Raw -LiteralPath (Join-Path $repo "app\version.json") | ConvertFrom-Json)
$out  = Join-Path $repo "artifacts"; New-Item -ItemType Directory -Force -Path $out | Out-Null
$zip  = Join-Path $out ("operion_" + $ver.version + "_" + $ver.build + ".zip")
# Changelog from last 20 commits
$notes = (git log -n 20 --pretty="* %h %s" 2>$null) -join "`r`n"
$notes | Out-File -Encoding UTF8 -LiteralPath (Join-Path $repo "RELEASE_NOTES.md")
# Package
$stage = Join-Path $out "stage"; if(Test-Path $stage){Remove-Item -Recurse -Force $stage}; New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item (Join-Path $repo "app") -Destination $stage -Recurse
Copy-Item (Join-Path $repo "ops") -Destination $stage -Recurse
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
Remove-Item -Recurse -Force $stage
Write-Host "Release artifact: $zip"
