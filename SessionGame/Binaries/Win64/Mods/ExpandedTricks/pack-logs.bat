@echo off
rem Expanded Tricks -- pack the logs for a bug report. Double-click this file; the zip lands on your desktop.
if exist "%~dp0pack-logs.ps1" goto run
echo.
echo   pack-logs.ps1 is not beside this file. Run pack-logs.bat from the game's
echo   SessionGame\Binaries\Win64\Mods\ExpandedTricks folder, not from inside the zip.
echo.
pause
exit /b 1
:run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack-logs.ps1" %*
