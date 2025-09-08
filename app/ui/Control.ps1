$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# Resolve paths RELATIVE TO THIS SCRIPT (two levels up = repo root)
$ThisPath  = $MyInvocation.MyCommand.Path
$ScriptDir = if ($ThisPath) { Split-Path -Parent $ThisPath } else { $PSScriptRoot }
$Repo      = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path

# Paths

# Policy + Audit
$PolicyF = Join-Path $Repo "app\policy.json"
$Policy  = if (Test-Path $PolicyF) { Get-Content -Raw -LiteralPath $PolicyF | ConvertFrom-Json } else { @{ allowedUsers=@(); requireConfirmForUpdatePush=$true; watchdog=@{enabled=$false;restartDelaySeconds=2}; notifications=@{enabled=$true} } }
$Audit   = Join-Path $Repo "ops\audit.ps1"
$Ops   = Join-Path $Repo "ops"
$Logs  = Join-Path $Repo "_logs"
$VerF  = Join-Path $Repo "VERSION.txt"
$Run   = Join-Path $Repo "app\run.ps1"
$SanV  = Join-Path $Ops  "sanity.view.ps1"
$Upd   = Join-Path $Ops  "update.ps1"
$Pkg   = Join-Path $Ops  "package.ps1"
$Tail  = Join-Path $Ops  "tail-log.ps1"
$SetF  = Join-Path $Repo "app\settings.json"

# PS5.1-safe version read
if (Test-Path $VerF) { $Version = (Get-Content -Raw -LiteralPath $VerF).Trim() } else { $Version = "0.0.0" }

# XAML
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Control" Width="760" Height="480"
        WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,8">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" Text="Operion Control" FontSize="20" FontWeight="Bold"/>
      <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
        <Ellipse x:Name="StatusDot" Width="12" Height="12" Margin="0,0,8,0"/>
        <TextBlock x:Name="StatusTxt" Text="stopped" VerticalAlignment="Center"/>
      </StackPanel>
    </Grid>

    <WrapPanel Grid.Row="1" Margin="0,0,0,8">
      <Button x:Name="BtnDash" Content="Open Dashboard" Width="160" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnStart"  Content="Start App" Width="120" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnStop"   Content="Stop App"  Width="120" Height="34" Margin="0,0,16,8" IsEnabled="False"/>
      <Button x:Name="BtnSanity" Content="Sanity (✓/✗)" Width="130" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnUpdate" Content="Update → Push" Width="140" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnLogs"   Content="Open Logs" Width="120" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnTail"   Content="Tail Latest Log" Width="140" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnZip"    Content="Make Release ZIP" Width="160" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnRepo"   Content="Open Repo Folder" Width="150" Height="34" Margin="0,0,8,8"/>
      <Button x:Name="BtnSettings" Content="Open Settings" Width="140" Height="34" Margin="0,0,8,8"/>
    </WrapPanel>

    <Grid Grid.Row="2">
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
        <TextBlock Text="CPU: " /><TextBlock x:Name="CpuTxt" Text="--%" FontWeight="Bold" Margin="4,0,12,0"/>
        <TextBlock Text="RAM: " /><TextBlock x:Name="RamTxt" Text="--%" FontWeight="Bold" Margin="4,0,12,0"/>
        <TextBlock Text="Version: " /><TextBlock x:Name="VerTxt" Text="0.0.0" FontWeight="Bold" Margin="4,0,0,0"/>
      </StackPanel>
      <ProgressBar x:Name="Bar" Grid.Row="1" Height="10" IsIndeterminate="False" Minimum="0" Maximum="100" Value="0"/>
      <ScrollViewer Grid.Row="2" Margin="0,8,0,0" Background="#0B1220"><TextBlock x:Name="Out" FontFamily="Consolas" TextWrapping="Wrap" Margin="8"/></ScrollViewer>
    </Grid>

    <DockPanel Grid.Row="3" LastChildFill="False" Margin="0,10,0,0">
      <Button x:Name="BtnClose" Content="Close" Width="90" Height="30" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$win    = [Windows.Markup.XamlReader]::Load($reader)

# Bind
$BtnStart=$win.FindName("BtnStart");$BtnStop=$win.FindName("BtnStop")
$BtnSanity=$win.FindName("BtnSanity");$BtnUpdate=$win.FindName("BtnUpdate")
# RBAC
$CurrentUser = $env:USERNAME
$Allowed = (@($Policy.allowedUsers)).Count -eq 0 -or @($Policy.allowedUsers) -contains $CurrentUser
if(-not $Allowed){ $BtnUpdate.IsEnabled = $false; $BtnZip.IsEnabled=$false }

$BtnLogs=$win.FindName("BtnLogs");$BtnTail=$win.FindName("BtnTail")
$BtnZip=$win.FindName("BtnZip");$BtnRepo=$win.FindName("BtnRepo");$BtnSettings=$win.FindName("BtnSettings")
$BtnClose=$win.FindName("BtnClose");$Bar=$win.FindName("Bar");$Out=$win.FindName("Out")
$CpuTxt=$win.FindName("CpuTxt");$RamTxt=$win.FindName("RamTxt")
$VerTxt=$win.FindName("VerTxt");$VerTxt.Text = $Version
$StatusTxt=$win.FindName("StatusTxt");$StatusDot=$win.FindName("StatusDot")
$BtnClose.Add_Click({ $win.Close() })

function Use-Shell { $pw=Get-Command pwsh -ErrorAction SilentlyContinue; if ($pw) { $pw.Path } else { (Get-Command powershell -EA Stop).Path } }
function Append([string]$t){ $Out.Text += ($t + [Environment]::NewLine) }
function Set-Status($running){
  $StatusTxt.Text = $(if($running){"running"}else{"stopped"})
  $brush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb($(if($running){34}else{239}),$(if($running){197}else{68}),$(if($running){94}else{68})))
  $StatusDot.Fill = $brush
  $BtnStart.IsEnabled = -not $running; $BtnStop.IsEnabled = $running
}

# App process
$global:AppProc=$null
$BtnStart.Add_Click({
  try{
    if (-not (Test-Path $Run)) { Append "Missing $Run"; return }
    Append "Starting app..."; Audit "app_start"; Show-Note("Starting app…") $Bar.IsIndeterminate=$true
    $sh=Use-Shell
    $global:AppProc = Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Run) -PassThru
    Start-Sleep -Milliseconds 400; Set-Status $true; Append ("Started. PID: {0}" -f $global:AppProc.Id)
  } catch { Append "Start error: $($_.Exception.Message)" } finally { $Bar.IsIndeterminate=$false; $Bar.Value=100 }
})
$BtnStop.Add_Click({
  try{
    if ($global:AppProc -and -not $global:AppProc.HasExited) {
      Append ("Stopping PID {0}..." -f $global:AppProc.Id)
      Stop-Process -Id $global:AppProc.Id -Force -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 300
    }
    Set-Status $false; Append "Stopped."; Audit "app_stop"; Show-Note("App stopped.")
  } catch { Append "Stop error: $($_.Exception.Message)" }
})

# Buttons wiring (guard missing scripts)
function Audit([string]$a,[string]$d=""){ & $Audit -Action $a -Detail $d }
$BtnDash.Add_Click({ Start-Process (Use-Shell) -ArgumentList @("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File", (Join-Path $Repo "app\ui\Dashboard.ps1")); Audit "open_dashboard" })

$BtnSanity.Add_Click({ if(Test-Path $SanV){ Start-Process (Use-Shell) -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $SanV) | Out-Null } else { Append "sanity.view.ps1 not found ($SanV)." } })
$BtnUpdate.Add_Click({
if($Policy.requireConfirmForUpdatePush -and
   [System.Windows.MessageBox]::Show("Run Update → Push now?","Confirm","YesNo","Question") -ne "Yes"){ Append "Update canceled."; return }if(Test-Path $Upd){
    $Bar.IsIndeterminate=$true; $Out.Text=""; Append "Running update..."; Audit "update_push_start"; Show-Note("Update→Push started…"); Audit "update_push_start"; Show-Note("Update→Push started…")
    $so=[IO.Path]::GetTempFileName(); $se=[IO.Path]::GetTempFileName()
    $p=Start-Process (Use-Shell) -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Upd) -PassThru -WindowStyle Hidden -RedirectStandardOutput $so -RedirectStandardError $se
    $timer=New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({ if($p.HasExited){ $timer.Stop(); $Bar.IsIndeterminate=$false; $Bar.Value=100; $Out.Text=(Get-Content -Raw -LiteralPath $so)+"`r`n"+(Get-Content -Raw -LiteralPath $se) }
})
    $timer.Start()
  } else { Append "update.ps1 not found ($Upd)." }
})
$BtnZip.Add_Click({
  if(Test-Path $Pkg){
    $Bar.IsIndeterminate=$true; $Out.Text=""; Append "Creating release zip..."; Audit "make_zip"; Show-Note("Creating release ZIP…")
    $so=[IO.Path]::GetTempFileName(); $se=[IO.Path]::GetTempFileName()
    $p=Start-Process (Use-Shell) -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Pkg) -PassThru -WindowStyle Hidden -RedirectStandardOutput $so -RedirectStandardError $se
    $timer=New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({ if($p.HasExited){ $timer.Stop(); $Bar.IsIndeterminate=$false; $Bar.Value=100; $Out.Text=(Get-Content -Raw -LiteralPath $so)+"`r`n"+(Get-Content -Raw -LiteralPath $se) } })
    $timer.Start()
  } else { Append "package.ps1 not found ($Pkg)." }
})
$BtnLogs.Add_Click({ if(-not (Test-Path $Logs)){ New-Item -ItemType Directory -Force -Path $Logs | Out-Null }; Start-Process explorer.exe $Logs })
$BtnTail.Add_Click({ if(Test-Path $Tail){ Start-Process (Use-Shell) -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Tail) } else { Append "tail-log.ps1 not found ($Tail)." } })
$BtnRepo.Add_Click({ Start-Process explorer.exe $Repo })
$BtnSettings.Add_Click({ if (Test-Path $SetF) { notepad $SetF } else { Append "settings.json not found ($SetF)." } })

# Health (CPU/RAM)
$timerH = New-Object Windows.Threading.DispatcherTimer; $timerH.Interval=[TimeSpan]::FromSeconds(2)
$timerH.Add_Tick({
  try{
    $cpu=(Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $os = Get-CimInstance -Class Win32_OperatingSystem
    $ram=[math]::Round((($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/$os.TotalVisibleMemorySize)*100,1)
    $CpuTxt.Text=("{0:N0}%%" -f $cpu); $RamTxt.Text=("{0:N1}%%" -f $ram)
  } catch { $CpuTxt.Text="--%"; $RamTxt.Text="--%" }
})
$timerH.Start()
Set-Status $false
$BtnClose.Add_Click({ $timerH.Stop(); $win.Close() })
$win.ShowDialog() | Out-Null


