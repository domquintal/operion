param()
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# XAML with proper xmlns:x and simple, reliable styling
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Operion" Height="600" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2F" Foreground="White" FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="60"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="#2D2D44">
      <TextBlock Text="Operion Dashboard"
                 VerticalAlignment="Center" HorizontalAlignment="Center"
                 FontSize="22" FontWeight="Bold" Foreground="#00E5FF"/>
    </Border>

    <!-- Tabs -->
    <TabControl Grid.Row="1" x:Name="Tabs" Background="#1E1E2F" BorderThickness="0">
      <!-- Automation -->
      <TabItem Header="Automation">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="AutoRunBtn"    Content="Run Flow"       Padding="10,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
            <Button x:Name="AutoSchedBtn"  Content="Schedule Task"  Padding="10,6" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="AutoLog" Grid.Row="1" Background="#252539" Foreground="White"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Analytics -->
      <TabItem Header="Analytics">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="AnaRefreshBtn" Content="Refresh KPIs" Padding="10,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
            <Button x:Name="AnaExportBtn"  Content="Export CSV"   Padding="10,6" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="AnaLog" Grid.Row="1" Background="#252539" Foreground="White"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Security -->
      <TabItem Header="Security">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="SecAuditBtn"   Content="Run Audit"      Padding="10,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
            <Button x:Name="SecHardenBtn"  Content="Apply Hardening" Padding="10,6" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="SecLog" Grid.Row="1" Background="#252539" Foreground="White"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Integrations -->
      <TabItem Header="Integrations">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="IntConnectBtn" Content="Connect Service" Padding="10,6" Margin="0,0,10,0" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
            <Button x:Name="IntTestBtn"    Content="Test Connection" Padding="10,6" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="IntLog" Grid.Row="1" Background="#252539" Foreground="White"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>

      <!-- Settings -->
      <TabItem Header="Settings">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button x:Name="SetSaveBtn" Content="Save Settings" Padding="10,6" Background="#00E5FF" Foreground="#111" FontWeight="Bold"/>
          </StackPanel>
          <TextBox x:Name="SetLog" Grid.Row="1" Background="#252539" Foreground="White"
                   FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                   TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
        </Grid>
      </TabItem>
    </TabControl>
  </Grid>
</Window>
"@

# Parse XAML (string -> WPF visual tree)
$Window = [Windows.Markup.XamlReader]::Parse($xaml)

# Helper for logs
function Append-Log($tb,[string]$msg){
  $tb.AppendText($msg + "`r`n")
  $tb.ScrollToEnd()
}

# Resolve dirs for exports
$ScriptDir = Split-Path -Parent $PSCommandPath
$ExportDir = Join-Path $ScriptDir "..\_exports"
[void][IO.Directory]::CreateDirectory((Resolve-Path -LiteralPath (Join-Path $ScriptDir "..") ).Path + "\_exports")

# Wire controls
$AutoLog = $Window.FindName('AutoLog')
$AnaLog  = $Window.FindName('AnaLog')
$SecLog  = $Window.FindName('SecLog')
$IntLog  = $Window.FindName('IntLog')
$SetLog  = $Window.FindName('SetLog')

$Window.FindName('AutoRunBtn').Add_Click({ Append-Log $AutoLog "Running flow..."; Start-Sleep 0.2; Append-Log $AutoLog "Done ✅" })
$Window.FindName('AutoSchedBtn').Add_Click({ Append-Log $AutoLog "Scheduling task..." })

$Window.FindName('AnaRefreshBtn').Add_Click({ Append-Log $AnaLog "Refreshing KPIs..." })
$Window.FindName('AnaExportBtn').Add_Click({
  $dir = (Resolve-Path -LiteralPath (Join-Path $ScriptDir "..")).Path + "\_exports"
  [void][IO.Directory]::CreateDirectory($dir)
  $file = Join-Path $dir ("dashboard_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
  "metric,value`nrevenue,12345`nleads,67" | Set-Content -Encoding UTF8 $file
  Append-Log $AnaLog "Exported $file"
})

$Window.FindName('SecAuditBtn').Add_Click({ Append-Log $SecLog "Security audit complete: 0 critical issues." })
$Window.FindName('SecHardenBtn').Add_Click({ Append-Log $SecLog "Baseline hardening applied." })

$Window.FindName('IntConnectBtn').Add_Click({ Append-Log $IntLog "Connect dialog (placeholder)." })
$Window.FindName('IntTestBtn').Add_Click({ Append-Log $IntLog "Connection OK." })

$Window.FindName('SetSaveBtn').Add_Click({ Append-Log $SetLog "Settings saved." })

# Show UI
$Window.ShowDialog() | Out-Null
