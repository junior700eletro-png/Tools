@echo off
REM === Configuracoes ===

REM Caminho para o Python (ajuste se necessario: python, py, etc.)
set PYTHON_EXEC=python

REM Diretorio base do repositorio clonado
set BASE_DIR=C:\Users\user\Desktop\Tools

REM Caminho para o script Python
set SCRIPT_PATH=%BASE_DIR%\PY_tools\0\git_dir_quick.py

echo.
echo Verificando/instalando dependencia gitpython...
%PYTHON_EXEC% -m pip install --quiet gitpython

echo.
echo Criando/atualizando .gitignore...
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
) > "%BASE_DIR%\.gitignore"

echo.
echo Iniciando script Python para 'gitar' diretorio...
echo Executando: %PYTHON_EXEC% "%SCRIPT_PATH%" "%BASE_DIR%"
echo.

REM Executar e mostrar erro se houver
%PYTHON_EXEC% "%SCRIPT_PATH%" "%BASE_DIR%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERRO: Script Python falhou com codigo %ERRORLEVEL%
    echo Verifique se o Tkinter esta instalado no Python.
    echo.
)

pause