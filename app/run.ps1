Write-Output "Operion heartbeat started."
while ($true) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$ts heartbeat pid=$PID"
    Start-Sleep -Seconds 3
}
