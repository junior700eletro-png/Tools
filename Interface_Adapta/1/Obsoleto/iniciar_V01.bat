@echo off
chcp 65001 >nul
title Adapta ONE - Sistema Multimodal
color 0A

REM Define o diretório correto
cd /d "%~dp0"

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║          🧠 ADAPTA ONE - INTERFACE MULTIMODAL 🧠           ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo 📁 Diretório: %cd%
echo.

REM Verifica se Python está instalado
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERRO: Python não encontrado!
    echo Instale Python em: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo ✓ Python detectado
echo.

REM Verifica se Flask está instalado
python -c "import flask" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Flask não encontrado. Instalando...
    pip install flask flask-cors >nul 2>&1
    if errorlevel 1 (
        echo ❌ Erro ao instalar Flask
        pause
        exit /b 1
    )
    echo ✓ Flask instalado com sucesso
)

echo ✓ Flask detectado
echo.

REM Verifica se backend.py existe
if not exist "backend.py" (
    echo ❌ ERRO: backend.py não encontrado!
    echo Certifique-se de que backend.py está em: %cd%
    pause
    exit /b 1
)

echo ✓ backend.py encontrado
echo.

REM Inicia o servidor HTTP
echo 📡 Iniciando servidor HTTP na porta 8000...
start "Servidor HTTP (8000)" cmd /k "cd /d "%~dp0" && python -m http.server 8000"
timeout /t 2 >nul

REM Inicia o backend Flask
echo 🚀 Iniciando backend Flask na porta 5000...
start "Backend Flask (5000)" cmd /k "cd /d "%~dp0" && python backend.py"
timeout /t 3 >nul

REM Abre o navegador
echo 🌐 Abrindo navegador...
timeout /t 2 >nul
start http://localhost:8000/index.html

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║  ✓ Sistema iniciado com sucesso!                           ║
echo ║                                                            ║
echo ║  📡 Servidor HTTP: http://localhost:8000                   ║
echo ║  🚀 Backend Flask: http://localhost:5000                   ║
echo ║  🌐 Interface: http://localhost:8000/index.html            ║
echo ║                                                            ║
echo ║  Feche estas janelas para parar o sistema.                 ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

pause