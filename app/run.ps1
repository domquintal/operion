$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework

# Relaunch in STA for WPF
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  $pw = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pw) { $pw = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
  Start-Process -FilePath $pw -ArgumentList @('-STA','-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"") -WorkingDirectory (Split-Path $PSCommandPath -Parent)
  exit
}

$AppDir = Split-Path $PSCommandPath -Parent
$Root   = Split-Path $AppDir -Parent
$OpsDir = Join-Path $Root 'ops'

function Load-Config {
  # prefer repo-root config, else ops\config.psd1, else defaults
  $paths = @(
    (Join-Path $Root 'config.psd1'),
    (Join-Path $OpsDir 'config.psd1')
  )
  foreach($p in $paths){
    if(Test-Path $p){
      $h = Import-PowerShellDataFile -Path $p
      return [pscustomobject]@{
        Pin                 = "$($h.Pin)"
        LogsPath            = (Resolve-Path (Join-Path $OpsDir $h.LogsPath) -ErrorAction SilentlyContinue)?.Path ?? (Join-Path $Root '_logs')
        LauncherPath        = if([System.IO.Path]::IsPathRooted($h.LauncherPath)){ $h.LauncherPath } else { (Join-Path $OpsDir $h.LauncherPath) }
        EnableDangerButtons = [bool]$h.EnableDangerButtons
      }
    }
  }
  return [pscustomobject]@{
    Pin                 = '0000'
    LogsPath            = (Join-Path $Root '_logs')
    LauncherPath        = (Join-Path $Root 'app\run.ps1')
    EnableDangerButtons = $true
  }
}
$CFG = Load-Config
New-Item -ItemType Directory -Force -Path $CFG.LogsPath | Out-Null

function Git-Info {
  try {
    Push-Location $Root
    $branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $local  = (git rev-parse HEAD 2>$null).Trim()
    $remote = ''
    try { $remote = (git rev-parse ("origin/" + $branch) 2>$null).Trim() } catch {}
    $counts = ''
    if($remote){ try { $counts = (git rev-list --left-right --count ("origin/" + $branch + "...HEAD")) } catch {} }
    $ahead=0;$behind=0
    if($counts){ $p=$counts -split '\s+'; if($p.Count -ge 2){ $behind=[int]$p[0]; $ahead=[int]$p[1] } }
    [pscustomobject]@{
      Branch = $branch
      Local  = $local
      Remote = $remote
      Ahead  = $ahead
      Behind = $behind
      Clean  = [string]::IsNullOrWhiteSpace((git status --porcelain))
    }
  } catch {
    [pscustomobject]@{ Branch='?'; Local='?'; Remote=''; Ahead=0; Behind=0; Clean=$false }
  } finally { Pop-Location }
}

function Append([string]$text) {
  $Output.AppendText(($text -replace "`r?`n$","") + "`r`n")
  $Output.ScrollToEnd()
}

function Start-PS1([string]$path,[string[]]$args=@()){
  if (!(Test-Path $path)) { Append "Missing: $path"; return }
  $pw = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  if (-not $pw) { $pw = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $pw
  $psi.WorkingDirectory = $Root
  $psi.Arguments = (@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$path`"") + $args) -join ' '
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)

  $hdlrOut = [System.Diagnostics.DataReceivedEventHandler]{ param($s,$e) if($e.Data){ $w.Dispatcher.Invoke({ Append $e.Data }) } }
  $hdlrErr = [System.Diagnostics.DataReceivedEventHandler]{ param($s,$e) if($e.Data){ $w.Dispatcher.Invoke({ Append ('[ERR] ' + $e.Data) }) } }
  $p.add_OutputDataReceived($hdlrOut)
  $p.add_ErrorDataReceived($hdlrErr)
  $p.BeginOutputReadLine(); $p.BeginErrorReadLine() | Out-Null
}

[xml]$x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Operion App" Height="520" Width="780" WindowStartupLocation="CenterScreen"
        Background="#0f1115" Foreground="#eaeaea" FontFamily="Segoe UI" FontSize="14">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,12">
      <TextBlock Text="OPERION APP" FontWeight="Bold" FontSize="22"/>
      <TextBlock x:Name="GitLine" Text="" Opacity="0.7" Margin="12,4,0,0"/>
    </StackPanel>

    <Border Grid.Row="1" Padding="12" Background="#171a21" CornerRadius="10">
      <DockPanel>
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Top" Margin="0,0,0,10">
          <Button x:Name="RefreshBtn" Content="Refresh" Margin="0,0,8,8"/>
          <Button x:Name="ParityBtn" Content="Parity Check" Margin="0,0,8,8"/>
          <Button x:Name="SelfBtn" Content="Self-Test" Margin="0,0,8,8"/>
          <Button x:Name="SnapBtn" Content="Snapshot" Margin="0,0,8,8"/>
          <Button x:Name="LogsBtn" Content="Open Logs" Margin="0,0,8,8"/>
          <Button x:Name="RepoBtn" Content="Open Repo" Margin="0,0,8,8"/>
          <TextBlock Text=" PIN:" VerticalAlignment="Center" Margin="16,0,4,0"/>
          <PasswordBox x:Name="PinBox" Width="130" Margin="0,0,8,0"/>
          <Button x:Name="UnlockBtn" Content="Unlock" Margin="0,0,8,8" Width="90"/>
          <TextBlock x:Name="PinMsg" Margin="4,4,0,0"/>
          <Button x:Name="PushBtn" Content="Push Local → Remote" Margin="16,0,8,8" IsEnabled="False"/>
          <Button x:Name="ResetBtn" Content="Reset Local ← Remote (Danger)" Margin="0,0,8,8" IsEnabled="False"/>
        </StackPanel>
        <TextBox x:Name="Output" Margin="0,8,0,0" Height="320" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True"/>
      </DockPanel>
    </Border>

    <DockPanel Grid.Row="2" Margin="0,12,0,0">
      <TextBlock Text="Operion ©" Opacity="0.6" />
      <Button x:Name="ExitBtn" Content="Exit" DockPanel.Dock="Right" Width="100"/>
    </DockPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $x
$w = [Windows.Markup.XamlReader]::Load($reader)

$GitLine   = $w.FindName('GitLine')
$Output    = $w.FindName('Output')
$Refresh   = $w.FindName('RefreshBtn')
$ParityBtn = $w.FindName('ParityBtn')
$SelfBtn   = $w.FindName('SelfBtn')
$SnapBtn   = $w.FindName('SnapBtn')
$LogsBtn   = $w.FindName('LogsBtn')
$RepoBtn   = $w.FindName('RepoBtn')
$PinBox    = $w.FindName('PinBox')
$UnlockBtn = $w.FindName('UnlockBtn')
$PinMsg    = $w.FindName('PinMsg')
$PushBtn   = $w.FindName('PushBtn')
$ResetBtn  = $w.FindName('ResetBtn')
$ExitBtn   = $w.FindName('ExitBtn')

function Render-GitLine {
  $g = Git-Info
  $GitLine.Text = "  •  $($g.Branch)  +$($g.Ahead)/-$($g.Behind)  Clean=$($g.Clean)"
}

Render-GitLine

$Refresh.Add_Click({ Render-GitLine; Append "Refreshed git status." })
$ParityBtn.Add_Click({ Append "== Parity =="; Start-PS1 (Join-Path $Root 'ops\parity_check.ps1') })
$SelfBtn.Add_Click({ Append "== Self-Test =="; Start-PS1 (Join-Path $Root 'ops\self_test.ps1') @('-CI') })
$SnapBtn.Add_Click({ Append "== Snapshot =="; Start-PS1 (Join-Path $Root 'ops\snapshot.ps1') })
$LogsBtn.Add_Click({ if(Test-Path $CFG.LogsPath){ Start-Process explorer.exe "$($CFG.LogsPath)" } else { Append "Logs path missing: $($CFG.LogsPath)" } })
$RepoBtn.Add_Click({ Start-Process explorer.exe "$Root" })

$UnlockBtn.Add_Click({
  $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($PinBox.SecurePassword)
  try { $entered=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { if($b -ne [IntPtr]::Zero){ [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) } }
  if ($entered -eq $CFG.Pin -and $CFG.EnableDangerButtons) {
    $PinMsg.Text='Unlocked'; $PinMsg.Foreground='LightGreen'; $PushBtn.IsEnabled=$true; $ResetBtn.IsEnabled=$true
  } else { $PinMsg.Text='Invalid or disabled'; $PinMsg.Foreground='OrangeRed' }
})

$PushBtn.Add_Click({
  if (-not $PushBtn.IsEnabled) { Append "Unlock with PIN first."; return }
  Append "== Force Sync: Push Local → Remote =="
  Start-PS1 (Join-Path $Root 'ops\force_sync.ps1') @('-Mode','push_local','-Yes')
})

$ResetBtn.Add_Click({
  if (-not $ResetBtn.IsEnabled) { Append "Unlock with PIN first."; return }
  $r = [System.Windows.MessageBox]::Show("CONFIRM: reset LOCAL to origin/branch (LOCAL CHANGES LOST).","Operion",1,"Warning")
  if ($r -eq 'OK') {
    Append "== Force Sync: Reset Local ← Remote =="
    Start-PS1 (Join-Path $Root 'ops\force_sync.ps1') @('-Mode','reset_to_remote','-Yes')
  }
})

$ExitBtn.Add_Click({ $w.Close() })

[void]$w.ShowDialog()
