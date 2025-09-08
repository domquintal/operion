param([ValidateSet("enable","disable")]$Mode="enable")
$ErrorActionPreference="Stop"
$taskName = "Operion.ControlV3"
$repo  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ctl   = Join-Path $repo "app\ui\ControlV3.ps1"
if($Mode -eq "enable"){
  $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$ctl`""
  $trigger= New-ScheduledTaskTrigger -AtLogOn
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Force | Out-Null
  "Startup ENABLED"
}else{
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  "Startup DISABLED"
}
