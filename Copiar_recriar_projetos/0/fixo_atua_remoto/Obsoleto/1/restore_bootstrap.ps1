# ============================================================================
# RESTORE - Restauração Genérica de Projeto a partir de Bootstrap JSON
# ============================================================================
# Versão: 3.0 (COM CORREÇÃO DE REGEX E SISTEMA DE LOG)
# ============================================================================

param(
    [string]$BootstrapRoot = "C:\Users\user\AppData\Local\estruturas_JSON",
    [string]$LogRoot = "C:\Users\user\AppData\Local\estruturas_JSON\logs"
)

# ============================================================================
# INICIALIZAÇÃO DE LOG
# ============================================================================

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $LogRoot "restore_$timestamp.log"

# Criar pasta de logs se não existir
if (-not (Test-Path $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}

# Função para escrever no log
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

Write-Log "=== INICIANDO RESTAURAÇÃO ===" "INFO"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

function Select-RestoreFolder {
    param(
        [string]$Description = "Selecione a pasta onde o projeto será restaurado",
        [string]$InitialPath = [Environment]::GetFolderPath('Desktop')
    )
    
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = $Description
    $FolderBrowser.SelectedPath = $InitialPath
    
    if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $FolderBrowser.SelectedPath
    }
    return $null
}

function Show-BootstrapMenu {
    param([string]$BootstrapRoot)
    
    $bootstrapFiles = @()
    if (Test-Path $BootstrapRoot) {
        $bootstrapFiles = Get-ChildItem -Path $BootstrapRoot -Filter "bootstrap_*.json" -File | 
                         Sort-Object -Property LastWriteTime -Descending
    }
    
    if ($bootstrapFiles.Count -eq 0) {
        Write-Log "Nenhum arquivo bootstrap encontrado em: $BootstrapRoot" "ERROR"
        return $null
    }
    
    Write-Host "`n📋 ARQUIVOS BOOTSTRAP DISPONÍVEIS:`n" -ForegroundColor Cyan
    for ($i = 0; $i -lt $bootstrapFiles.Count; $i++) {
        $file = $bootstrapFiles[$i]
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $date = $file.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
        Write-Host "  [$($i+1)] $($file.Name) ($sizeMB MB) - $date"
    }
    
    Write-Host "`nPressione ENTER sem digitar nada para cancelar."
    $choice = Read-Host "Escolha uma opcao (numero)"
    
    if ([string]::IsNullOrWhiteSpace($choice)) {
        Write-Log "Operação cancelada pelo usuário" "WARN"
        return $null
    }
    
    if ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $bootstrapFiles.Count) {
        $selectedFile = $bootstrapFiles[$choice - 1].FullName
        Write-Log "Arquivo selecionado: $selectedFile" "INFO"
        return $selectedFile
    }
    
    Write-Log "Opção inválida selecionada: $choice" "ERROR"
    return $null
}

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

Write-Host "`n" + ("="*70) -ForegroundColor Cyan
Write-Host "RESTORE - Restauração Genérica de Projeto" -ForegroundColor Cyan
Write-Host ("="*70) + "`n" -ForegroundColor Cyan

# Passo 1: Selecionar arquivo bootstrap
$jsonFile = Show-BootstrapMenu -BootstrapRoot $BootstrapRoot
if ($null -eq $jsonFile) {
    Write-Log "Nenhum arquivo selecionado. Encerrando." "WARN"
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit
}

# Passo 2: Ler e parsear JSON
Write-Host "📖 Lendo arquivo bootstrap..." -ForegroundColor Yellow
Write-Log "Iniciando leitura do arquivo: $jsonFile" "INFO"

try {
    $json = Get-Content -Path $jsonFile -Raw -ErrorAction Stop
    Write-Log "Arquivo lido com sucesso (tamanho: $($json.Length) bytes)" "INFO"
    
    # ⭐ CORREÇÃO CRÍTICA: Substituir caminho Windows mantendo quebras de linha
    # Converter TODAS as barras invertidas para forward slashes
    $json = $json -replace '\\(?![\\"/bfnrtu])', '/'
    Write-Log "Barras invertidas convertidas para forward slashes" "INFO"
    
    # Parsear JSON
    $projectData = ConvertFrom-Json $json -ErrorAction Stop
    Write-Log "JSON parseado com sucesso" "INFO"
    
    Write-Host "✅ Arquivo lido com sucesso." -ForegroundColor Green
    Write-Host "   Projeto: $($projectData.metadata.project_name)" -ForegroundColor Green
    Write-Host "   Versão: $($projectData.metadata.version)" -ForegroundColor Green
    Write-Host "   Arquivos: $($projectData.metadata.total_files)" -ForegroundColor Green
    
    Write-Log "Projeto: $($projectData.metadata.project_name)" "INFO"
    Write-Log "Versão: $($projectData.metadata.version)" "INFO"
    Write-Log "Total de arquivos: $($projectData.metadata.total_files)" "INFO"
}
catch {
    Write-Host "❌ ERRO ao ler arquivo bootstrap: $_" -ForegroundColor Red
    Write-Log "ERRO ao ler arquivo: $_" "ERROR"
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit
}

# Passo 3: Selecionar pasta de destino
Write-Host "`n📁 Selecione a pasta onde o projeto será restaurado (dialogo grafico)..." -ForegroundColor Yellow
$restoreRoot = Select-RestoreFolder
if ($null -eq $restoreRoot) {
    Write-Log "Operação cancelada na seleção da pasta de destino" "WARN"
    Write-Host "❌ Operacao cancelada pelo usuario na selecao da pasta de destino." -ForegroundColor Yellow
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit
}

Write-Log "Pasta de destino selecionada: $restoreRoot" "INFO"

# Passo 4: Criar pasta principal do projeto
$projectFolder = Join-Path $restoreRoot "$($projectData.metadata.project_name)_$timestamp"

Write-Host "`n📂 Criando estrutura de pastas..." -ForegroundColor Yellow
Write-Log "Criando estrutura de pastas em: $projectFolder" "INFO"

$folderCount = 0
try {
    # Criar pasta raiz do projeto
    if (-not (Test-Path $projectFolder)) {
        New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null
        $folderCount++
    }
    
    # Criar todas as pastas da estrutura
    foreach ($folder in $projectData.structure.folders) {
        $folderPath = Join-Path $projectFolder $folder
        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
            $folderCount++
        }
    }
    
    Write-Host "✅ Pastas criadas com sucesso ($folderCount pastas)." -ForegroundColor Green
    Write-Log "Pastas criadas: $folderCount" "INFO"
}
catch {
    Write-Host "❌ ERRO ao criar pastas: $_" -ForegroundColor Red
    Write-Log "ERRO ao criar pastas: $_" "ERROR"
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit
}

# Passo 5: Escrever arquivos
Write-Host "`n📝 Escrevendo arquivos..." -ForegroundColor Yellow
Write-Log "Iniciando escrita de arquivos" "INFO"

$fileCount = 0
$errorCount = 0

try {
    foreach ($file in $projectData.structure.files) {
        $filePath = Join-Path $projectFolder $file.path
        
        try {
            # Garantir que o diretório existe
            $fileDir = Split-Path -Parent $filePath
            if (-not (Test-Path $fileDir)) {
                New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            }
            
            # Escrever arquivo com encoding UTF-8
            $file.content | Out-File -FilePath $filePath -Encoding UTF8 -Force
            $fileCount++
        }
        catch {
            Write-Log "ERRO ao escrever arquivo $($file.path): $_" "ERROR"
            $errorCount++
        }
    }
    
    Write-Host "✅ Todos os arquivos foram restaurados com sucesso ($fileCount arquivos)." -ForegroundColor Green
    Write-Log "Arquivos restaurados: $fileCount" "INFO"
    
    if ($errorCount -gt 0) {
        Write-Log "Erros durante escrita de arquivos: $errorCount" "WARN"
    }
}
catch {
    Write-Host "❌ ERRO durante escrita de arquivos: $_" -ForegroundColor Red
    Write-Log "ERRO geral durante escrita: $_" "ERROR"
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit
}

# Passo 6: Exibir resumo final
Write-Host "`n" + ("="*70) -ForegroundColor Green
Write-Host "✅ RESTAURAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
Write-Host ("="*70) -ForegroundColor Green
Write-Host "`n📊 RESUMO:" -ForegroundColor Cyan
Write-Host "   Projeto: $($projectData.metadata.project_name)" -ForegroundColor White
Write-Host "   Versão: $($projectData.metadata.version)" -ForegroundColor White
Write-Host "   Pasta de destino: $projectFolder" -ForegroundColor White
Write-Host "   Pastas criadas: $folderCount" -ForegroundColor White
Write-Host "   Arquivos restaurados: $fileCount" -ForegroundColor White
Write-Host "   Arquivo de log: $logFile" -ForegroundColor White
Write-Host "`n"

Write-Log "=== RESTAURAÇÃO CONCLUÍDA ===" "INFO"
Write-Log "Resumo final - Pastas: $folderCount, Arquivos: $fileCount, Erros: $errorCount" "INFO"

Write-Host "Pressione ENTER para sair..."
Read-Host