@echo off
set PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0operion_start.ps1"
REM === Operion Control Window ===
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "app\ui\Open_Control.ps1"
