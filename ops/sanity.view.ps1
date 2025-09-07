Add-Type -AssemblyName PresentationFramework
$X = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Operion — Sanity" Width="560" Height="420"
        WindowStartupLocation="CenterScreen" Background="#111827" Foreground="#E5E7EB" FontFamily="Segoe UI">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,8">
      <TextBlock Text="Sanity Status:" FontSize="18" FontWeight="Bold"/>
      <TextBlock x:Name="StatusText" Text="  Running..." FontSize="18" Margin="8,0,0,0"/>
    </StackPanel>
    <ProgressBar x:Name="Bar" Grid.Row="1" Height="10" IsIndeterminate="True"/>
    <ScrollViewer Grid.Row="2" Margin="0,12,0,12" Background="#0B1220"><TextBlock x:Name="Output" FontFamily="Consolas" TextWrapping="Wrap" Margin="8"/></ScrollViewer>
    <DockPanel Grid.Row="3">
      <Button x:Name="CopyBtn" Content="Copy" Width="90" Height="30" Margin="0,0,8,0" />
      <Button x:Name="CloseBtn" Content="Close" Width="90" Height="30" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@
$win=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$X)))
$StatusText=$win.FindName("StatusText"); $Bar=$win.FindName("Bar"); $Output=$win.FindName("Output")
($win.FindName("CloseBtn")).Add_Click({ $win.Close() })
($win.FindName("CopyBtn")).Add_Click({ $Output.Text | Set-Clipboard })

# choose pwsh or powershell
$sh=(Get-Command pwsh -EA SilentlyContinue)?.Source; if(-not $sh){ $sh=(Get-Command powershell).Source }
$so=[IO.Path]::GetTempFileName(); $se=[IO.Path]::GetTempFileName()
$ps=Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'sanity.ps1')) `
     -PassThru -WindowStyle Hidden -RedirectStandardOutput $so -RedirectStandardError $se

$t=New-Object Windows.Threading.DispatcherTimer; $t.Interval=[TimeSpan]::FromMilliseconds(600)
$t.Add_Tick({
  if($ps.HasExited){
    $Bar.IsIndeterminate=$false; $Bar.Value=100
    $text=(Get-Content -Raw -LiteralPath $so) + "`n" + (Get-Content -Raw -LiteralPath $se)
    $Output.Text=$text
    if($ps.ExitCode -eq 0){ $StatusText.Text="  ✓ PASS"; $StatusText.Foreground=New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(34,197,94)) }
    else { $StatusText.Text="  ✗ FAIL"; $StatusText.Foreground=New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromRgb(239,68,68)) }
    $t.Stop()
  } else { $StatusText.Text="  Running..." }
})
$t.Start(); $win.ShowDialog() | Out-Null
