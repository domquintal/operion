$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework

# Relaunch in STA if needed (WPF requirement)
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  $pw = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pw) { $pw = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
  Start-Process -FilePath $pw -ArgumentList @('-STA','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") -WorkingDirectory (Split-Path $PSCommandPath -Parent)
  exit
}

# Load config
$OpsDir = Split-Path $PSCommandPath -Parent
$Root   = Split-Path $OpsDir -Parent
Import-Module (Join-Path $OpsDir 'lib\config.psm1') -Force
$CFG = Get-OperionConfig -OpsDir $OpsDir

function Start-PS1 {
  param([string]$Path,[string[]]$Args=@())
  if (!(Test-Path $Path)) { [System.Windows.MessageBox]::Show("Missing: $Path",'Operion') | Out-Null; return }
  $pw = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pw) { $pw = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
  $alist = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$Path`"") + $Args
  Start-Process -FilePath $pw -ArgumentList $alist -WorkingDirectory $Root | Out-Null
}

[xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion Hub" Height="520" Width="720" WindowStartupLocation="CenterScreen"
        Background="#111318" Foreground="#EAEAEA" FontFamily="Segoe UI" FontSize="14">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,12">
      <TextBlock Text="OPERION HUB" FontWeight="Bold" FontSize="22"/>
      <TextBlock Text="  —  all controls in one place" Opacity="0.7" Margin="8,4,0,0"/>
    </StackPanel>
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,12">
      <TextBlock Text="PIN:" VerticalAlignment="Center" Width="40"/>
      <PasswordBox x:Name="PinBox" Width="160"/>
      <Button x:Name="Unlock" Content="Unlock" Width="120" Margin="12,0,0,0"/>
      <TextBlock x:Name="PinMsg" Margin="12,4,0,0" Foreground="#FF6B6B"/>
    </StackPanel>
    <UniformGrid Grid.Row="2" Rows="4" Columns="2" Margin="0,0,0,12">
      <Button x:Name="Launch"      Content="Launch App"                                      Margin="6" />
      <Button x:Name="SelfTest"    Content="Self-Test (CI mode)"                             Margin="6" />
      <Button x:Name="Parity"      Content="Parity Check"                                    Margin="6" />
      <Button x:Name="Snapshot"    Content="Snapshot (tree + hashes)"                        Margin="6" />
      <Button x:Name="OpenLogs"    Content="Open Logs Folder"                                Margin="6" />
      <Button x:Name="OpenRoot"    Content="Open Repo Folder"                                Margin="6" />
      <Button x:Name="PushLocal"   Content="Force Sync → Push Local (requires PIN)"          Margin="6" IsEnabled="False"/>
      <Button x:Name="ResetRemote" Content="Force Sync → Reset to Remote (Danger, PIN)"      Margin="6" IsEnabled="False"/>
    </UniformGrid>
    <DockPanel Grid.Row="3">
      <TextBlock Text="{Binding AppInfo}" x:Name="Info" Opacity="0.6" />
      <Button x:Name="ExitBtn" Content="Exit" HorizontalAlignment="Right" Width="120" DockPanel.Dock="Right"/>
    </DockPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $x
$w = [Windows.Markup.XamlReader]::Load($reader)

$PinBox       = $w.FindName('PinBox')
$UnlockBtn    = $w.FindName('Unlock')
$PinMsg       = $w.FindName('PinMsg')
$LaunchBtn    = $w.FindName('Launch')
$SelfTestBtn  = $w.FindName('SelfTest')
$ParityBtn    = $w.FindName('Parity')
$SnapshotBtn  = $w.FindName('Snapshot')
$OpenLogsBtn  = $w.FindName('OpenLogs')
$OpenRootBtn  = $w.FindName('OpenRoot')
$PushLocalBtn = $w.FindName('PushLocal')
$ResetBtn     = $w.FindName('ResetRemote')
$ExitBtn      = $w.FindName('ExitBtn')

$w.DataContext = [pscustomobject]@{ AppInfo = "Operion  •  Repo: $Root" }

# Unlock (enables dangerous buttons)
$UnlockBtn.Add_Click( {
  $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($PinBox.SecurePassword)
  try { $entered=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { if($b -ne [IntPtr]::Zero){ [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) } }
  if ($entered -eq $CFG.Pin) {
    $PinMsg.Text = 'Unlocked'; $PinMsg.Foreground = 'LightGreen'
    if ($CFG.EnableDangerButtons) { $PushLocalBtn.IsEnabled=$true; $ResetBtn.IsEnabled=$true }
  } else { $PinMsg.Text='Invalid PIN'; $PinMsg.Foreground='OrangeRed' }
} )

# Safe actions
$LaunchBtn.Add_Click( { $lr = Join-Path $OpsDir 'log_retention.ps1'
  if (Test-Path $lr) { & $lr 2>$null }
  if ($CFG.LauncherPath -and (Test-Path $CFG.LauncherPath)) { Start-PS1 -Path $CFG.LauncherPath }
  else { [System.Windows.MessageBox]::Show("No launcher found: $($CFG.LauncherPath)","Operion") | Out-Null }
 } )
$SelfTestBtn.Add_Click( { Start-PS1 -Path (Join-Path $OpsDir 'self_test.ps1') -Args @('-CI')  } )
$ParityBtn.Add_Click( { Start-PS1 -Path (Join-Path $OpsDir 'parity_check.ps1')  } )
$SnapshotBtn.Add_Click( { Start-PS1 -Path (Join-Path $OpsDir 'snapshot.ps1')  } )
$OpenLogsBtn.Add_Click( { if(Test-Path $CFG.LogsPath){ Start-Process explorer.exe "$($CFG.LogsPath)" } else { [System.Windows.MessageBox]::Show("Logs path missing: $($CFG.LogsPath)","Operion") | Out-Null }
 } )
$OpenRootBtn.Add_Click( { Start-Process explorer.exe "$Root"  } )

# Dangerous actions (require PIN unlock)
$PushLocalBtn.Add_Click( { if (-not $PushLocalBtn.IsEnabled) { [System.Windows.MessageBox]::Show("Unlock with PIN first.","Operion") | Out-Null; return }
  Start-PS1 -Path (Join-Path $OpsDir 'force_sync.ps1') -Args @('-Mode','push_local','-Yes')
 } )
$ResetBtn.Add_Click( { if (-not $ResetBtn.IsEnabled) { [System.Windows.MessageBox]::Show("Unlock with PIN first.","Operion") | Out-Null; return }
  $r = [System.Windows.MessageBox]::Show("CONFIRM: Hard reset LOCAL to origin/branch (LOCAL CHANGES LOST).","Operion",1,"Warning")
  if ($r -eq 'OK') { Start-PS1 -Path (Join-Path $OpsDir 'force_sync.ps1') -Args @('-Mode','reset_to_remote','-Yes') }
 } )

$ExitBtn.Add_Click( { $w.Close() } )

[void]$w.ShowDialog()





