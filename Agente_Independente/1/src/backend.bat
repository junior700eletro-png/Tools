REM # start_backend.bat
REM # Tools/Agente_Independente/1/src/start_backend.bat
@echo off
if not exist "C:\Users\user\Desktop\Tools\Agente_Independente\1\src\" (
    echo Error: Directory not found.
    pause
    exit /b 1
)
cd /d "C:\Users\user\Desktop\Tools\Agente_Independente\1\src\"
if exist "venv\Scripts\python.exe" (
    set PYTHON=venv\Scripts\python.exe
) else (
    set PYTHON=python
)
echo Starting FastAPI backend...
%PYTHON% -m uvicorn backend:app --reload
if errorlevel 1 (
    echo An error occurred. Press any key to exit.
    pause
)