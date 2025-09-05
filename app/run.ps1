param()
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-Tab([string]$name){
  $tab = New-Object System.Windows.Forms.TabPage
  $tab.Text = $name
  $tab.Padding = '10,10'
  return $tab
}
function New-LogBox(){ $tb = New-Object System.Windows.Forms.TextBox; $tb.Multiline=$true; $tb.ReadOnly=$true; $tb.ScrollBars='Vertical'; $tb.Font = New-Object System.Drawing.Font('Consolas',10); $tb.Dock='Fill'; $tb }
function Add-Log([System.Windows.Forms.TextBox]$tb,[string]$msg){
  $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $tb.AppendText("[$ts] $msg`r`n")
}

# Window
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "Operion"
$form.StartPosition = "CenterScreen"
$form.Size          = New-Object System.Drawing.Size(900, 560)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock='Fill'
$form.Controls.Add($tabs)

# Tabs
$tabAutomation   = New-Tab 'Automation'
$tabAnalytics    = New-Tab 'Analytics'
$tabSecurity     = New-Tab 'Security'
$tabIntegrations = New-Tab 'Integrations'
$tabSettings     = New-Tab 'Settings'
$tabs.TabPages.AddRange(@($tabAutomation,$tabAnalytics,$tabSecurity,$tabIntegrations,$tabSettings))

# === Automation ===
$autoPanel = New-Object System.Windows.Forms.Panel; $autoPanel.Dock='Top'; $autoPanel.Height=60
$btnRunFlows = New-Object System.Windows.Forms.Button; $btnRunFlows.Text='Run Automations'; $btnRunFlows.Width=160; $btnRunFlows.Height=32; $btnRunFlows.Left=10; $btnRunFlows.Top=10
$btnSchedule = New-Object System.Windows.Forms.Button; $btnSchedule.Text='Schedule Task'; $btnSchedule.Left=180; $btnSchedule.Top=10; $btnSchedule.Width=140; $btnSchedule.Height=32
$autoLog = New-LogBox
$tabAutomation.Controls.Add($autoLog); $tabAutomation.Controls.Add($autoPanel); $autoPanel.Controls.AddRange(@($btnRunFlows,$btnSchedule))
$btnRunFlows.Add_Click({ Add-Log $autoLog "Automation: running example flow..."; Start-Sleep 0.4; Add-Log $autoLog "Step 1"; Start-Sleep 0.4; Add-Log $autoLog "Step 2"; Add-Log $autoLog "Done ✅" })
$btnSchedule.Add_Click({ Add-Log $autoLog "Scheduling placeholder task… (wire to real scheduler next)" })

# === Analytics (Dashboards) ===
$anaPanel = New-Object System.Windows.Forms.Panel; $anaPanel.Dock='Top'; $anaPanel.Height=60
$btnRefresh = New-Object System.Windows.Forms.Button; $btnRefresh.Text='Refresh Dashboards'; $btnRefresh.Width=180; $btnRefresh.Height=32; $btnRefresh.Left=10; $btnRefresh.Top=10
$btnExport = New-Object System.Windows.Forms.Button; $btnExport.Text='Export CSV'; $btnExport.Left=200; $btnExport.Top=10; $btnExport.Width=140; $btnExport.Height=32
$anaLog = New-LogBox
$tabAnalytics.Controls.Add($anaLog); $tabAnalytics.Controls.Add($anaPanel); $anaPanel.Controls.AddRange(@($btnRefresh,$btnExport))
$btnRefresh.Add_Click({ Add-Log $anaLog "Refreshing KPIs… (plug your data sources here)" })
$btnExport.Add_Click({ $p=Join-Path (Split-Path -Parent $PSCommandPath) '..\_exports'; New-Item -ItemType Directory -Force -Path $p | Out-Null; $f=Join-Path $p ("dashboard_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date)); 'metric,value',"revenue,12345","leads,67" | Set-Content $f; Add-Log $anaLog "Exported $f" })

# === Security ===
$secPanel = New-Object System.Windows.Forms.Panel; $secPanel.Dock='Top'; $secPanel.Height=60
$btnAudit = New-Object System.Windows.Forms.Button; $btnAudit.Text='Run Security Audit'; $btnAudit.Width=160; $btnAudit.Height=32; $btnAudit.Left=10; $btnAudit.Top=10
$btnHard = New-Object System.Windows.Forms.Button; $btnHard.Text='Apply Hardening'; $btnHard.Left=180; $btnHard.Top=10; $btnHard.Width=140; $btnHard.Height=32
$secLog = New-LogBox
$tabSecurity.Controls.Add($secLog); $tabSecurity.Controls.Add($secPanel); $secPanel.Controls.AddRange(@($btnAudit,$btnHard))
$btnAudit.Add_Click({ Add-Log $secLog "Security: scanning (placeholder)…"; Start-Sleep 0.5; Add-Log $secLog "No critical issues found." })
$btnHard.Add_Click({ Add-Log $secLog "Applying baseline hardening (placeholder)…"; Start-Sleep 0.5; Add-Log $secLog "Baseline applied." })

# === Integrations ===
$intPanel = New-Object System.Windows.Forms.Panel; $intPanel.Dock='Top'; $intPanel.Height=60
$btnConnect = New-Object System.Windows.Forms.Button; $btnConnect.Text='Connect Service…'; $btnConnect.Width=160; $btnConnect.Height=32; $btnConnect.Left=10; $btnConnect.Top=10
$btnTest = New-Object System.Windows.Forms.Button; $btnTest.Text='Test Connection'; $btnTest.Left=180; $btnTest.Top=10; $btnTest.Width=140; $btnTest.Height=32
$intLog = New-LogBox
$tabIntegrations.Controls.Add($intLog); $tabIntegrations.Controls.Add($intPanel); $intPanel.Controls.AddRange(@($btnConnect,$btnTest))
$btnConnect.Add_Click({ Add-Log $intLog "Connect dialog (placeholder). We’ll add real OAuth/API keys here." })
$btnTest.Add_Click({ Add-Log $intLog "Testing example endpoint…"; Start-Sleep 0.4; Add-Log $intLog "OK" })

# === Settings ===
$setPanel = New-Object System.Windows.Forms.TableLayoutPanel
$setPanel.Dock='Fill'; $setPanel.ColumnCount=2; $setPanel.RowCount=6; $setPanel.AutoSize=$true
$lblEnv = New-Object System.Windows.Forms.Label; $lblEnv.Text='Environment:'; $txtEnv = New-Object System.Windows.Forms.TextBox; $txtEnv.Text='prod'
$lblLog = New-Object System.Windows.Forms.Label; $lblLog.Text='Log Folder:'; $txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Text = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "_logs")
$btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text='Save Settings'; $btnSave.Width=140
$setPanel.Controls.Add($lblEnv,0,0); $setPanel.Controls.Add($txtEnv,1,0)
$setPanel.Controls.Add($lblLog,0,1); $setPanel.Controls.Add($txtLog,1,1)
$setPanel.Controls.Add($btnSave,1,5)
$tabSettings.Controls.Add($setPanel)
$btnSave.Add_Click({ [System.IO.Directory]::CreateDirectory($txtLog.Text) | Out-Null; [System.Windows.Forms.MessageBox]::Show("Saved.","Operion") })

[void]$form.ShowDialog()
