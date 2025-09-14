param([string]$Api="http://localhost:8000",[string]$AgentId="$env:COMPUTERNAME",[int]$IntervalSec=30)
$ErrorActionPreference="SilentlyContinue"
while ($true) {
  try { $body=@{agent_id=$AgentId;status="ok"}|ConvertTo-Json -Compress; Invoke-RestMethod -Method Post -Uri "$Api/heartbeat" -Body $body -ContentType "application/json" -TimeoutSec 5 | Out-Null } catch {}
  Start-Sleep -Seconds $IntervalSec
}
