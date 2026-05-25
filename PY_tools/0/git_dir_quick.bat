@echo off
REM === Configuracoes ===

REM Caminho para o Python (ajuste se necessario: python, py, etc.)
set PYTHON_EXEC=python

REM Diretorio base do repositorio clonado
set BASE_DIR=C:\Users\user\Desktop\Tools\

REM Caminho para o script Python
set SCRIPT_PATH=%BASE_DIR%\PY_tools\0\git_dir_quick.py

echo.
echo Verificando/instalando dependencia gitpython...
%PYTHON_EXEC% -m pip install --quiet gitpython

echo.
echo Iniciando script Python para 'gitar' diretorio...
REM Sem arg 2 -> script pergunta o diretorio
%PYTHON_EXEC% "%SCRIPT_PATH%" "%BASE_DIR%"

REM Se quiser ja fixar um diretorio especifico, use:
REM %PYTHON_EXEC% "%SCRIPT_PATH%" "%BASE_DIR%" "tools"

echo.
pause