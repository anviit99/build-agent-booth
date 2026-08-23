@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-startup-task.ps1"
if errorlevel 1 (
  echo.
  echo Khong cai duoc scheduled task.
  pause
  exit /b 1
)
echo.
echo Da cai: tu dong chay khi dang nhap Windows va mo khoa man hinh.
pause
