# restore_bootstrap_v5_modified.ps1
# Restauração de Projeto - SEM MODIFICAR BARRAS (JSON já está correto)
# Versão: 1.2 - 2026-05-19 (Windows Forms para escolher arquivo e pasta de destino)

param(
    [string]$JsonPath = "",
    [string]$SourceRoot = "C:\\Users\\user\\AppData\\Local\\estruturas_JSON",
    [string]$DestinationRoot = ""
)

# ==================== INICIALIZAÇÃO ====================
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = Join-Path $SourceRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "restore_$timestamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
    $color = switch($Level) {
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default   { "White" }
    }
    Write-Host $entry -ForegroundColor $color
}

# ==================== VALIDAR JSON ====================
function Validate-JsonContent {
    param([string]$JsonContent)
    Write-Log "Validando JSON..." "INFO"
    try {
        $json = $JsonContent | ConvertFrom-Json -ErrorAction Stop
        Write-Log "✓ JSON válido" "SUCCESS"
        return $json
    } catch {
        Write-Log "✗ Erro ao parsear JSON: $($_.Exception.Message)" "ERROR"
        Write-Host "❌ Erro: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ==================== RESTAURAR PROJETO ====================
function Restore-ProjectStructure {
    param([object]$ProjectData, [string]$DestinationRoot, [string]$SourceRoot)

    $projectName = $ProjectData.metadata.project_name
    $projectFolder = Join-Path $DestinationRoot "$projectName`_$timestamp"

    Write-Log "Criando pasta do projeto: $projectFolder" "INFO"
    New-Item -ItemType Directory -Path $projectFolder -Force | Out-Null

    $folderCount = 0
    $fileCount = 0
    $errorCount = 0

    # Criar pastas
    Write-Log "Criando estrutura de pastas..." "INFO"
    foreach ($folder in $ProjectData.structure.folders) {
        $folderPath = Join-Path $projectFolder $folder
        try {
            New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
            $folderCount++
            Write-Log "✓ Pasta: $folder" "DEBUG"
        } catch {
            Write-Log "✗ Erro ao criar pasta $folder : $($_.Exception.Message)" "ERROR"
            $errorCount++
        }
    }

    # Criar arquivos
    Write-Log "Restaurando arquivos..." "INFO"
    foreach ($file in $ProjectData.structure.files) {
        $filePath = Join-Path $projectFolder $file.path
        $fileDir = Split-Path $filePath

        try {
            if (-not (Test-Path $fileDir)) {
                New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            }

            [System.IO.File]::WriteAllText($filePath, $file.content, [System.Text.Encoding]::UTF8)
            $fileCount++
            Write-Log "✓ Arquivo: $($file.path)" "DEBUG"
        } catch {
            Write-Log "✗ Erro ao criar arquivo $($file.path) : $($_.Exception.Message)" "ERROR"
            $errorCount++
        }
    }

    # Resumo
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          📊 RESUMO DA RESTAURAÇÃO      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "Projeto: $projectName" -ForegroundColor Green
    Write-Host "Versão: $($ProjectData.metadata.version)" -ForegroundColor Green
    Write-Host "Pastas criadas: $folderCount" -ForegroundColor Green
    Write-Host "Arquivos restaurados: $fileCount" -ForegroundColor Green
    Write-Host "Erros: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Destino: $projectFolder" -ForegroundColor Green
    Write-Host "Log: $logFile" -ForegroundColor Gray

    Write-Log "Restauração concluída. Pastas: $folderCount, Arquivos: $fileCount, Erros: $errorCount" "SUCCESS"
}

# ==================== FLUXO PRINCIPAL ====================
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RESTORE - Bootstrap JSON Restaurador  ║" -ForegroundColor Cyan
Write-Host "║  (SEM MODIFICAR BARRAS INVERTIDAS)     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

# Garantir que SourceRoot existe
if (-not (Test-Path $SourceRoot)) {
    Write-Log "SourceRoot não existe. Criando: $SourceRoot" "WARNING"
    try {
        New-Item -ItemType Directory -Path $SourceRoot -Force | Out-Null
        Write-Log "Criado SourceRoot: $SourceRoot" "INFO"
    } catch {
        Write-Log "Falha ao criar SourceRoot $SourceRoot : $($_.Exception.Message)" "ERROR"
        Write-Host "❌ Não foi possível criar SourceRoot: $SourceRoot" -ForegroundColor Red
        exit 1
    }
}

Write-Log "Pasta de origem fixa: $SourceRoot" "INFO"

# ---------- USAR WINDOWS FORMS PARA SELEÇÃO DO ARQUIVO E DESTINO ----------
$guiOk = $true
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    # OpenFileDialog para selecionar JSON (inicia em SourceRoot)
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.InitialDirectory = $SourceRoot
    $ofd.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    $ofd.Multiselect = $false
    $ofd.Title = "Selecione o arquivo JSON do projeto"

    if ($JsonPath -and (Test-Path $JsonPath)) {
        Write-Log "JsonPath fornecido por parâmetro e válido: $JsonPath" "INFO"
    } else {
        if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $JsonPath = $ofd.FileName
            Write-Log "Arquivo selecionado via OpenFileDialog: $JsonPath" "INFO"
        } else {
            Write-Log "Seleção de arquivo cancelada pelo usuário." "WARNING"
            Write-Host "Operação cancelada." -ForegroundColor Yellow
            exit 1
        }
    }

    # FolderBrowserDialog para selecionar pasta de destino (inicia em C:\Users\user)
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.SelectedPath = "C:\\Users\\user"
    $fbd.Description = "Escolha a pasta de destino para restaurar o projeto"
    if ($DestinationRoot -and (Test-Path $DestinationRoot)) {
        Write-Log "DestinationRoot fornecido por parâmetro e válido: $DestinationRoot" "INFO"
    } else {
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $DestinationRoot = $fbd.SelectedPath
            Write-Log "Destino selecionado via FolderBrowserDialog: $DestinationRoot" "INFO"
        } else {
            Write-Log "Seleção de pasta de destino cancelada pelo usuário." "WARNING"
            Write-Host "Operação cancelada." -ForegroundColor Yellow
            exit 1
        }
    }
} catch {
    # Modo console de fallback
    $guiOk = $false
    Write-Log "Falha ao usar Windows Forms: $($_.Exception.Message)" "WARNING"
    Write-Host "Não foi possível abrir a interface gráfica. Entrando em modo console..." -ForegroundColor Yellow

    if (-not $JsonPath) {
        $JsonPath = Read-Host "Caminho do arquivo JSON (inicie em $SourceRoot)"
    }

    if (-not $DestinationRoot) {
        $DestinationRoot = Read-Host "Caminho da pasta de destino (ex: C:\\Users\\user)"
    }
}

# Validar JsonPath e DestinationRoot
if (-not (Test-Path $JsonPath)) {
    Write-Log "Arquivo não encontrado: $JsonPath" "ERROR"
    Write-Host "❌ Arquivo não encontrado: $JsonPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DestinationRoot)) {
    Write-Log "Destino não existe, criando: $DestinationRoot" "WARNING"
    try {
        New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    } catch {
        Write-Log "Falha ao criar destino $DestinationRoot : $($_.Exception.Message)" "ERROR"
        Write-Host "❌ Não foi possível criar a pasta de destino." -ForegroundColor Red
        exit 1
    }
}

Write-Log "Lendo arquivo: $JsonPath" "INFO"
$jsonContent = Get-Content -Path $JsonPath -Raw -Encoding UTF8
Write-Log "Tamanho do arquivo: $($jsonContent.Length) caracteres" "INFO"

$projectData = Validate-JsonContent -JsonContent $jsonContent

if ($projectData) {
    Restore-ProjectStructure -ProjectData $projectData -DestinationRoot $DestinationRoot -SourceRoot $SourceRoot
    Write-Host "`n✓ Script finalizado com sucesso.`n" -ForegroundColor Green
} else {
    Write-Log "Falha na validação do JSON. Abortando." "ERROR"
    Write-Host "`n❌ Falha na validação. Verifique o arquivo JSON.`n" -ForegroundColor Red
    exit 1
}