@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title NEXUS v2.0 - Safe Beast Windows Optimization Tool
color 0b

:MENU
cls
echo.
echo     NN    NN  EEEEEEE  XX    XX  UU    UU  SSSSSSS
echo     NNN   NN  EE        XX  XX   UU    UU  SS
echo     NN N  NN  EEEEE      XXXX    UU    UU  SSSSSSS
echo     NN  N NN  EE        XX  XX   UU    UU       SS
echo     NN   NNN  EEEEEEE  XX    XX  UUUUUU   SSSSSSS
echo.
echo     NETWORK - ENGINE - XTREME - UNIFIED - SYSTEM
echo     v2.0 ^| Safe Beast Mode ^| No personal files touched
echo.
echo   [1] DEEP SCAN       - Full system analysis + bottleneck report + score
echo   [2] POWER BOOST     - Cache purge + RAM optimizer + FPS mode + repair
echo   [3] NET BOOST       - TCP tuning + DNS optimize + adapter tune + ping test
echo   [4] RAM BOOST       - Dedicated RAM optimizer (WorkingSet + Standby flush)
echo   [5] STARTUP MGR     - View and selectively disable startup programs
echo   [0] EXIT
echo.

set /p choice="Select an option [0-5]: "

if "%choice%"=="1" goto RUN_SCAN
if "%choice%"=="2" goto RUN_POWER
if "%choice%"=="3" goto RUN_NET
if "%choice%"=="4" goto RUN_RAM
if "%choice%"=="5" goto RUN_STARTUP
if "%choice%"=="0" exit /b 0

goto MENU

:RUN_SCAN
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\NEXUS.ps1" -Mode Scan -Interactive
pause
goto MENU

:RUN_POWER
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\NEXUS.ps1" -Mode Optimize -Interactive
pause
goto MENU

:RUN_NET
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\NEXUS.ps1" -Mode Network -Interactive
pause
goto MENU

:RUN_RAM
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\NEXUS.ps1" -Mode RAM -Interactive
pause
goto MENU

:RUN_STARTUP
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\NEXUS.ps1" -Mode Startup -Interactive
pause
goto MENU
