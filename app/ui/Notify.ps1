$ErrorActionPreference="Stop"
Add-Type -AssemblyName PresentationFramework
$This=$MyInvocation.MyCommand.Path; $Dir=if($This){Split-Path -Parent $This}else{$PSScriptRoot}
$Repo=(Resolve-Path (Join-Path $Dir "..\..")).Path; $Logs=Join-Path $Repo "_logs"
$xaml=@"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Operion — Notifications" Width="840" Height="520" WindowStartupLocation="CenterScreen" Background="#0F172A" Foreground="#E5E7EB" FontFamily="Segoe UI">
 <Grid Margin="16">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
  <TextBlock Text="Notifications Center" FontSize="18" FontWeight="Bold"/>
  <Grid Grid.Row="1" Margin="0,12,0,0">
    <Grid.ColumnDefinitions><ColumnDefinition Width="1.1*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Border Grid.Column="0" Background="#111827" CornerRadius="12" Padding="10" Margin="0,0,12,0">
      <StackPanel>
        <TextBlock Text="Audit (latest 200)" FontWeight="Bold"/>
        <ListView x:Name="AuditList">
          <ListView.View><GridView>
            <GridViewColumn Header="Time" Width="140" DisplayMemberBinding="{Binding timestamp}"/>
            <GridViewColumn Header="User" Width="100" DisplayMemberBinding="{Binding user}"/>
            <GridViewColumn Header="Action" Width="160" DisplayMemberBinding="{Binding action}"/>
            <GridViewColumn Header="Detail" Width="260" DisplayMemberBinding="{Binding detail}"/>
          </GridView></ListView.View>
        </ListView>
      </StackPanel>
    </Border>
    <Border Grid.Column="1" Background="#111827" CornerRadius="12" Padding="10">
      <StackPanel>
        <TextBlock Text="Log Tail (latest)" FontWeight="Bold"/>
        <TextBox x:Name="LogTail" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0" Background="#111827" FontFamily="Consolas" FontSize="12"/>
      </StackPanel>
    </Border>
  </Grid>
 </Grid>
</Window>
"@
$win=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$xaml)))
$AuditList=$win.FindName("AuditList"); $LogTail=$win.FindName("LogTail")
function Read-Audit {
  $f=Join-Path $Logs "audit.csv"; if(-not (Test-Path $f)){ return @() }
  $rows = Get-Content -LiteralPath $f | Select-Object -Skip 1 | Select-Object -Last 200
  $rows | ForEach-Object {
    $parts = [Regex]::Matches($_,'("([^"]|"")*"|[^,]*)') | ForEach-Object {$_.Value.Trim(',').Trim()}
    [pscustomobject]@{ timestamp=$parts[0]; user=$parts[1]; action=$parts[2].Trim('"'); detail=$parts[3].Trim('"') }
  }
}
function Read-LogTail {
  if(-not (Test-Path $Logs)){ return "No logs." }
  $lf = Get-ChildItem $Logs -File | Sort-Object LastWriteTime -Desc | Select-Object -First 1
  if(-not $lf){ return "No logs." }
  (Get-Content -LiteralPath $lf.FullName -Tail 250) -join "`r`n"
}
$AuditList.ItemsSource = Read-Audit()
$LogTail.Text = Read-LogTail()
$win.ShowDialog()|Out-Null
