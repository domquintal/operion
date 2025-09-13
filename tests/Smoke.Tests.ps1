BeforeAll {
  Set-Location 'C:\Users\Domin\Operion'
}
Describe 'Config Loader' {
  It 'loads config without error' {
    . 'C:\Users\Domin\Operion\ops\lib\config.ps1'
    { Get-OperionConfig -OpsDir 'C:\Users\Domin\Operion\ops' } | Should -Not -Throw
  }
}
