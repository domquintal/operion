# ==== Operion Control V2 ====
param()
$ErrorActionPreference="Stop"
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
$App  = Join-Path $Repo "app"
$UI   = Join-Path $App "ui"
$Ops  = Join-Path $Repo "ops"
$Logs = Join-Path $Repo "_logs"
New-Item -ItemType Directory -Force -Path $Logs | Out-Null

# Policy + Audit
$PolicyF = Join-Path $Repo "app\policy.json"
$Policy  = if (Test-Path $PolicyF) { Get-Content -Raw -LiteralPath $PolicyF | ConvertFrom-Json } else { @{ allowedUsers=@(); requireConfirmForUpdatePush=$true; watchdog=@{enabled=$false;restartDelaySeconds=2}; notifications=@{enabled=$true} } }
$Audit   = Join-Path $Repo "ops\audit.ps1"

# Toasts
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
function Show-Note([string]$text){ try { if($Policy.notifications.enabled){ $notify.BalloonTipTitle = "Operion"; $notify.BalloonTipText = $text; $notify.ShowBalloonTip(2000) } } catch {} }

# UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Control" Width="980" Height="640"
        WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="260"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <!-- Sidebar -->
    <StackPanel Grid.Column="0" Margin="0,0,16,0">
      <Border Background="#111827" CornerRadius="14" Padding="16" Margin="0,0,0,12">
        <StackPanel>
          <TextBlock Text="OPERION" FontSize="18" FontWeight="Bold"/>
          <TextBlock Text="Control Center" Opacity="0.8"/>
        </StackPanel>
      </Border>
      <Border Background="#111827" CornerRadius="14" Padding="12" Margin="0,0,0,12">
        <StackPanel>
          <TextBlock Text="Actions" FontWeight="Bold" Margin="0,0,0,8"/>
          <WrapPanel x:Name="BtnRow" ItemWidth="200" ItemHeight="34">
            <Button x:Name="BtnStart"   Content="Start App"    Margin="0,0,0,8"/>
            <Button x:Name="BtnStop"    Content="Stop App"     Margin="0,0,0,8"/>
            <Button x:Name="BtnUpdate"  Content="Update → Push" Margin="0,0,0,8"/>
            <Button x:Name="BtnZip"     Content="Make ZIP"     Margin="0,0,0,8"/>
            <Button x:Name="BtnDash"    Content="Open Dashboard" Margin="0,0,0,8"/>
            <Button x:Name="BtnPolicy"  Content="Edit Policy"  Margin="0,0,0,8"/>
          <Button x:Name="BtnNotify" Content="Notifications" Margin="0,0,0,8"/></WrapPanel>
        </StackPanel>
      </Border>
      <Border Background="#111827" CornerRadius="14" Padding="12">
        <StackPanel>
          <TextBlock Text="Watchdog" FontWeight="Bold" Margin="0,0,0,8"/>
          <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
            <Button x:Name="BtnWDOn"  Content="Enable" Width="90" Margin="0,0,8,0"/>
            <Button x:Name="BtnWDOff" Content="Disable" Width="90"/>
          </StackPanel>
        </StackPanel>
      </Border>
    </StackPanel>

    <!-- Main -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <Border Background="#111827" CornerRadius="14" Padding="14" Margin="0,0,0,12">
        <TextBlock Text="Operational Feed" FontWeight="Bold" FontSize="16"/>
      </Border>
      <Border Background="#111827" CornerRadius="14" Padding="0">
        <ScrollViewer>
          <TextBox x:Name="LogBox" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="#111827" FontFamily="Consolas" FontSize="13"/>
        </ScrollViewer>
      </Border>
    </Grid>
    <StatusBar VerticalAlignment="Bottom" Background="#0B1220"><StatusBarItem><TextBlock x:Name="VerTxt"/></StatusBarItem></StatusBar></Grid></Window>
"@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$BtnStart    = $win.FindName("BtnStart")
$BtnStop     = $win.FindName("BtnStop")
$BtnUpdate   = $win.FindName("BtnUpdate")
$BtnZip      = $win.FindName("BtnZip")
$BtnDash     = $win.FindName("BtnDash")
$BtnPolicy   = $win.FindName("BtnPolicy")
$BtnWDOn     = $win.FindName("BtnWDOn")
$BtnWDOff    = $win.FindName("BtnWDOff")
$LogBox      = $win.FindName("LogBox")
$BtnNotify = $win.FindName("BtnNotify"); $VerTxt = $win.FindName("VerTxt")
$VersionF = Join-Path $Repo "app\version.json"
try{ $V = Get-Content -Raw -LiteralPath $VersionF | ConvertFrom-Json; $VerTxt.Text = ("v{0} · build {1}" -f $V.version,$V.build) } catch { $VerTxt.Text = "v0.0.0" }

function Append([string]$t){ $LogBox.AppendText($t+"`r`n"); $LogBox.ScrollToEnd() }
function Use-Shell(){ if(Get-Command pwsh -EA SilentlyContinue){ 'pwsh' } else { 'powershell' } }

# RBAC
$CurrentUser = $env:USERNAME
$Allowed = (@($Policy.allowedUsers)).Count -eq 0 -or @($Policy.allowedUsers) -contains $CurrentUser
try { if(-not $Allowed -and $BtnUpdate){ $BtnUpdate.IsEnabled = $false } } catch {}
try { if(-not $Allowed -and $BtnZip){    $BtnZip.IsEnabled    = $false } } catch {}

# Buttons wiring
function Audit([string]$a,[string]$d=""){ & $Audit -Action $a -Detail $d }
$BtnStart.Add_Click({ Append "Starting app..."; Audit "app_start"; Show-Note("Starting app…") })
$BtnStop.Add_Click({  Append "Stopped.";       Audit "app_stop";  Show-Note("App stopped.") })
$BtnZip.Add_Click({   Append "Creating release zip..."; Audit "make_zip"; Show-Note("Creating release ZIP…") })
$BtnDash.Add_Click({  Start-Process (Use-Shell) -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", (Join-Path $Repo "app\ui\Dashboard.ps1")); Audit "open_dashboard" })

# Update→Push: confirm + audit + toast
$BtnUpdate.Add_Click({
  if($Policy.requireConfirmForUpdatePush -and
     [System.Windows.MessageBox]::Show("Run Update → Push now?","Confirm","YesNo","Question") -ne "Yes"){ Append "Update canceled."; return }
  Append "Running update..."; Audit "update_push_start"; Show-Note("Update→Push started…")
  # TODO: your update/push routine; placeholder:
  Start-Sleep -Milliseconds 600
  Append "Update complete."
})

# Policy Editor (new feature)
$BtnPolicy.Add_Click({
  try{
    $raw = Get-Content -Raw -LiteralPath $PolicyF
    $dlg = New-Object System.Windows.Window
    $dlg.Title="Edit policy.json"; $dlg.Width=720; $dlg.Height=520; $dlg.WindowStartupLocation="CenterOwner"; $dlg.Background="#0F172A"; $dlg.Foreground="#E5E7EB"; $dlg.FontFamily="Segoe UI"
    $grid = New-Object System.Windows.Controls.Grid
    $row1 = New-Object System.Windows.Controls.RowDefinition; $row1.Height="*"
    $row2 = New-Object System.Windows.Controls.RowDefinition; $row2.Height="Auto"
    $grid.RowDefinitions.Add($row1); $grid.RowDefinitions.Add($row2)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.AcceptsReturn = $true; $tb.TextWrapping="Wrap"; $tb.VerticalScrollBarVisibility="Auto"
    $tb.FontFamily="Consolas"; $tb.Background="#111827"; $tb.BorderThickness=0; $tb.Text=$raw
    [System.Windows.Controls.Grid]::SetRow($tb,0); $grid.Children.Add($tb) | Out-Null
    $panel = New-Object System.Windows.Controls.DockPanel
    $btnSave = New-Object System.Windows.Controls.Button; $btnSave.Content="Save"; $btnSave.Width=100; $btnSave.Height=30; $btnSave.Margin="0,8,0,0"; $btnSave.HorizontalAlignment="Right"
    $panel.Children.Add($btnSave) | Out-Null
    [System.Windows.Controls.Grid]::SetRow($panel,1); $grid.Children.Add($panel) | Out-Null
    $dlg.Content=$grid; $btnSave.Add_Click({
      try{
        $json = $tb.Text | ConvertFrom-Json
        $tb.Text | Out-File -Encoding UTF8 -LiteralPath $PolicyF
        $global:Policy = Get-Content -Raw -LiteralPath $PolicyF | ConvertFrom-Json
        [System.Windows.MessageBox]::Show("Saved.","Policy", "OK","Information") | Out-Null
        & (Join-Path $Ops "audit.ps1") -Action "policy_saved"
        $dlg.Close()
      } catch {
        [System.Windows.MessageBox]::Show("Invalid JSON: $($_.Exception.Message)","Error","OK","Error") | Out-Null
      }
    })
    $dlg.Owner = $win; $dlg.ShowDialog() | Out-Null
  } catch {
    Append ("Policy open error: " + $_.Exception.Message)
  }
})

# Watchdog toggles
# Notifications Center
$BtnNotify.Add_Click({ Start-Process (Use-Shell) -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", (Join-Path $Repo "app\ui\Notify.ps1")) })
$BtnWDOn.Add_Click({  & (Join-Path $Ops "watchdog.toggle.ps1") -Enable;  Show-Note("Watchdog ENABLED");  Audit "watchdog_toggle" "on" })
$BtnWDOff.Add_Click({ & (Join-Path $Ops "watchdog.toggle.ps1");         Show-Note("Watchdog DISABLED"); Audit "watchdog_toggle" "off" })

# Boot
Append ("Welcome, " + $env:USERNAME)
$win.ShowDialog() | Out-Null
# ==== END Control V2 ====

