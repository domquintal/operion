param([ValidateSet("major","minor","patch")]$Part="patch")
$ErrorActionPreference="Stop"
$verFile = Join-Path (Split-Path -Parent $PSScriptRoot) "app\version.json"
$obj = Get-Content -Raw -LiteralPath $verFile | ConvertFrom-Json
$v = [System.Version]$obj.version
switch($Part){ "major"{$v=[version]::new($v.Major+1,0,0)} "minor"{$v=[version]::new($v.Major,$v.Minor+1,0)} "patch"{$v=[version]::new($v.Major,$v.Minor,$v.Build+1)} }
$obj.version = "$($v.Major).$($v.Minor).$($v.Build)"; $obj.build = (Get-Date -Format "yyyyMMdd.HHmm")
$obj | ConvertTo-Json | Out-File -Encoding UTF8 -LiteralPath $verFile
Write-Host "Bumped to $($obj.version) ($($obj.build))"
