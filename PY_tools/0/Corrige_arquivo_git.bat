@echo off
REM === Configuracoes ===

REM Caminho para o Python (ajuste se necessario: python, py, etc.)
set PYTHON_EXEC=python

REM Diretorio base do repositorio clonado
set BASE_DIR=C:\Users\user\Desktop\Tools

REM Caminho para o script Python
set SCRIPT_PATH=%BASE_DIR%\PY_tools\0\substituir_clipboard_git.py

echo.
echo Verificando/instalando dependencias (pyperclip e gitpython)...
%PYTHON_EXEC% -m pip install --quiet pyperclip gitpython

echo.
echo Iniciando script Python...

REM Tentar rodar o script.
REM Se der erro de Tkinter ausente, vamos mostrar uma mensagem amigavel.
%PYTHON_EXEC% "%SCRIPT_PATH%" "%BASE_DIR%"
if errorlevel 1 (
    echo.
    echo Se ocorreu erro relacionado a 'tkinter' ou 'tk', isso significa que
    echo sua instalacao do Python nao inclui o modulo Tkinter (Tcl/Tk).
    echo Nesse caso, reinstale o Python pelo instalador oficial do python.org
    echo certificando-se de marcar a opcao de instalar Tcl/Tk (Tkinter).
)

echo.
pause