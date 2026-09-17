@echo off
setlocal EnableDelayedExpansion
title Instalador Envy-Diamond-2

:: Check for Admin permissions and self-elevate
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Solicitando permisos de administrador...
    if "%~1" NEQ "" (
        powershell -Command "Start-Process -FilePath '%~f0' -ArgumentList '\"%~1\"' -Verb RunAs"
    ) else (
        powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    )
    exit /b
)

echo =======================================================
echo        Instalador Envy-Diamond-2 (ED2)
echo =======================================================
echo.

set "TARGET_DIR=%~1"

if "%TARGET_DIR%"=="" (
    echo Arrastra la carpeta del juego a esta ventana o escribe la ruta:
    set /p "TARGET_DIR=Ruta del juego: "
)

:: Strip surrounding quotes
set "TARGET_DIR=!TARGET_DIR:"=!"

if "%TARGET_DIR%"=="" (
    echo.
    echo [ERROR] No se ingreso ninguna ruta.
    echo.
    pause
    exit /b 1
)

if not exist "%TARGET_DIR%" (
    echo.
    echo [ERROR] La carpeta especificada no existe: "%TARGET_DIR%"
    echo.
    pause
    exit /b 1
)

echo.
echo Instalando Envy-Diamond-2 en:
echo "!TARGET_DIR!"
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.Install.ps1" -GameDir "!TARGET_DIR!"

echo.
echo =======================================================
echo Proceso finalizado. Presiona cualquier tecla para salir...
echo =======================================================
pause >nul
