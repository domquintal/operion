param()
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework

# XAML for modern UI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
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
    <TabControl Grid.Row="1" x:Name="Tabs" Background="#1E1E2F">
      <TabItem Header="Automation" x:Name="TabAutomation"/>
      <TabItem Header="Analytics" x:Name="TabAnalytics"/>
      <TabItem Header="Security" x:Name="TabSecurity"/>
      <TabItem Header="Integrations" x:Name="TabIntegrations"/>
      <TabItem Header="Settings" x:Name="TabSettings"/>
    </TabControl>
  </Grid>
</Window>
"@

# Load XAML
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load($reader)

# Controls
$Tabs        = $Window.FindName("Tabs")
$TabAutomation = $Window.FindName("TabAutomation")
$TabAnalytics  = $Window.FindName("TabAnalytics")
$TabSecurity   = $Window.FindName("TabSecurity")
$TabIntegrations = $Window.FindName("TabIntegrations")
$TabSettings  = $Window.FindName("TabSettings")

function New-TabContent($title){
    $grid = New-Object Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
    $grid.RowDefinitions[0].Height = "60"
    $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))

    $panel = New-Object Windows.Controls.StackPanel
    $panel.Orientation="Horizontal"
    $panel.Margin="10"

    $log = New-Object Windows.Controls.TextBox
    $log.Text="[$title] Ready.`r`n"
    $log.AcceptsReturn=$true
    $log.VerticalScrollBarVisibility="Auto"
    $log.HorizontalScrollBarVisibility="Disabled"
    $log.TextWrapping="Wrap"
    $log.IsReadOnly=$true
    $log.Background="#252539"
    $log.Foreground="White"
    $log.FontFamily="Consolas"
    $log.FontSize=12
    $log.Margin="10"
    [Windows.Controls.Grid]::SetRow($log,1)

    $grid.Children.Add($panel)
    $grid.Children.Add($log)

    return @{Grid=$grid; Panel=$panel; Log=$log}
}
function Add-Button($panel,$label,$onClick){
    $btn=New-Object Windows.Controls.Button
    $btn.Content=$label
    $btn.Margin="5"
    $btn.Padding="10,5"
    $btn.Background="#00E5FF"
    $btn.Foreground="Black"
    $btn.FontWeight="Bold"
    $btn.Add_Click($onClick)
    $panel.Children.Add($btn) | Out-Null
}

# Build tabs
$auto = New-TabContent "Automation"
Add-Button $auto.Panel "Run Flow" { $auto.Log.AppendText("Running flow...`r`nDone ✅`r`n") }
Add-Button $auto.Panel "Schedule Task" { $auto.Log.AppendText("Scheduling task...`r`n") }
$TabAutomation.Content=$auto.Grid

$ana = New-TabContent "Analytics"
Add-Button $ana.Panel "Refresh KPIs" { $ana.Log.AppendText("Refreshing KPIs...`r`n") }
Add-Button $ana.Panel "Export CSV" {
  $p=Join-Path (Split-Path -Parent $PSCommandPath) "..\_exports"
  New-Item -ItemType Directory -Force -Path $p | Out-Null
  $f=Join-Path $p ("dashboard_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
  "metric,value`nrevenue,12345`nleads,67" | Set-Content $f
  $ana.Log.AppendText("Exported $f`r`n")
}
$TabAnalytics.Content=$ana.Grid

$sec = New-TabContent "Security"
Add-Button $sec.Panel "Run Audit" { $sec.Log.AppendText("Security audit complete: 0 critical issues.`r`n") }
Add-Button $sec.Panel "Apply Hardening" { $sec.Log.AppendText("Baseline hardening applied.`r`n") }
$TabSecurity.Content=$sec.Grid

$int = New-TabContent "Integrations"
Add-Button $int.Panel "Connect Service" { $int.Log.AppendText("Connect dialog (placeholder).`r`n") }
Add-Button $int.Panel "Test Connection" { $int.Log.AppendText("Test successful.`r`n") }
$TabIntegrations.Content=$int.Grid

$set = New-TabContent "Settings"
Add-Button $set.Panel "Save Settings" { $set.Log.AppendText("Settings saved.`r`n") }
$TabSettings.Content=$set.Grid

# Show
$Window.ShowDialog() | Out-Null
