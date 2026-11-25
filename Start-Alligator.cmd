@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Alligator.ps1" %*
if errorlevel 1 (
  echo.
  echo Alligator stopped. See the message above.
  pause
  exit /b 1
)
