@echo off
chcp 65001 >nul
title Adapta ONE - Master Launcher
color 0A

cd /d "%~dp0"

echo.
echo ============================================================
echo.
echo        ADAPTA ONE - MASTER LAUNCHER
echo.
echo ============================================================
echo.

echo Iniciando 3 sistemas em paralelo...
echo.

echo [1/3] Iniciando Interface Adapta ONE...
start "Interface Adapta ONE" cmd /k python backend.py

timeout /t 2 /nobreak

echo [2/3] Iniciando Communication System...
start "Communication System" cmd /k cd comunication_system && python src/main_orchestrator.py

timeout /t 2 /nobreak

echo [3/3] Abrindo navegador...
timeout /t 3 /nobreak
start http://localhost:8000

echo.
echo ============================================================
echo OK - Todos os sistemas iniciados!
echo ============================================================
echo.
echo Janelas abertas:
echo   1. Interface Adapta ONE (localhost:8000)
echo   2. Communication System (monitoramento)
echo   3. Navegador (http://localhost:8000)
echo.
echo Para parar tudo, feche as janelas de terminal.
echo.
pause