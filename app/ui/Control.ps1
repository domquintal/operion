# app/ui/Control.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# Paths
$Repo = (Resolve-Path "..").Path
$Ops  = Join-Path $Repo "ops"
$Logs = Join-Path $Repo "_logs"
$VerF = Join-Path $Repo "VERSION.txt"
$SanV = Join-Path $Ops  "sanity.view.ps1"
$Upd  = Join-Path $Ops  "update.ps1"
if (Test-Path $VerF) { $Version = (Get-Content -Raw -LiteralPath $VerF).Trim() } else { $Version = "0.0.0" }

# XAML (note xmlns:x is included)
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Control" Width="520" Height="360"
        WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <TextBlock Grid.Row="0" Text="Operion Control" FontSize="20" FontWeight="Bold" Margin="0,0,0,8"/>

    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,8" HorizontalAlignment="Left" >
      <Button x:Name="BtnSanity" Content="Run Sanity (✓/✗)" Width="150" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnUpdate" Content="Update (pull → sanity → push)" Width="230" Height="34" Margin="0,0,8,0"/>
      <Button x:Name="BtnLogs"   Content="Open Logs" Width="100" Height="34"/>
    </StackPanel>

    <StackPanel Grid.Row="2">
      <TextBlock Text="Progress / Output" Margin="0,0,0,6"/>
      <ProgressBar x:Name="Bar" Height="10" IsIndeterminate="False" Minimum="0" Maximum="100" Value="0"/>
      <ScrollViewer Margin="0,8,0,0" Background="#0B1220"><TextBlock x:Name="Out" FontFamily="Consolas" TextWrapping="Wrap" Margin="8"/></ScrollViewer>
    </StackPanel>

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
$BtnSanity = $win.FindName("BtnSanity")
$BtnUpdate = $win.FindName("BtnUpdate")
$BtnLogs   = $win.FindName("BtnLogs")
$BtnClose  = $win.FindName("BtnClose")
$Bar       = $win.FindName("Bar")
$Out       = $win.FindName("Out")
$VerTxt    = $win.FindName("VerTxt")
$VerTxt.Text = $Version
$BtnClose.Add_Click({ $win.Close() })

function Use-Shell {
  $pw = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($pw) { return $pw.Path } else { return (Get-Command powershell -ErrorAction Stop).Path }
}
function Append([string]$t){ $Out.Text += ($t + [Environment]::NewLine) }

# Buttons
$BtnSanity.Add_Click({
  try {
    Append "Launching sanity.view.ps1..."
    $sh = Use-Shell
    Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $SanV) | Out-Null
  } catch { Append "Error: $($_.Exception.Message)" }
})

$BtnLogs.Add_Click({
  try { if (-not (Test-Path $Logs)) { New-Item -ItemType Directory -Force -Path $Logs | Out-Null }
        Start-Process explorer.exe $Logs } catch { Append "Error opening logs: $($_.Exception.Message)" }
})

$BtnUpdate.Add_Click({
  try {
    $Bar.IsIndeterminate = $true; $Out.Text = ""
    Append "Running update (git pull → sanity → commit/push on PASS)..."
    $sh = Use-Shell
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
  } catch {
    $Bar.IsIndeterminate = $false; Append "Update error: $($_.Exception.Message)"
  }
})

$win.ShowDialog() | Out-Null
