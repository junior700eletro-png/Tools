
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
    param([string]$scriptPath)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SELECIONE O ARQUIVO BOOTSTRAP" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Procurando em: $scriptPath" -ForegroundColor Green
    Write-Host ""
    
    $bootstrapFiles = Get-ChildItem -Path $scriptPath -Filter "bootstrap_*.json" -ErrorAction SilentlyContinue
    
    if ($bootstrapFiles.Count -eq 0) {
        Write-Host "Nenhum arquivo bootstrap encontrado!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Opções:" -ForegroundColor Yellow
        Write-Host "  [1] Digitar caminho completo do arquivo" -ForegroundColor Cyan
        Write-Host "  [2] Cancelar" -ForegroundColor Cyan
        Write-Host ""
        $choice = Read-Host "Escolha uma opção"
        
        if ($choice -eq "1") {
            $customPath = Read-Host "Digite o caminho completo do arquivo bootstrap"
            if (Test-Path $customPath) {
                return $customPath
            } else {
                throw "Arquivo não encontrado: $customPath"
            }
        } else {
            throw "Operação cancelada."
        }
    }
    
    $counter = 1
    foreach ($file in $bootstrapFiles) {
        $size = [math]::Round($file.Length / 1MB, 2)
        $date = $file.LastWriteTime.ToString("dd/MM/yyyy HH:mm:ss")
        Write-Host "  [$counter] $($file.Name) ($size MB) - $date" -ForegroundColor Cyan
        $counter++
    }
    
    Write-Host ""
    $choice = Read-Host "Escolha uma opção (número)"
    
    if ($choice -ge 1 -and $choice -le $bootstrapFiles.Count) {
        return $bootstrapFiles[$choice - 1].FullName
    } else {
        Write-Host "Opção inválida!" -ForegroundColor Red
        return Show-BootstrapMenu $scriptPath
    }
}

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RESTORE - Restauração Genérica de Projeto" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
