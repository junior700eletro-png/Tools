# Adapta ONE - Script de Inicialização
# Executa servidor HTTP, backend Flask e abre a interface

Write-Host "`n" -ForegroundColor Green
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║          🧠 ADAPTA ONE - INTERFACE MULTIMODAL 🧠           ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "`n"

# Verifica Python
Write-Host "Verificando Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Python detectado: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRO: Python não encontrado!" -ForegroundColor Red
    Write-Host "Instale em: https://www.python.org/downloads/" -ForegroundColor Red
    Read-Host "Pressione Enter para sair"
    exit
}

# Verifica Flask
Write-Host "Verificando Flask..." -ForegroundColor Yellow
try {
    python -c "import flask" 2>&1 | Out-Null
    Write-Host "✓ Flask detectado" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Flask não encontrado. Instalando..." -ForegroundColor Yellow
    pip install flask flask-cors | Out-Null
    Write-Host "✓ Flask instalado" -ForegroundColor Green
}

Write-Host "`n"

# Inicia servidor HTTP
Write-Host "📡 Iniciando servidor HTTP na porta 8000..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; python -m http.server 8000" -WindowStyle Normal

Start-Sleep -Seconds 2

# Inicia backend Flask
Write-Host "🚀 Iniciando backend Flask na porta 5000..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; python backend.py" -WindowStyle Normal

Start-Sleep -Seconds 3

# Abre navegador
Write-Host "🌐 Abrindo navegador..." -ForegroundColor Cyan
Start-Sleep -Seconds 2
Start-Process "http://localhost:8000/index.html"

Write-Host "`n"
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║  ✓ Sistema iniciado com sucesso!                           ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║  📡 Servidor HTTP: http://localhost:8000                   ║" -ForegroundColor Green
Write-Host "║  🚀 Backend Flask: http://localhost:5000                   ║" -ForegroundColor Green
Write-Host "║  🌐 Interface: http://localhost:8000/index.html            ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║  Feche estas janelas para parar o sistema.                 ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "`n"

Read-Host "Pressione Enter para continuar"