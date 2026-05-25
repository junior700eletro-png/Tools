# restore_bootstrap_v3.ps1
# Restauração de Projeto - SEM MODIFICAR BARRAS (JSON já está correto)
# Versão: 1.0 - 2026-05-19

param(
    [string]$JsonPath = "",
    [string]$DestinationRoot = "C:\Users\user\AppData\Local\estruturas_JSON"
)

# ==================== INICIALIZAÇÃO ====================
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = Join-Path $DestinationRoot "logs"
$logFile = Join-Path $logDir "restore_$timestamp.log"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $entry -Encoding UTF8
    $color = switch($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default { "White" }
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
    param([object]$ProjectData, [string]$DestinationRoot)
    
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

if (-not $JsonPath) {
    $JsonPath = Read-Host "Caminho do arquivo JSON"
}

if (-not (Test-Path $JsonPath)) {
    Write-Log "Arquivo não encontrado: $JsonPath" "ERROR"
    Write-Host "❌ Arquivo não encontrado!" -ForegroundColor Red
    exit 1
}

Write-Log "Lendo arquivo: $JsonPath" "INFO"
$jsonContent = Get-Content -Path $JsonPath -Raw -Encoding UTF8

Write-Log "Tamanho do arquivo: $($jsonContent.Length) caracteres" "INFO"

$projectData = Validate-JsonContent -JsonContent $jsonContent

if ($projectData) {
    Restore-ProjectStructure -ProjectData $projectData -DestinationRoot $DestinationRoot
    Write-Host "`n✓ Script finalizado com sucesso.`n" -ForegroundColor Green
} else {
    Write-Log "Falha na validação do JSON. Abortando." "ERROR"
    Write-Host "`n❌ Falha na validação. Verifique o arquivo JSON.`n" -ForegroundColor Red
    exit 1
}