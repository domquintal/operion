# app/ui/Control.ps1  (fixed layout: Grid header)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# Paths
$Repo = (Resolve-Path "..").Path
$Ops  = Join-Path $Repo "ops"
$Logs = Join-Path $Repo "_logs"
$VerF = Join-Path $Repo "VERSION.txt"
$Run  = Join-Path $Repo "app\run.ps1"
$SanV = Join-Path $Ops  "sanity.view.ps1"
$Upd  = Join-Path $Ops  "update.ps1"
$Pkg  = Join-Path $Ops  "package.ps1"
$Version = (Test-Path $VerF) ? ((Get-Content -Raw -LiteralPath $VerF).Trim()) : "0.0.0"

# XAML (header uses Grid with 2 columns; status right-aligned)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Control" Width="680" Height="420"
        WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Grid Grid.Row="0" Margin="0,0,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock Grid.Column="0" Text="Operion Control" FontSize="20" FontWeight="Bold" />
      <StackPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right">
        <Ellipse x:Name="StatusDot" Width="12" Height="12" Margin="0,0,8,0"/>
        <TextBlock x:Name="StatusTxt" Text="stopped" VerticalAlignment="Center"/>
      </StackPanel>
    </Grid>

    <!-- Buttons -->
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8">
      <Button x:Name="BtnStart"  Content="Start App" Width="110" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnStop"   Content="Stop App"  Width="110" Height="34" Margin="0,0,16,0" IsEnabled="False"/>
      <Button x:Name="BtnSanity" Content="Sanity (✓/✗)" Width="120" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnUpdate" Content="Update → Push" Width="140" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnLogs"   Content="Open Logs" Width="110" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnZip"    Content="Make Release ZIP" Width="150" Height="34"/>
    </StackPanel>

    <!-- Body -->
    <Grid Grid.Row="2">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,6">
        <TextBlock Text="CPU: " />
        <TextBlock x:Name="CpuTxt" Text="--%" FontWeight="Bold" Margin="4,0,12,0"/>
        <TextBlock Text="RAM: " />
        <TextBlock x:Name="RamTxt" Text="--%" FontWeight="Bold" Margin="4,0,12,0"/>
      </StackPanel>

      <ProgressBar x:Name="Bar" Grid.Row="1" Height="10" IsIndeterminate="False" Minimum="0" Maximum="100" Value="0"/>

      <ScrollViewer Grid.Row="2" Margin="0,8,0,0" Background="#0B1220">
        <TextBlock x:Name="Out" FontFamily="Consolas" TextWrapping="Wrap" Margin="8"/>
      </ScrollViewer>
    </Grid>

    <!-- Footer -->
    <DockPanel Grid.Row="3" LastChildFill="False" Margin="0,10,0,0">
      <TextBlock Text="Version: " VerticalAlignment="Center"/>
      <TextBlock x:Name="VerTxt" Text="0.0.0" FontWeight="Bold" Margin="4,0,0,0" VerticalAlignment="Center"/>
      <DockPanel DockPanel.Dock="Right" LastChildFill="False">
        <Button x:Name="BtnClose" Content="Close" Width="90" Height="30"/>
      </DockPanel>
    </DockPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$win    = [Windows.Markup.XamlReader]::Load($reader)

# Bind
$BtnStart = $win.FindName("BtnStart")
$BtnStop  = $win.FindName("BtnStop")
$BtnSanity= $win.FindName("BtnSanity")
$BtnUpdate= $win.FindName("BtnUpdate")
$BtnLogs  = $win.FindName("BtnLogs")
$BtnZip   = $win.FindName("BtnZip")
$BtnClose = $win.FindName("BtnClose")
$Bar      = $win.FindName("Bar")
$Out      = $win.FindName("Out")
$VerTxt   = $win.FindName("VerTxt")
$CpuTxt   = $win.FindName("CpuTxt")
$RamTxt   = $win.FindName("RamTxt")
$StatusTxt= $win.FindName("StatusTxt")
$StatusDot= $win.FindName("StatusDot")
$VerTxt.Text = $Version
$BtnClose.Add_Click({ $win.Close() })

function Use-Shell {
  $pw = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($pw) { return $pw.Path } else { return (Get-Command powershell -ErrorAction Stop).Path }
}
function Append([string]$t){ $Out.Text += ($t + [Environment]::NewLine) }
function Set-Status($running){
  $StatusTxt.Text = $(if($running){"running"}else{"stopped"})
  $brush = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb($(if($running){34}else{239}),$(if($running){197}else{68}),$(if($running){94}else{68})))
  $StatusDot.Fill = $brush
  $BtnStart.IsEnabled = -not $running
  $BtnStop.IsEnabled  = $running
}

# App process tracking
$global:AppProc = $null

# Start
$BtnStart.Add_Click({
  try {
    $Run = Join-Path $Repo "app\run.ps1"
    if (-not (Test-Path $Run)) { Append "Missing app\run.ps1"; return }
    Append "Starting app (app\run.ps1)..."; $Bar.IsIndeterminate = $true
    $sh = Use-Shell
    $global:AppProc = Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Run) -PassThru
    Start-Sleep -Milliseconds 600; Set-Status $true
    Append "Started. PID: $($global:AppProc.Id)"
  } catch { Append "Start error: $($_.Exception.Message)" }
  finally { $Bar.IsIndeterminate = $false; $Bar.Value = 100 }
})

# Stop
$BtnStop.Add_Click({
  try {
    if ($global:AppProc -and -not $global:AppProc.HasExited) {
      Append "Stopping PID $($global:AppProc.Id)..."
      Stop-Process -Id $global:AppProc.Id -Force -ErrorAction SilentlyContinue
      Start-Sleep -Milliseconds 300
    }
    Set-Status $false; Append "Stopped."
  } catch { Append "Stop error: $($_.Exception.Message)" }
})

# Sanity (visual)
$BtnSanity.Add_Click({
  try {
    Append "Launching sanity.view.ps1..."
    $sh = Use-Shell
    $SanV = Join-Path $Ops  "sanity.view.ps1"
    Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $SanV) | Out-Null
  } catch { Append "Sanity error: $($_.Exception.Message)" }
})

# Update
$BtnUpdate.Add_Click({
  try {
    $Bar.IsIndeterminate = $true; $Out.Text = ""; Append "Running update (git pull → sanity → commit/push on PASS)..."
    $sh = Use-Shell
    $Upd = Join-Path $Ops  "update.ps1"
    $so = [IO.Path]::GetTempFileName(); $se = [IO.Path]::GetTempFileName()
    $p = Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $Upd) `
         -PassThru -WindowStyle Hidden -RedirectStandardOutput $so -RedirectStandardError $se
    $timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
      if ($p.HasExited) {
        $timer.Stop(); $Bar.IsIndeterminate = $false; $Bar.Value = 100
        $txt = (Get-Content -Raw -LiteralPath $so) + "`r`n" + (Get-Content -Raw -LiteralPath $se)
        $Out.Text = $txt
      }
    })
    $timer.Start()
  } catch { $Bar.IsIndeterminate = $false; Append "Update error: $($_.Exception.Message)" }
})

# Health timer (CPU %, RAM %)
$timerH = New-Object Windows.Threading.DispatcherTimer
$timerH.Interval = [TimeSpan]::FromSeconds(2)
$timerH.Add_Tick({
  try {
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    $os  = Get-CimInstance -ClassName Win32_OperatingSystem
    $ram = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
    $CpuTxt.Text = ("{0:N0}%%" -f $cpu)
    $RamTxt.Text = ("{0:N1}%%" -f $ram)
  } catch { $CpuTxt.Text = "--%"; $RamTxt.Text = "--%" }
})
$timerH.Start()

# Init
Set-Status $false
$BtnLogs.Add_Click({ Start-Process explorer.exe $Logs })
$BtnClose.Add_Click({ $timerH.Stop(); $win.Close() })
$win.ShowDialog() | Out-Null
