@echo off
REM HDMI + X Acquire booth agent (AUTODELETE variant)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-agent.ps1"
if errorlevel 1 pause
