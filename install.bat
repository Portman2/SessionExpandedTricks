@echo off
rem Expanded Tricks -- install. Double-click this file.
if exist "%~dp0tools\install.ps1" goto run
echo.
echo   The rest of the download is not beside this file: tools\install.ps1 is missing.
echo   Unzip the WHOLE download first: right-click the zip, choose Extract All,
echo   then run install.bat from the unzipped folder.
echo.
pause
exit /b 1
:run
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install.ps1" %*
