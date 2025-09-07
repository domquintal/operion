$ErrorActionPreference="Stop"
Add-Type -AssemblyName PresentationFramework

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
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
    <DockPanel Grid.Row="3"><Button x:Name="CopyBtn" Content="Copy" Width="90" Height="30" Margin="0,0,8,0"/><Button x:Name="CloseBtn" Content="Close" Width="90" Height="30" DockPanel.Dock="Right"/></DockPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$win    = [Windows.Markup.XamlReader]::Load($reader)

$StatusText=$win.FindName("StatusText");$Bar=$win.FindName("Bar");$Output=$win.FindName("Output")
($win.FindName("CloseBtn")).Add_Click({ $win.Close() }); ($win.FindName("CopyBtn")).Add_Click({ $Output.Text | Set-Clipboard })

$pw=Get-Command pwsh -ErrorAction SilentlyContinue; $sh=$(if($pw){$pw.Path}else{(Get-Command powershell -EA Stop).Path})
$so=[IO.Path]::GetTempFileName(); $se=[IO.Path]::GetTempFileName()
$san= Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'sanity.ps1'
$ps=Start-Process $sh -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $san) -PassThru -WindowStyle Hidden -RedirectStandardOutput $so -RedirectStandardError $se
$t=New-Object Windows.Threading.DispatcherTimer; $t.Interval=[TimeSpan]::FromMilliseconds(600)
$t.Add_Tick({ if($ps.HasExited){ $Bar.IsIndeterminate=$false;$Bar.Value=100;$Output.Text=(Get-Content -Raw -LiteralPath $so)+"`r`n"+(Get-Content -Raw -LiteralPath $se); if($ps.ExitCode -eq 0){$StatusText.Text="  ✓ PASS"}else{$StatusText.Text="  ✗ FAIL"}; $t.Stop() } })
$t.Start(); $win.ShowDialog() | Out-Null
