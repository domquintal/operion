param()
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-Tab([string]$name){ $t=New-Object System.Windows.Forms.TabPage; $t.Text=$name; $t.Padding='10,10'; return $t }
function New-LogBox(){ $tb=New-Object System.Windows.Forms.TextBox; $tb.Multiline=$true; $tb.ReadOnly=$true; $tb.ScrollBars='Vertical'; $tb.Font=New-Object System.Drawing.Font('Consolas',10); $tb.Dock='Fill'; $tb }
function Add-Log([System.Windows.Forms.TextBox]$tb,[string]$msg){ $ts=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); $tb.AppendText("[$ts] $msg
") }

$form               = New-Object System.Windows.Forms.Form
$form.Text          = "Operion"
$form.StartPosition = "CenterScreen"
$form.Size          = New-Object System.Drawing.Size(900,560)

$tabs = New-Object System.Windows.Forms.TabControl; $tabs.Dock='Fill'; $form.Controls.Add($tabs)
$tAuto=New-Tab 'Automation'; $tAna=New-Tab 'Analytics'; $tSec=New-Tab 'Security'; $tInt=New-Tab 'Integrations'; $tSet=New-Tab 'Settings'
$tabs.TabPages.AddRange(@($tAuto,$tAna,$tSec,$tInt,$tSet))

# Automation
$pA=New-Object System.Windows.Forms.Panel; $pA.Dock='Top'; $pA.Height=60
$bRun=New-Object System.Windows.Forms.Button; $bRun.Text='Run Automations'; $bRun.Width=160; $bRun.Height=32; $bRun.Left=10; $bRun.Top=10
$bSch=New-Object System.Windows.Forms.Button; $bSch.Text='Schedule Task'; $bSch.Left=180; $bSch.Top=10; $bSch.Width=140; $bSch.Height=32
$logA=New-LogBox
$tAuto.Controls.Add($logA); $tAuto.Controls.Add($pA); $pA.Controls.AddRange(@($bRun,$bSch))
$bRun.Add_Click({ Add-Log $logA "Automation flow starting…"; Start-Sleep .3; Add-Log $logA "Step 1"; Start-Sleep .3; Add-Log $logA "Step 2"; Add-Log $logA "Done ✅" })
$bSch.Add_Click({ Add-Log $logA "Scheduling placeholder… (wire real scheduler next)" })

# Analytics
$pN=New-Object System.Windows.Forms.Panel; $pN.Dock='Top'; $pN.Height=60
$bRef=New-Object System.Windows.Forms.Button; $bRef.Text='Refresh Dashboards'; $bRef.Width=180; $bRef.Height=32; $bRef.Left=10; $bRef.Top=10
$bExp=New-Object System.Windows.Forms.Button; $bExp.Text='Export CSV'; $bExp.Left=200; $bExp.Top=10; $bExp.Width=140; $bExp.Height=32
$logN=New-LogBox
$tAna.Controls.Add($logN); $tAna.Controls.Add($pN); $pN.Controls.AddRange(@($bRef,$bExp))
$bRef.Add_Click({ Add-Log $logN "Refreshing KPIs… (plug data sources here)" })
$bExp.Add_Click({ $p=(Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) '_exports'); [IO.Directory]::CreateDirectory($p) | Out-Null; $f=Join-Path $p ("dashboard_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date)); 'metric,value',"revenue,12345","leads,67" | Set-Content $f; Add-Log $logN "Exported $f" })

# Security
$pS=New-Object System.Windows.Forms.Panel; $pS.Dock='Top'; $pS.Height=60
$bAud=New-Object System.Windows.Forms.Button; $bAud.Text='Run Security Audit'; $bAud.Width=160; $bAud.Height=32; $bAud.Left=10; $bAud.Top=10
$bHard=New-Object System.Windows.Forms.Button; $bHard.Text='Apply Hardening'; $bHard.Left=180; $bHard.Top=10; $bHard.Width=140; $bHard.Height=32
$logS=New-LogBox
$tSec.Controls.Add($logS); $tSec.Controls.Add($pS); $pS.Controls.AddRange(@($bAud,$bHard))
$bAud.Add_Click({ Add-Log $logS "Security scan (placeholder)…"; Start-Sleep .4; Add-Log $logS "No critical issues found." })
$bHard.Add_Click({ Add-Log $logS "Applying baseline hardening (placeholder)…"; Start-Sleep .4; Add-Log $logS "Baseline applied." })

# Integrations
$pI=New-Object System.Windows.Forms.Panel; $pI.Dock='Top'; $pI.Height=60
$bCon=New-Object System.Windows.Forms.Button; $bCon.Text='Connect Service…'; $bCon.Width=160; $bCon.Height=32; $bCon.Left=10; $bCon.Top=10
$bTst=New-Object System.Windows.Forms.Button; $bTst.Text='Test Connection'; $bTst.Left=180; $bTst.Top=10; $bTst.Width=140; $bTst.Height=32
$logI=New-LogBox
$tInt.Controls.Add($logI); $tInt.Controls.Add($pI); $pI.Controls.AddRange(@($bCon,$bTst))
$bCon.Add_Click({ Add-Log $logI "Connect dialog (placeholder). We'll add OAuth/API keys here." })
$bTst.Add_Click({ Add-Log $logI "Testing example endpoint…"; Start-Sleep .3; Add-Log $logI "OK" })

# Settings
$grid=New-Object System.Windows.Forms.TableLayoutPanel; $grid.Dock='Fill'; $grid.ColumnCount=2; $grid.RowCount=6; $grid.AutoSize=$true
$lblEnv=New-Object System.Windows.Forms.Label; $lblEnv.Text='Environment:'; $txtEnv=New-Object System.Windows.Forms.TextBox; $txtEnv.Text='prod'
$lblLogs=New-Object System.Windows.Forms.Label; $lblLogs.Text='Log Folder:'; $txtLogs=New-Object System.Windows.Forms.TextBox
$txtLogs.Text = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) '_logs')
$btnSave=New-Object System.Windows.Forms.Button; $btnSave.Text='Save Settings'; $btnSave.Width=140
$grid.Controls.Add($lblEnv,0,0); $grid.Controls.Add($txtEnv,1,0); $grid.Controls.Add($lblLogs,0,1); $grid.Controls.Add($txtLogs,1,1); $grid.Controls.Add($btnSave,1,5)
$tSet.Controls.Add($grid)
$btnSave.Add_Click({ [IO.Directory]::CreateDirectory($txtLogs.Text) | Out-Null; [System.Windows.Forms.MessageBox]::Show("Saved.","Operion") })

[void].ShowDialog()
