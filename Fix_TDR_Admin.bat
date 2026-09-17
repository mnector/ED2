@echo off
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process -FilePath '%0' -Verb RunAs"
    exit /b
)

echo.
echo Ejecutando Setup.TDRFix.ps1 con permisos de Administrador...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Setup.TDRFix.ps1"
echo.
echo Finalizado. Presiona cualquier tecla para salir...
pause >nul
