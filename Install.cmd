@echo off
set "PSModulePath="
set "installerShell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "installerShell=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%installerShell%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
set "result=%errorlevel%"
pause
exit /b %result%
