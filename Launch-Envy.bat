@echo off
setlocal
title Envy-Diamond Launcher
echo ===================================================
echo     Envy-Diamond Dynamic Pacing Launcher
echo ===================================================

if not exist "OptiScaler.ini" (
    echo Error: OptiScaler.ini not found. 
    echo Please run Setup.bat to install Envy-Diamond, or place this batch file in your game directory.
    pause
    exit /b
)

echo Starting Dynamic Pacing Daemon...
start "Envy-Diamond Daemon" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EnvyDynamicPacing.ps1"

echo.
echo The daemon is now running in a separate window.
echo Launch your game normally!
echo When you are finished playing, simply close the daemon window.
echo.
pause
