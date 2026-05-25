@echo off
chcp 65001 >nul
title Communication System - Orchestrator
color 0B

cd /d "%~dp0"

echo.
echo ============================================================
echo.
echo        Communication System - Orchestrator
echo.
echo ============================================================
echo.

python --version >nul 2>&1
if errorlevel 1 (
    echo ERRO: Python nao encontrado!
    pause
    exit /b 1
)

echo OK - Python detectado
echo.

if not exist "src" (
    echo Pasta src nao encontrada!
    echo Executando setup...
    
    if not exist "setup_communication_system.ps1" (
        echo ERRO: setup_communication_system.ps1 nao encontrado!
        pause
        exit /b 1
    )
    
    powershell -ExecutionPolicy Bypass -File "setup_communication_system.ps1"
    
    if errorlevel 1 (
        echo Erro ao desempacotar projeto
        pause
        exit /b 1
    )
)

echo OK - Estrutura encontrada
echo.

echo Verificando dependencias Python...
python -c "import pytesseract" >nul 2>&1
if errorlevel 1 (
    echo Instalando pytesseract, pillow, pyautogui...
    pip install pytesseract pillow pyautogui >nul 2>&1
)

echo OK - Dependencias OK
echo.

echo Iniciando Communication System...
echo Aguardando resposta da IA...
echo.

python src/main_orchestrator.py

if errorlevel 1 (
    echo.
    echo Erro ao iniciar sistema
    pause
    exit /b 1
)

pause