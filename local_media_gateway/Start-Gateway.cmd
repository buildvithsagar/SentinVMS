@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Gateway.ps1" %*
exit /b %errorlevel%
