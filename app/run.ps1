param()
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# --- XAML (modern dark UI) ---
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion" Height="680" Width="1024"
        WindowStartupLocation="CenterScreen"
        Background="#11131A" Foreground="#F5F7FA" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="72"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="28"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="#1A1D29" Padding="16">
      <DockPanel LastChildFill="True">
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
          <TextBlock Text="Operion" FontSize="22" FontWeight="Bold" Foreground="#00E5FF" Margin="0,0,12,0"/>
          <TextBlock Text="— Automation • Analytics • Security" Opacity="0.75" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" HorizontalAlignment="Right" >
          <Button x:Name="BtnAbout" Content="About" Padding="12,6" Margin="0,0,8,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
          <Button x:Name="BtnQuit"  Content="Quit"  Padding="12,6" Background="#2E3243" BorderBrush="#454B63" />
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Main Tabs -->
    <TabControl Grid.Row="1" x:Name="Tabs" Background="#11131A" BorderThickness="0">
      <!-- Automation -->
      <TabItem Header="Automation">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="AutoRunBtn"    Content="Run Flow"       Padding="12,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
            <Button x:Name="AutoSchedBtn"  Content="Schedule Task"  Padding="12,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
            <Button x:Name="AutoStopBtn"   Content="Stop"           Padding="12,6" Background="#2E3243" BorderBrush="#454B63"/>
          </StackPanel>
          <TextBox x:Name="AutoLog" Grid.Row="1" Background="#1A1D29" Foreground="#F5F7FA"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Analytics -->
      <TabItem Header="Analytics">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="AnaRefreshBtn" Content="Refresh KPIs" Padding="12,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
            <Button x:Name="AnaExportBtn"  Content="Export CSV"   Padding="12,6" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="AnaLog" Grid.Row="1" Background="#1A1D29" Foreground="#F5F7FA"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Security -->
      <TabItem Header="Security">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="SecAuditBtn"   Content="Run Audit"      Padding="12,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
            <Button x:Name="SecHardenBtn"  Content="Apply Hardening" Padding="12,6" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="SecLog" Grid.Row="1" Background="#1A1D29" Foreground="#F5F7FA"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Integrations -->
      <TabItem Header="Integrations">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="IntConnectBtn" Content="Connect Service" Padding="12,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
            <Button x:Name="IntTestBtn"    Content="Test Connection" Padding="12,6" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="IntLog" Grid.Row="1" Background="#1A1D29" Foreground="#F5F7FA"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Settings -->
      <TabItem Header="Settings">
        <Grid Margin="12">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="SetSaveBtn" Content="Save Settings" Padding="12,6" Background="#00E5FF" Foreground="#101318" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="SetLog" Grid.Row="1" Background="#1A1D29" Foreground="#F5F7FA"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>
    </TabControl>

    <!-- Footer -->
    <DockPanel Grid.Row="2" Background="#1A1D29" LastChildFill="True">
      <TextBlock Text="© Operion" Margin="10,4,0,0" Opacity="0.65"/>
      <TextBlock Text="{Binding ElementName=StatusText, Path=Text}" Visibility="Collapsed"/>
      <TextBlock x:Name="StatusText" Text="Ready" Margin="0,4,10,0" HorizontalAlignment="Right" Opacity="0.75"/>
    </DockPanel>
  </Grid>
</Window>
"@

# Build visual tree
$Window = [Windows.Markup.XamlReader]::Parse($xaml)

# Helpers
function Append-Log($tb,[string]$msg){
  $tb.AppendText($msg + "`r`n")
  $tb.ScrollToEnd()
}

# Resolve paths
$ScriptDir = Split-Path -Parent $PSCommandPath
$Root      = (Resolve-Path (Join-Path $ScriptDir "..")).Path
$LogsDir   = Join-Path $Root "_logs"
$ExportDir = Join-Path $Root "_exports"
[void][IO.Directory]::CreateDirectory($LogsDir)
[void][IO.Directory]::CreateDirectory($ExportDir)

# Wire buttons & logs
$AutoLog = $Window.FindName('AutoLog'); $AnaLog=$Window.FindName('AnaLog')
$SecLog  = $Window.FindName('SecLog');  $IntLog=$Window.FindName('IntLog')
$SetLog  = $Window.FindName('SetLog')

# Header buttons
$Window.FindName('BtnQuit').Add_Click({ $Window.Close() })
$Window.FindName('BtnAbout').Add_Click({
  [System.Windows.MessageBox]::Show("Operion — streamlined automation, analytics, security, integrations.`r`nBuild: $(Get-Date -Format 'yyyy-MM-dd HH:mm')","About Operion","OK","Information")
})

# Automation
$Window.FindName('AutoRunBtn').Add_Click({
  Append-Log $AutoLog "Starting flow…"
  Start-Sleep -Milliseconds 250
  Append-Log $AutoLog "Step 1 ✓"
  Start-Sleep -Milliseconds 200
  Append-Log $AutoLog "Step 2 ✓"
  Append-Log $AutoLog "Flow complete ✅"
})
$Window.FindName('AutoSchedBtn').Add_Click({ Append-Log $AutoLog "Scheduling task (stub)…" })
$Window.FindName('AutoStopBtn').Add_Click({ Append-Log $AutoLog "Stop signal sent (stub)." })

# Analytics
$Window.FindName('AnaRefreshBtn').Add_Click({ Append-Log $AnaLog "Refreshing KPIs (stub)…" })
$Window.FindName('AnaExportBtn').Add_Click({
  $file = Join-Path $ExportDir ("dashboard_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
  "metric,value`nrevenue,12345`nleads,67" | Set-Content -Encoding UTF8 $file
  Append-Log $AnaLog "Exported $file"
})

# Security
$Window.FindName('SecAuditBtn').Add_Click({ Append-Log $SecLog "Audit complete: 0 critical, 2 info." })
$Window.FindName('SecHardenBtn').Add_Click({ Append-Log $SecLog "Baseline hardening applied." })

# Integrations
$Window.FindName('IntConnectBtn').Add_Click({ Append-Log $IntLog "Connect dialog (placeholder)." })
$Window.FindName('IntTestBtn').Add_Click({ Append-Log $IntLog "Connection OK." })

# Settings
$Window.FindName('SetSaveBtn').Add_Click({ Append-Log $SetLog "Settings saved." })

# Show window
$Window.ShowDialog() | Out-Null
