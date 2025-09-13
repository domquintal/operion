$ErrorActionPreference = 'Stop'

# Ensure WPF assemblies
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase

# Resolve paths relative to this script
$Ops  = Split-Path $PSCommandPath -Parent
$Root = Split-Path $Ops -Parent
$Logs = Join-Path $Root '_logs'
$PinRequired = '0000'

# Helper scripts
$LogRetention = Join-Path $Ops 'log_retention.ps1'
$ParityPath   = Join-Path $Ops 'parity_check.ps1'
$ForcePath    = Join-Path $Ops 'force_sync.ps1'

# Try to locate an app launcher
$Launcher = Join-Path $Root 'run.ps1'
if (!(Test-Path $Launcher)) {
  $cand = Get-ChildItem -Path $Root -Recurse -Filter 'run.ps1' -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cand) { $Launcher = $cand.FullName } else {
    $cmd = Get-ChildItem -Path $Root -Recurse -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|start|run' } | Select-Object -First 1
    if ($cmd) { $Launcher = $cmd.FullName } else {
      $py = Get-ChildItem -Path $Root -Recurse -Include 'main.py','app.py' -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($py) {
        $Shim = Join-Path $Ops 'launch_shim.ps1'
        @"
`$ErrorActionPreference = 'Stop'
`$Target = '$($py.FullName -replace '\\','\\')'
`$Root   = '$($Root -replace '\\','\\')'
`$VenvPy = Join-Path `$Root 'venv\Scripts\python.exe'
if (Test-Path `$VenvPy) { & `$VenvPy "`$Target" } else { & python "`$Target" }
"@ | Set-Content -Encoding UTF8 $Shim
        $Launcher = $Shim
      } else { $Launcher = $null }
    }
  }
}

# XAML UI  (NOTE the xmlns:x added)
[xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion Hub" Height="430" Width="620" WindowStartupLocation="CenterScreen"
        Background="#111318" Foreground="#EAEAEA" FontFamily="Segoe UI" FontSize="14">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,12">
      <TextBlock Text="OPERION HUB" FontWeight="Bold" FontSize="20" />
      <TextBlock Text="  —  select an action" Opacity="0.7" Margin="8,4,0,0"/>
    </StackPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
      <TextBlock Text="PIN:" VerticalAlignment="Center" Width="40"/>
      <PasswordBox x:Name="PinBox" Width="140"/>
      <Button x:Name="UnlockBtn" Content="Unlock" Width="100" Margin="12,0,0,0"/>
      <TextBlock x:Name="PinMsg" Margin="12,4,0,0" Foreground="#FF6B6B"/>
    </StackPanel>
    <UniformGrid Grid.Row="2" Rows="3" Columns="2" Margin="0,0,0,12">
      <Button x:Name="LaunchApp" Content="Launch App" Margin="6" IsEnabled="False"/>
      <Button x:Name="OpenLogs" Content="Open Logs Folder" Margin="6" IsEnabled="True"/>
      <Button x:Name="Parity" Content="Parity Check" Margin="6" IsEnabled="True"/>
      <Button x:Name="PushLocal" Content="Force Sync → Push Local" Margin="6" IsEnabled="False"/>
      <Button x:Name="ResetRemote" Content="Force Sync → Reset to Remote (Danger)" Margin="6" IsEnabled="False"/>
      <Button x:Name="RepairShortcut" Content="Repair Desktop Shortcut" Margin="6" IsEnabled="True"/>
    </UniformGrid>
    <DockPanel Grid.Row="3">
      <TextBlock Text="Operion ©" Opacity="0.6" />
      <Button x:Name="ExitBtn" Content="Exit" HorizontalAlignment="Right" Width="100" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@

# Prefer XamlReader.Parse() to avoid quirky XML casting issues
$windowXaml = $x.OuterXml
$w = [Windows.Markup.XamlReader]::Parse($windowXaml)

# Wire controls
$PinBox        = $w.FindName('PinBox')
$UnlockBtn     = $w.FindName('UnlockBtn')
$PinMsg        = $w.FindName('PinMsg')
$LaunchApp     = $w.FindName('LaunchApp')
$OpenLogs      = $w.FindName('OpenLogs')
$Parity        = $w.FindName('Parity')
$PushLocal     = $w.FindName('PushLocal')
$ResetRemote   = $w.FindName('ResetRemote')
$RepairShortcut= $w.FindName('RepairShortcut')
$ExitBtn       = $w.FindName('ExitBtn')

# Unlock
$UnlockBtn.Add_Click({
  $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($PinBox.SecurePassword)
  try { $entered=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { if($b -ne [IntPtr]::Zero){ [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) } }
  if ($entered -eq $PinRequired) {
    $PinMsg.Text = 'Unlocked'; $PinMsg.Foreground = 'LightGreen'
    $LaunchApp.IsEnabled = $true; $PushLocal.IsEnabled = $true; $ResetRemote.IsEnabled = $true
  } else {
    $PinMsg.Text = 'Invalid PIN'; $PinMsg.Foreground = 'OrangeRed'
  }
})

# Actions

# Diagnostics: run self_test.ps1 in a visible console
$Diagnostics.Add_Click({
  $st = Join-Path $Ops 'self_test.ps1'
  if (Test-Path $st) {
    Start-Process powershell -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $st)
  } else {
    [System.Windows.MessageBox]::Show('self_test.ps1 not found','Operion')
  }
})$LaunchApp.Add_Click({
  if ($Launcher) { & $LogRetention 2>$null; & $Launcher } else { [System.Windows.MessageBox]::Show('No launcher found','Operion') }
})
$OpenLogs.Add_Click({ if(Test-Path $Logs){ Start-Process explorer.exe "$Logs" } })
$Parity.Add_Click({ & $ParityPath })
$PushLocal.Add_Click({ & $ForcePath -Mode push_local -Yes })
$ResetRemote.Add_Click({ & $ForcePath -Mode reset_to_remote -Yes })
$RepairShortcut.Add_Click({
  $desktop=[Environment]::GetFolderPath('Desktop')
  $lnk=Join-Path $desktop 'Operion.lnk'
  $ps=(Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if(-not $ps){ $ps=(Get-Command powershell -ErrorAction SilentlyContinue).Source }
  if(-not (Test-Path $ps)){ $ps="$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
  $ws=New-Object -ComObject WScript.Shell
  $sc=$ws.CreateShortcut($lnk)
  $sc.TargetPath=$ps
  $sc.Arguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'"'
  $sc.WorkingDirectory=$Root
  $icn=(Get-ChildItem -Path $Root -Recurse -Include *.ico,*.png -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'operion|logo|icon'} | Select-Object -First 1)
  if($icn){ $sc.IconLocation = $icn.FullName }
  $sc.Save()
  [System.Windows.MessageBox]::Show("Desktop shortcut repaired:`n$lnk",'Operion')
})
$ExitBtn.Add_Click({ $w.Close() })

# Show (ensure STA if needed)
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  Start-Process powershell -ArgumentList @('-sta','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath)
  return
}
[void]$w.ShowDialog()



