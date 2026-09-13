@echo off
setlocal enabledelayedexpansion
title Envy-Diamond Variable Launcher
echo ===================================================
echo     Envy-Diamond Variable FPS Launcher
echo ===================================================

:: ==========================================
:: CONFIGURACION FACIL
:: Cambia estos numeros segun tus necesidades:

:: 1. La frecuencia real de tu monitor principal (Hz)
set MONITOR_HZ=138

:: 2. El porcentaje que quieres utilizar (ejemplo: 25, 50, 75)
set PERCENT=25

:: 3. Multiplicador de Frame Generation (2 = Doble FPS, 3 = Triple)
:: Si no usas Frame Gen en el juego, dejalo en 1.
:: OptiScaler duplica los FPS base, por lo que el script dividira
:: el limite para que tus FPS en pantalla sean exactamente los deseados.
set FG_MULTIPLIER=2
:: ==========================================

if not exist "OptiScaler.ini" (
    echo Error: OptiScaler.ini no encontrado.
    pause
    exit /b
)

:: Calcular FPS Objetivo Final (Salida en pantalla)
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "[math]::Round(%MONITOR_HZ% * %PERCENT% / 100)"`) do set TARGET_OUTPUT_FPS=%%A

:: Calcular FPS Base (Reflex Input Limit) para OptiScaler
for /f "usebackq delims=" %%B in (`powershell -NoProfile -Command "[math]::Round(%TARGET_OUTPUT_FPS% / %FG_MULTIPLIER%)"`) do set TARGET_INPUT_FPS=%%B

echo Frecuencia de pantalla manual  : %MONITOR_HZ% Hz
echo Porcentaje objetivo            : %PERCENT%%%
echo Multiplicador de Frame Gen     : %FG_MULTIPLIER%x
echo.
echo FPS de Salida (Final en juego) : %TARGET_OUTPUT_FPS% FPS
echo FPS de Entrada (Limite Reflex) : %TARGET_INPUT_FPS% FPS

:: Actualizar OptiScaler.ini usando PowerShell
powershell -NoProfile -Command "$c = Get-Content 'OptiScaler.ini'; $r = $false; for ($i=0; $i -lt $c.Length; $i++) { if ($c[$i] -match '^FramerateLimit=') { $c[$i] = 'FramerateLimit=%TARGET_INPUT_FPS%'; $r = $true } }; if (-not $r) { $c += '[Framerate]'; $c += 'FramerateLimit=%TARGET_INPUT_FPS%' }; $c | Set-Content 'OptiScaler.ini'"

echo.
echo OptiScaler.ini actualizado con exito.
echo Ya puedes abrir el juego normalmente (No lances el daemon).
echo.
pause
