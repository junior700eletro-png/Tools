
Add-Type -AssemblyName System.Windows.Forms

function Get-NextBackupName {
    param([string]$baseName, [string]$extension, [string]$directory)
    $counter = 1
    while ($true) {
        $newName = "{0}_V{1:D2}{2}" -f $baseName, $counter, $extension
        $fullPath = Join-Path $directory $newName
        if (-not (Test-Path $fullPath)) {
            return $newName
        }
        $counter++
    }
}

try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "BOOTSTRAP - Adapta ONE Project Capture" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $projectRoot = Get-Location
    Write-Host "Pasta do projeto: $projectRoot" -ForegroundColor Green

    $foldersToCapture = @(
        "src",
        "config",
        "logs",
        "output",
        "comunication_system\src",
        "comunication_system\config",
        "comunication_system\logs",
        "comunication_system\output"
    )

    $filesToCapture = @(
        "backend.py",
        "ai_models.py",
        "index_updated.html",
        "test_system.py",
        "iniciar.bat",
        "master_launcher.bat",
        "README.md",
        "comunication_system\iniciar_communication_system.bat",
        "comunication_system\setup_communication_system.ps1",
        "comunication_system\src\screen_reader.py",
        "comunication_system\src\response_detector.py",
        "comunication_system\src\command_parser.py",
        "comunication_system\src\feedback_sender.py",
        "comunication_system\src\main_orchestrator.py",
        "comunication_system\config\settings.json"
    )

    $projectData = @{
        "project_name" = "Adapta ONE - Communication System"
        "version" = "1.0.0"
        "created_date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "folders" = @()
        "files" = @()
    }

    Write-Host "Capturando estrutura de pastas..." -ForegroundColor Yellow
    foreach ($folder in $foldersToCapture) {
        $folderPath = Join-Path $projectRoot $folder
        if (Test-Path $folderPath) {
            $projectData.folders += $folder
            Write-Host "  OK - $folder" -ForegroundColor Green
        }
    }

    Write-Host "Capturando arquivos..." -ForegroundColor Yellow
    foreach ($file in $filesToCapture) {
        $filePath = Join-Path $projectRoot $file
        if (Test-Path $filePath) {
            $fileContent = Get-Content $filePath -Raw -Encoding UTF8
            $projectData.files += @{
                "path" = $file
                "content" = $fileContent
                "size" = (Get-Item $filePath).Length
            }
            Write-Host "  OK - $file" -ForegroundColor Green
        }
    }

    Write-Host "Convertendo para JSON..." -ForegroundColor Yellow
    $jsonData = $projectData | ConvertTo-Json -Depth 10

    $bootstrapFile = "bootstrap_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    [System.IO.File]::WriteAllText($bootstrapFile, $jsonData, [System.Text.Encoding]::UTF8)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK - Bootstrap criado com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivo: $bootstrapFile" -ForegroundColor Cyan
    Write-Host "Tamanho: $((Get-Item $bootstrapFile).Length / 1MB) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para restaurar o projeto em outra pasta:" -ForegroundColor Yellow
    Write-Host "1. Copie $bootstrapFile para a nova pasta" -ForegroundColor Cyan
    Write-Host "2. Execute: restore_bootstrap.ps1 $bootstrapFile" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}