@echo off
echo ========================================
echo   Git Add/Commit/Push Automatico
echo ========================================
echo.

cd /d "%~dp0..\.."

echo Repositorio: %CD%
echo.

echo Verificando .gitignore...
if not exist .gitignore (
    echo Criando .gitignore...
    (
    echo .tmp.driveupload/
    echo *.pyc
    echo __pycache__/
    echo .venv/
    echo venv/
    echo env/
    echo *.log
    echo .DS_Store
    echo Thumbs.db
    echo desktop.ini
    echo *.tmp
    echo *.temp
    echo .cache/
    echo node_modules/
    ) > .gitignore
)

echo.
echo Arquivos modificados/novos:
echo ----------------------------------------
git status --short
echo ----------------------------------------
echo.

set /p CONFIRMA="Continuar com add/commit/push? (S/n): "
if /i "%CONFIRMA%"=="n" (
    echo Cancelado.
    pause
    exit /b 0
)

echo.
echo Executando git add...
git add .

echo.
set /p MSG="Mensagem de commit (ENTER = 'Atualizar repositorio'): "
if "%MSG%"=="" set MSG=Atualizar repositorio

echo.
echo Criando commit...
git commit -m "%MSG%"

echo.
echo Fazendo push...
git push origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo   SUCESSO!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo   ERRO no push
    echo ========================================
)

pause