@echo off
set "PSModulePath="
set "systemBin=%SystemRoot%\System32"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "systemBin=%SystemRoot%\Sysnative"
set "installerShell=%systemBin%\WindowsPowerShell\v1.0\powershell.exe"
call :checkShell
if errorlevel 1 (
    call :preparePortable
    if errorlevel 1 goto :failed
)
"%installerShell%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
set "result=%errorlevel%"
pause
exit /b %result%

:checkShell
"%installerShell%" -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $env:PSModulePath=[IO.Path]::Combine($PSHOME,'Modules'); if($PSVersionTable.PSVersion.PreReleaseLabel){exit 1}; try { 1,2 | Select-Object -First 1 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>&1
exit /b %errorlevel%

:preparePortable
set "portable=%LOCALAPPDATA%\Minecraft X Half-Life\tools\pwsh-7.6.6"
set "installerShell=%portable%\pwsh.exe"
if exist "%installerShell%" (
    call :checkShell
    if not errorlevel 1 exit /b 0
)
echo Downloading stable PowerShell 7.6.6 for this installer...
mkdir "%portable%" 2>nul
set "archive=%portable%\powershell.zip"
"%systemBin%\curl.exe" --fail --location --retry 2 --output "%archive%" "https://github.com/PowerShell/PowerShell/releases/download/v7.6.6/PowerShell-7.6.6-win-x64.zip"
if errorlevel 1 exit /b 1
"%systemBin%\certutil.exe" -hashfile "%archive%" SHA256 | "%systemBin%\findstr.exe" /i /x "02fe458be20493fbdf43f61ea20610b811ee6c738ab1676c61b9cfcd1a33c860" >nul
if errorlevel 1 exit /b 1
"%systemBin%\tar.exe" -xf "%archive%" -C "%portable%"
if errorlevel 1 exit /b 1
call :checkShell
exit /b %errorlevel%

:failed
echo Could not prepare a working PowerShell runtime for the installer.
pause
exit /b 1
