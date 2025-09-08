$ErrorActionPreference="Stop"
Add-Type -AssemblyName PresentationFramework
$This  = $MyInvocation.MyCommand.Path
$Dir   = if($This){ Split-Path -Parent $This } else { $PSScriptRoot }
$Repo  = (Resolve-Path (Join-Path $Dir "..\..")).Path
$Logs  = Join-Path $Repo "_logs"
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion — Dashboard" Width="720" Height="420"
        WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Text="Operational Intelligence" FontSize="20" FontWeight="Bold" Grid.Row="0"/>
    <Grid Grid.Row="1" Margin="0,12,0,12">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border Grid.Column="0" CornerRadius="12" Padding="12" Background="#111827" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="Heartbeat/min" FontWeight="Bold"/>
          <TextBlock x:Name="BeatTxt" FontSize="28" FontWeight="Bold"/>
        </StackPanel>
      </Border>
      <Border Grid.Column="1" CornerRadius="12" Padding="12" Background="#111827" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="Errors (last 24h)" FontWeight="Bold"/>
          <TextBlock x:Name="ErrTxt" FontSize="28" FontWeight="Bold"/>
        </StackPanel>
      </Border>
      <Border Grid.Column="2" CornerRadius="12" Padding="12" Background="#111827">
        <StackPanel>
          <TextBlock Text="Latest Log" FontWeight="Bold"/>
          <TextBlock x:Name="LatestTxt" TextWrapping="Wrap" />
        </StackPanel>
      </Border>
    </Grid>
    <DockPanel Grid.Row="2">
      <Button x:Name="CloseBtn" Content="Close" Width="90" Height="30" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$CloseBtn = $win.FindName("CloseBtn"); $CloseBtn.Add_Click({ $win.Close() })
$BeatTxt  = $win.FindName("BeatTxt");   $ErrTxt  = $win.FindName("ErrTxt"); $LatestTxt=$win.FindName("LatestTxt")
function Get-LatestLog { if(-not (Test-Path $Logs)){ return $null }; Get-ChildItem $Logs -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1 }
function Analyze {
  $lf = Get-LatestLog
  if(-not $lf){ $BeatTxt.Text="0"; $ErrTxt.Text="0"; $LatestTxt.Text="No logs yet."; return }
  $lines = Get-Content -LiteralPath $lf.FullName -Tail 1000
  $now = Get-Date; $lastMin = $now.AddMinutes(-1)
  $beats = ($lines | Where-Object { $_ -match 'heartbeat' -and $_ -match '^\d{4}-\d{2}-\d{2}' -and ([datetime]($_.Substring(0,19))) -ge $lastMin }).Count
  $errs  = ($lines | Where-Object { $_ -match 'CRASH|ERROR|FAIL' -and $_ -match '^\d{4}-\d{2}-\d{2}' -and ([datetime]($_.Substring(0,19))) -ge $now.AddHours(-24) }).Count
  $BeatTxt.Text = $beats.ToString(); $ErrTxt.Text = $errs.ToString(); $LatestTxt.Text = ($lines | Select-Object -Last 1)
}
$timer = New-Object Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ Analyze }); $timer.Start(); Analyze
$win.ShowDialog() | Out-Null
