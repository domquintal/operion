# Operion Notify (PowerShell-only, no XAML)
param(
  [string]$Title = "Operion",
  [string]$Body  = "Done",
  [int]$Ms = 3000
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ni = New-Object System.Windows.Forms.NotifyIcon
$ni.Icon = [System.Drawing.SystemIcons]::Information
$ni.BalloonTipTitle = $Title
$ni.BalloonTipText  = $Body
$ni.Visible = $true
$ni.ShowBalloonTip($Ms)
Start-Sleep -Milliseconds ($Ms + 500)
$ni.Dispose()
