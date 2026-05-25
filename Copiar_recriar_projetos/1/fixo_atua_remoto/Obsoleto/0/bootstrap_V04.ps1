
Add-Type -AssemblyName System.Windows.Forms

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
    $choice = Read-Host "Escolha uma opcao (numero)"
    
    if ($choice -eq $counter - 1) {
        $customPath = Read-Host "Digite o caminho completo"
        if (-not (Test-Path $customPath)) {
            Write-Host "Caminho nao existe. Criando..." -ForegroundColor Yellow
            New-Item -Path $customPath -ItemType Directory -Force | Out-Null
        }
        return $customPath
    } elseif ($choice -ge 1 -and $choice -le $folders.Count - 1) {
        return $folders[$choice - 1]
    } else {
        Write-Host "Opcao invalida!" -ForegroundColor Red
        return Show-FolderMenu $title
    }
}

$ErrorActionPreference = "Continue"

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "BOOTSTRAP - Captura Generica de Projeto" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    Write-Host "Script localizado em: $scriptPath" -ForegroundColor Green
    Write-Host ""

    $projectRoot = Show-FolderMenu "SELECIONE A PASTA DO PROJETO (ORIGEM)"
    
    Write-Host ""
    Write-Host "Pasta do projeto: $projectRoot" -ForegroundColor Green
    Write-Host ""

    $projectName = Read-Host "Digite o nome do projeto"
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = Split-Path -Leaf $projectRoot
    }

    Write-Host ""
    Write-Host "Capturando projeto: $projectName" -ForegroundColor Yellow
    Write-Host ""

    $projectData = @{
        "project_name" = $projectName
        "version" = "1.0.0"
        "created_date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "source_folder" = $projectRoot
        "folders" = @()
        "files" = @()
    }

    Write-Host "Capturando estrutura de pastas..." -ForegroundColor Yellow
    $allFolders = @(Get-ChildItem -Path $projectRoot -Directory -Recurse -ErrorAction SilentlyContinue)
    
    foreach ($folder in $allFolders) {
        $relativePath = $folder.FullName.Substring($projectRoot.Length).TrimStart('\')
        $projectData.folders += $relativePath
        Write-Host "  OK - $relativePath" -ForegroundColor Green
    }

    Write-Host "Capturando arquivos..." -ForegroundColor Yellow
    $allFiles = @(Get-ChildItem -Path $projectRoot -File -Recurse -ErrorAction SilentlyContinue)
    
    $fileCount = 0
    foreach ($file in $allFiles) {
        try {
            $relativePath = $file.FullName.Substring($projectRoot.Length).TrimStart('\')
            $fileContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            
            if ($null -ne $fileContent) {
                $projectData.files += @{
                    "path" = $relativePath
                    "content" = $fileContent
                    "size" = $file.Length
                }
                $fileCount++
                Write-Host "  OK - $relativePath" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ERRO ao ler - $($file.FullName)" -ForegroundColor Red
        }
    }

    if ($projectData.files.Count -eq 0) {
        throw "Nenhum arquivo foi capturado!"
    }

    Write-Host ""
    Write-Host "Convertendo para JSON..." -ForegroundColor Yellow
    $jsonData = $projectData | ConvertTo-Json -Depth 10

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bootstrapFile = "bootstrap_${projectName}_${timestamp}.json"
    $bootstrapPath = Join-Path $scriptPath $bootstrapFile
    
    Write-Host "Salvando em: $bootstrapPath" -ForegroundColor Yellow
    
    [System.IO.File]::WriteAllText($bootstrapPath, $jsonData, [System.Text.Encoding]::UTF8)
    
    if (-not (Test-Path $bootstrapPath)) {
        throw "Falha ao criar arquivo: $bootstrapPath"
    }

    $fileSize = [math]::Round((Get-Item $bootstrapPath).Length / 1MB, 2)

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK - Bootstrap criado com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Arquivo: $bootstrapFile" -ForegroundColor Cyan
    Write-Host "Caminho: $bootstrapPath" -ForegroundColor Cyan
    Write-Host "Tamanho: $fileSize MB" -ForegroundColor Cyan
    Write-Host "Arquivos capturados: $($projectData.files.Count)" -ForegroundColor Cyan
    Write-Host "Pastas capturadas: $($projectData.folders.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para restaurar o projeto em outra pasta:" -ForegroundColor Yellow
    Write-Host "1. Copie $bootstrapFile para a pasta onde esta restore_bootstrap.ps1" -ForegroundColor Cyan
    Write-Host "2. Execute: restore_bootstrap.ps1" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pressione ENTER para sair..."
    Read-Host

} catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Pressione ENTER para sair..."
    Read-Host
    exit 1
}