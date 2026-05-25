
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

function Show-FolderMenu {
    param([string]$title)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Root -match '^[A-Z]:\$'}
    $folders = @()
    $counter = 1
    
    Write-Host "DRIVES:" -ForegroundColor Green
    foreach ($drive in $drives) {
        Write-Host "  [$counter] $($drive.Name):" -ForegroundColor Cyan
        $folders += $drive.Root
        $counter++
    }
    
    Write-Host ""
    Write-Host "PASTAS RECENTES:" -ForegroundColor Green
    
    $commonFolders = @(
        @{Name = "Desktop"; Path = [Environment]::GetFolderPath("Desktop")},
        @{Name = "Documentos"; Path = [Environment]::GetFolderPath("MyDocuments")},
        @{Name = "Downloads"; Path = [Environment]::GetFolderPath("UserProfile") + "\Downloads"},
        @{Name = "Pasta Atual"; Path = Get-Location}
    )
    
    foreach ($folder in $commonFolders) {
        if (Test-Path $folder.Path) {
            Write-Host "  [$counter] $($folder.Name) - $($folder.Path)" -ForegroundColor Cyan
            $folders += $folder.Path
            $counter++
        }
    }
    
    Write-Host ""
    Write-Host "  [$counter] Digitar caminho customizado" -ForegroundColor Cyan
    $folders += "CUSTOM"
    $counter++
    
    Write-Host ""
    $choice = Read-Host "Escolha uma opção (número)"
    
    if ($choice -eq $counter - 1) {
        $customPath = Read-Host "Digite o caminho completo"
        if (-not (Test-Path $customPath)) {
            Write-Host "Caminho não existe. Criando..." -ForegroundColor Yellow
            New-Item -Path $customPath -ItemType Directory -Force | Out-Null
        }
        return $customPath
    } elseif ($choice -ge 1 -and $choice -le $folders.Count - 1) {
        return $folders[$choice - 1]
    } else {
        Write-Host "Opção inválida!" -ForegroundColor Red
        return Show-FolderMenu $title
    }
}

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "BOOTSTRAP - Adapta ONE Project Capture" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $projectRoot = Show-FolderMenu "SELECIONE A PASTA DO PROJETO (ORIGEM)"
    
    Write-Host ""
    Write-Host "Pasta do projeto: $projectRoot" -ForegroundColor Green
    Write-Host ""

    if (-not (Test-Path (Join-Path $projectRoot "backend.py"))) {
        Write-Host "AVISO: backend.py não encontrado!" -ForegroundColor Yellow
        $confirm = Read-Host "Deseja continuar mesmo assim? (S/N)"
        if ($confirm -ne "S" -and $confirm -ne "s") {
            Write-Host "Operação cancelada." -ForegroundColor Red
            exit 0
        }
    }

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
        "source_folder" = $projectRoot
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

    if ($projectData.files.Count -eq 0) {
        throw "Nenhum arquivo foi capturado!"
    }

    Write-Host "Convertendo para JSON..." -ForegroundColor Yellow
    $jsonData = $projectData | ConvertTo-Json -Depth 10

    Write-Host ""
    $bootstrapDest = Show-FolderMenu "SELECIONE ONDE SALVAR O ARQUIVO BOOTSTRAP"
    
    $bootstrapFile = "bootstrap_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $bootstrapPath = Join-Path $bootstrapDest $bootstrapFile
    
    [System.IO.File]::WriteAllText($bootstrapPath, $jsonData, [System.Text.Encoding]::UTF8)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK - Bootstrap criado com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivo: $bootstrapPath" -ForegroundColor Cyan
    Write-Host "Tamanho: $([math]::Round((Get-Item $bootstrapPath).Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host "Arquivos capturados: $($projectData.files.Count)" -ForegroundColor Cyan
    Write-Host "Pastas capturadas: $($projectData.folders.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para restaurar o projeto em outra pasta:" -ForegroundColor Yellow
    Write-Host "1. Copie $bootstrapFile para a nova pasta" -ForegroundColor Cyan
    Write-Host "2. Execute: restore_bootstrap.ps1" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}