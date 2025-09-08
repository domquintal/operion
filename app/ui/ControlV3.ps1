# ==== Operion Control V3 ====
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
$Logs = Join-Path $Repo "_logs"; New-Item -ItemType Directory -Force -Path $Logs | Out-Null

# Policy + Theme + Audit
$PolicyF = Join-Path $Repo "app\policy.json"
$Policy  = if (Test-Path $PolicyF) { Get-Content -Raw -LiteralPath $PolicyF | ConvertFrom-Json } else { @{ allowedUsers=@(); requireConfirmForUpdatePush=$true; watchdog=@{enabled=$false;restartDelaySeconds=2}; notifications=@{enabled=$true} } }
$ThemeF  = Join-Path $Repo "app\theme.json"
$Theme   = if (Test-Path $ThemeF) { Get-Content -Raw -LiteralPath $ThemeF | ConvertFrom-Json } else { @{ mode="dark"; colors=@{ bg="#0F172A"; card="#111827"; fg="#E5E7EB"; accent="#60A5FA" } } }
$Audit   = Join-Path $Repo "ops\audit.ps1"

# Toasts
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
function Show-Note([string]$text){ try { if($Policy.notifications.enabled){ $notify.BalloonTipTitle = "Operion"; $notify.BalloonTipText = $text; $notify.ShowBalloonTip(2000) } } catch {} }

# Version + git meta for status bar (feature 10)
$VerF = Join-Path $Repo "app\version.json"
try { $V = Get-Content -Raw -LiteralPath $VerF | ConvertFrom-Json } catch { $V = @{version="0.0.0"; build="NA"} }
$Branch = (git rev-parse --abbrev-ref HEAD 2>$null); if([string]::IsNullOrWhiteSpace($Branch)){$Branch="main"}
$LastTag = (git describe --tags --abbrev=0 2>$null); if([string]::IsNullOrWhiteSpace($LastTag)){$LastTag="(no tag)"}

# Colors
$BG = $Theme.colors.bg; $FG = $Theme.colors.fg; $CARD = $Theme.colors.card

# UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Control V3" Width="1080" Height="720"
        WindowStartupLocation="CenterScreen" Background="$BG" Foreground="$FG" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.ColumnDefinitions><ColumnDefinition Width="260"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <!-- Sidebar -->
    <StackPanel Grid.Column="0" Margin="0,0,16,0">
      <Border Background="$CARD" CornerRadius="14" Padding="16" Margin="0,0,0,12">
        <StackPanel>
          <TextBlock Text="OPERION" FontSize="18" FontWeight="Bold"/>
          <TextBlock Text="Control Center" Opacity="0.85"/>
        </StackPanel>
      </Border>
      <Border Background="$CARD" CornerRadius="14" Padding="12" Margin="0,0,0,12">
        <StackPanel>
          <TextBlock Text="Quick Actions" FontWeight="Bold" Margin="0,0,0,8"/>
          <WrapPanel x:Name="BtnRow" ItemWidth="220" ItemHeight="34">
            <Button x:Name="BtnUpdate"   Content="Update → Push"/>
            <Button x:Name="BtnRelease"  Content="Make Release (ZIP)"/>
            <Button x:Name="BtnDash"     Content="Open Dashboard"/>
            <Button x:Name="BtnNotify"   Content="Notifications"/>
            <Button x:Name="BtnLogs"     Content="Logs Explorer"/>
            <Button x:Name="BtnPolicy"   Content="Edit Policy"/>
            <Button x:Name="BtnStartup"  Content="Toggle Startup"/>
            <Button x:Name="BtnTheme"    Content="Toggle Theme (Dark/Dim)"/>
            <Button x:Name="BtnSite"     Content="Open operion.tech"/>
            <Button x:Name="BtnGitHub"   Content="Open GitHub Repo"/>
          </WrapPanel>
        </StackPanel>
      </Border>
      <Border Background="$CARD" CornerRadius="14" Padding="12">
        <StackPanel>
          <TextBlock Text="Tasks Runner" FontWeight="Bold" Margin="0,0,0,8"/>
          <ListView x:Name="TaskList" Height="220">
            <ListView.View><GridView>
              <GridViewColumn Header="#" Width="30" DisplayMemberBinding="{Binding Id}"/>
              <GridViewColumn Header="Task" Width="160" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="Status" Width="100" DisplayMemberBinding="{Binding Status}"/>
              <GridViewColumn Header="Progress" Width="80" DisplayMemberBinding="{Binding Progress}"/>
            </GridView></ListView.View>
          </ListView>
          <ProgressBar x:Name="TaskBar" Height="8" Minimum="0" Maximum="100" Margin="0,6,0,0"/>
        </StackPanel>
      </Border>
    </StackPanel>

    <!-- Main area -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
      <TabControl x:Name="Tabs" Background="$CARD">
        <TabItem Header="Feed">
          <Border Background="$CARD" Padding="12"><ScrollViewer><TextBox x:Name="LogBox" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderThickness="0" Background="$CARD" FontFamily="Consolas" FontSize="13"/></ScrollViewer></Border>
        </TabItem>
        <TabItem Header="Logs Explorer">
          <Grid Margin="8">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,8">
              <TextBox x:Name="LogSearch" Width="240" Margin="0,0,8,0" ToolTip="search text"/>
              <CheckBox x:Name="ChkInfo" Content="INFO" IsChecked="True" Margin="0,0,8,0"/>
              <CheckBox x:Name="ChkErr"  Content="ERROR" IsChecked="True" Margin="0,0,8,0"/>
              <CheckBox x:Name="ChkBeat" Content="heartbeat" IsChecked="True"/>
              <Button x:Name="BtnRefreshLogs" Content="Refresh" Margin="8,0,0,0"/>
            </StackPanel>
            <ListBox x:Name="LogList" Grid.Row="1" FontFamily="Consolas" Background="$CARD"/>
          </Grid>
        </TabItem>
        <TabItem Header="Policy Editor">
          <Grid Margin="8">
            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <TextBox x:Name="PolicyBox" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" FontFamily="Consolas" Background="$CARD"/>
            <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
              <Button x:Name="BtnPolicySave" Content="Save Policy" Width="120"/>
            </StackPanel>
          </Grid>
        </TabItem>
        <TabItem Header="About">
          <StackPanel Margin="12"><TextBlock Text="Operion Control V3" FontSize="16" FontWeight="Bold"/><TextBlock Text="Refined WPF UI + tools."/></StackPanel>
        </TabItem>
      </TabControl>
      <StatusBar Grid.Row="1" Background="#0B1220">
        <StatusBarItem><TextBlock x:Name="VerTxt"/></StatusBarItem>
      </StatusBar>
    </Grid>
  </Grid>
</Window>
"@

$win=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))

# Find controls
$BtnUpdate =$win.FindName("BtnUpdate");  $BtnRelease=$win.FindName("BtnRelease")
$BtnDash   =$win.FindName("BtnDash");    $BtnNotify =$win.FindName("BtnNotify")
$BtnLogs   =$win.FindName("BtnLogs");    $BtnPolicy =$win.FindName("BtnPolicy")
$BtnStartup=$win.FindName("BtnStartup"); $BtnTheme  =$win.FindName("BtnTheme")
$BtnSite   =$win.FindName("BtnSite");    $BtnGitHub =$win.FindName("BtnGitHub")
$TaskList  =$win.FindName("TaskList");   $TaskBar   =$win.FindName("TaskBar")
$Tabs      =$win.FindName("Tabs");       $LogBox    =$win.FindName("LogBox")
$LogSearch =$win.FindName("LogSearch");  $ChkInfo   =$win.FindName("ChkInfo")
$ChkErr    =$win.FindName("ChkErr");     $ChkBeat   =$win.FindName("ChkBeat")
$BtnRefreshLogs=$win.FindName("BtnRefreshLogs"); $LogList=$win.FindName("LogList")
$PolicyBox =$win.FindName("PolicyBox");  $BtnPolicySave=$win.FindName("BtnPolicySave")
$VerTxt    =$win.FindName("VerTxt")

# Helpers
function Append([string]$t){ $LogBox.AppendText($t+"`r`n"); $LogBox.ScrollToEnd() }
function Use-Shell(){ if(Get-Command pwsh -EA SilentlyContinue){ 'pwsh' } else { 'powershell' } }
function Audit([string]$a,[string]$d=""){ & $Audit -Action $a -Detail $d }

# Status bar
$VerTxt.Text = "v$($V.version) · build $($V.build) · $Branch · $LastTag"

# RBAC
$CurrentUser=$env:USERNAME
$Allowed = (@($Policy.allowedUsers)).Count -eq 0 -or @($Policy.allowedUsers) -contains $CurrentUser
try { if(-not $Allowed -and $BtnUpdate){ $BtnUpdate.IsEnabled = $false } } catch {}
try { if(-not $Allowed -and $BtnRelease){ $BtnRelease.IsEnabled = $false } } catch {}

# Keyboard shortcuts (feature 6)
$win.Add_KeyDown({
  if([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl)){
    switch ($_.Key){
      'D' { $BtnDash.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
      'N' { $BtnNotify.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
      'U' { $BtnUpdate.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
      'L' { $BtnLogs.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
    }
  }
})

# Tasks Runner (feature 2) - simple queue simulation + progress
$global:TaskId=0
$global:Tasks=@()
function Enqueue-Task([string]$name,[scriptblock]$work){
  $global:TaskId++; $t=[pscustomobject]@{Id=$global:TaskId;Name=$name;Status="Queued";Progress=0;Work=$work}
  $global:Tasks += $t; $TaskList.ItemsSource = $null; $TaskList.ItemsSource = $global:Tasks
}
$timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromMilliseconds(180)
$timer.Add_Tick({
  $running = $global:Tasks | Where-Object { $_.Status -eq "Running" } | Select-Object -First 1
  if(-not $running){
    $next = $global:Tasks | Where-Object { $_.Status -eq "Queued" } | Select-Object -First 1
    if($next){
      $next.Status="Running"; $next.Progress=0; $TaskList.Items.Refresh()
      try { & $next.Work.Invoke() } catch { Append ("Task error: " + $_.Exception.Message); Audit "task_error" $_.Exception.Message }
    }
  } else {
    if($running.Progress -lt 100){ $running.Progress += 10; $TaskBar.Value = $running.Progress; $TaskList.Items.Refresh() }
    if($running.Progress -ge 100){ $running.Status="Done"; $TaskBar.Value=0; $TaskList.Items.Refresh(); Audit "task_done" $running.Name }
  }
})
$timer.Start()

# Buttons wiring
$BtnDash.Add_Click({ Start-Process (Use-Shell) -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", (Join-Path $UI "Dashboard.ps1")); Audit "open_dashboard"; Append "Dashboard opened." })
$BtnNotify.Add_Click({ Start-Process (Use-Shell) -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", (Join-Path $UI "Notify.ps1")); Audit "open_notify"; Append "Notifications opened." })
$BtnLogs.Add_Click({ $Tabs.SelectedIndex=1 })
$BtnPolicy.Add_Click({
  try { $PolicyBox.Text = Get-Content -Raw -LiteralPath $PolicyF } catch { $PolicyBox.Text = "{`"error`":`"$($_.Exception.Message)`"}" }
  $Tabs.SelectedIndex=2
})

# Update→Push with confirm (feature 1 carry)
$BtnUpdate.Add_Click({
  if($Policy.requireConfirmForUpdatePush -and
     [System.Windows.MessageBox]::Show("Run Update → Push now?","Confirm","YesNo","Question") -ne "Yes"){ Append "Update canceled."; return }
  Show-Note("Update→Push started…"); Audit "update_push_start"
  Enqueue-Task "Update+Push" { param() Start-Sleep -Milliseconds 250; git add -A; git commit -m "ops: UI Update push (V3 workflow)" 2>$null | Out-Null; git push | Out-Null; Append "Pushed."; }
})

# Release Builder (feature 8)
$BtnRelease.Add_Click({
  Enqueue-Task "Version bump"  { & (Join-Path $Ops "version.bump.ps1") patch | Out-Null; Append "Version bumped." }
  Enqueue-Task "Make release"  { & (Join-Path $Ops "release.make.ps1") | Out-Null; Append "Release ZIP created."; }
})

# Startup Toggle (feature 7)
$BtnStartup.Add_Click({
  try{
    $state = [System.Windows.MessageBox]::Show("Enable startup (launch ControlV3 at logon)?","Startup","YesNo","Question")
    if($state -eq "Yes"){ & (Join-Path $Ops "startup.toggle.ps1") enable | Out-Null; Show-Note("Startup ENABLED"); Audit "startup" "enable" }
    else { & (Join-Path $Ops "startup.toggle.ps1") disable | Out-Null; Show-Note("Startup DISABLED"); Audit "startup" "disable" }
  } catch { Append ("Startup toggle error: " + $_.Exception.Message) }
})

# Theme Toggle (feature 5)
$BtnTheme.Add_Click({
  try{
    $theme = Get-Content -Raw -LiteralPath $ThemeF | ConvertFrom-Json
    if($theme.mode -eq "dark"){ $theme.mode="dim"; $theme.colors.bg="#0B1220"; $theme.colors.card="#0E1628" } else { $theme.mode="dark"; $theme.colors.bg="#0F172A"; $theme.colors.card="#111827" }
    $theme | ConvertTo-Json | Out-File -Encoding UTF8 -LiteralPath $ThemeF
    [System.Windows.MessageBox]::Show("Theme saved. Close & reopen to apply.","Theme","OK","Information") | Out-Null
    Audit "theme_toggle" $theme.mode
  } catch { Append ("Theme error: " + $_.Exception.Message) }
})

# Quick Links (feature 9)
$BtnSite.Add_Click({ Start-Process "https://www.operion.tech"; Audit "open_site" })
$BtnGitHub.Add_Click({ Start-Process "https://github.com/domquintal/operion"; Audit "open_github" })

# Logs Explorer (feature 3)
function Load-Logs{
  if(-not (Test-Path $Logs)){ $LogList.ItemsSource=@("No logs.") ; return }
  $lf = Get-ChildItem $Logs -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if(-not $lf){ $LogList.ItemsSource=@("No logs.") ; return }
  $lines = Get-Content -LiteralPath $lf.FullName -Tail 1000
  $q = $LogSearch.Text
  if($q){ $lines = $lines | Where-Object { $_ -match [regex]::Escape($q) } }
  if(-not $ChkInfo.IsChecked){ $lines = $lines | Where-Object { $_ -notmatch 'INFO' } }
  if(-not $ChkErr.IsChecked){  $lines = $lines | Where-Object { $_ -notmatch 'ERROR|CRASH|FAIL' } }
  if(-not $ChkBeat.IsChecked){ $lines = $lines | Where-Object { $_ -notmatch 'heartbeat' } }
  $LogList.ItemsSource = $lines
}
$BtnRefreshLogs.Add_Click({ Load-Logs })
$LogSearch.Add_TextChanged({ Load-Logs })

# Policy Editor (feature 4)
try { $PolicyBox.Text = Get-Content -Raw -LiteralPath $PolicyF } catch {}
$BtnPolicySave.Add_Click({
  try{
    $json = $PolicyBox.Text | ConvertFrom-Json
    $PolicyBox.Text | Out-File -Encoding UTF8 -LiteralPath $PolicyF
    $global:Policy = Get-Content -Raw -LiteralPath $PolicyF | ConvertFrom-Json
    [System.Windows.MessageBox]::Show("Saved.","Policy", "OK","Information") | Out-Null
    & (Join-Path $Ops "audit.ps1") -Action "policy_saved"
  } catch {
    [System.Windows.MessageBox]::Show("Invalid JSON: $($_.Exception.Message)","Error","OK","Error") | Out-Null
  }
})

# Boot
Append ("Welcome, " + $env:USERNAME)
$Tabs.SelectedIndex=0
$win.ShowDialog() | Out-Null
# ==== END Control V3 ====
