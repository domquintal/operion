@{
  Pin                  = '0000'                           # string
  LogsPath             = '..\_logs'                       # relative to ops\
  LauncherPath         = '..\run.ps1'                     # prefer a direct path; fallback logic if missing
  EnableDangerButtons  = $false                           # show force sync buttons only after PIN + this = $true
}
