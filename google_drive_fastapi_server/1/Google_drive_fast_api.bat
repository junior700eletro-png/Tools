@echo off
REM === Ir para a pasta do projeto ===
cd /d "%~dp0"

echo [1/4] Criando/ativando ambiente virtual...
IF NOT EXIST .venv (
    python -m venv .venv
)

call ".venv\Scripts\activate.bat"

echo [2/4] Atualizando pip...
python -m pip install --upgrade pip

echo [3/4] Instalando dependencias...
IF EXIST requirements.txt (
    pip install -r requirements.txt
) ELSE (
    echo Arquivo requirements.txt nao encontrado. Pulando instalacao...
)

echo [4/4] Executando scripts de criacao do servidor...

REM Exemplo: script de criacao de banco
IF EXIST setup_db.py (
    python setup_db.py
) ELSE (
    echo Script setup_db.py nao encontrado. Pulando...
)

REM Exemplo: script principal do servidor
IF EXIST create_server.py (
    python create_server.py
) ELSE (
    echo Script create_server.py nao encontrado. Ajuste o nome no .bat.
)

echo.
echo Processo concluido. Pressione qualquer tecla para sair.
pause >nul