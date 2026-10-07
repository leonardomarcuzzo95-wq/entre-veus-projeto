@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0jogo\infra\Launch.ps1" -Action Play
if errorlevel 1 pause
