@echo off
setlocal EnableDelayedExpansion
title Restaurar Valores TDR de Windows (ED2)

:: Solicitar permisos de Administrador sin archivos temporales VBScript
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo =======================================================
echo   Restaurar TDR (Timeout Detection and Recovery)
echo =======================================================
echo.
echo Eliminando claves TDR personalizadas en:
echo   HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers
echo.

set "REG_KEY=HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
for %%V in (TdrDelay TdrDdiDelay TdrLimitCount TdrLimitTime TdrLevel) do (
    reg query "%REG_KEY%" /v "%%V" >nul 2>&1
    if !errorlevel! equ 0 (
        reg delete "%REG_KEY%" /v "%%V" /f >nul 2>&1
        if !errorlevel! equ 0 (
            echo [OK] Eliminado: %%V
        ) else (
            echo [ERROR] No se pudo eliminar: %%V
        )
    ) else (
        echo [--] Ya estaba en valor por defecto: %%V
    )
)

echo.
echo Listo. Si se elimino alguna clave, reinicia Windows para aplicar los valores por defecto.
echo Presiona cualquier tecla para salir...
pause >nul
