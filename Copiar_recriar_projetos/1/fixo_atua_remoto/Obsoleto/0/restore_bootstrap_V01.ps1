
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

function Show-BootstrapMenu {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SELECIONE O ARQUIVO BOOTSTRAP" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $bootstrapFiles = Get-ChildItem -Filter "bootstrap_*.json" -ErrorAction SilentlyContinue
    
    if ($bootstrapFiles.Count -eq 0) {
        Write-Host "Nenhum arquivo bootstrap encontrado na pasta atual!" -ForegroundColor Red
        Write-Host ""
        $customPath = Read-Host "Digite o caminho completo do arquivo bootstrap"
        if (Test-Path $customPath) {
            return $customPath
        } else {
            throw "Arquivo não encontrado: $customPath"
        }
    }
    
    $counter = 1
    foreach ($file in $bootstrapFiles) {
        $size = [math]::Round($file.Length / 1MB, 2)
        Write-Host "  [$counter] $($file.Name) ($size MB)" -ForegroundColor Cyan
        $counter++
    }
    
    Write-Host ""
    $choice = Read-Host "Escolha uma opção (número)"
    
    if ($choice -ge 1 -and $choice -le $bootstrapFiles.Count) {
        return $bootstrapFiles[$choice - 1].FullName
    } else {
        Write-Host "Opção inválida!" -ForegroundColor Red
        return Show-BootstrapMenu
    }
}

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RESTORE - Adapta ONE Project Restore" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $bootstrapFile = Show-BootstrapMenu
    
    Write-Host ""
    Write-Host "Lendo arquivo bootstrap..." -ForegroundColor Yellow
    $jsonContent = Get-Content $bootstrapFile -Raw -Encoding UTF8
    $projectData = $jsonContent | ConvertFrom-Json

    Write-Host "Projeto: $($projectData.project_name)" -ForegroundColor Green
    Write-Host "Versão: $($projectData.version)" -ForegroundColor Green
    Write-Host "Data original: $($projectData.created_date)" -ForegroundColor Green
    Write-Host "Arquivos: $($projectData.files.Count)" -ForegroundColor Green
    Write-Host "Pastas: $($projectData.folders.Count)" -ForegroundColor Green
    Write-Host ""

    $restoreRoot = Show-FolderMenu "SELECIONE ONDE RESTAURAR O PROJETO"
    
    Write-Host ""
    Write-Host "Restaurando em: $restoreRoot" -ForegroundColor Green
    Write-Host ""

    $projectFolder = Join-Path $restoreRoot "Adapta_ONE_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $projectFolder -ItemType Directory -Force | Out-Null
    Write-Host "Pasta criada: $projectFolder" -ForegroundColor Green
    Write-Host ""

    Write-Host "Criando estrutura de pastas..." -ForegroundColor Yellow
    foreach ($folder in $projectData.folders) {
        $folderPath = Join-Path $projectFolder $folder
        if (-not (Test-Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            Write-Host "  OK - $folder" -ForegroundColor Green
        }
    }

    Write-Host "Restaurando arquivos..." -ForegroundColor Yellow
    foreach ($file in $projectData.files) {
        $filePath = Join-Path $projectFolder $file.path
        $fileDir = Split-Path $filePath
        
        if (-not (Test-Path $fileDir)) {
            New-Item -Path $fileDir -ItemType Directory -Force | Out-Null
        }

        [System.IO.File]::WriteAllText($filePath, $file.content, [System.Text.Encoding]::UTF8)
        Write-Host "  OK - $($file.path)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK - Projeto restaurado com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pasta do projeto: $projectFolder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Próximos passos:" -ForegroundColor Yellow
    Write-Host "1. Abra a pasta: $projectFolder" -ForegroundColor Cyan
    Write-Host "2. Execute: master_launcher.bat" -ForegroundColor Cyan
    Write-Host "3. Sistema iniciará automaticamente" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}