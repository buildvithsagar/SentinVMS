@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-Gateway.ps1" %*
exit /b %errorlevel%
