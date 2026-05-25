
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

try {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "BOOTSTRAP - Captura Genérica de Projeto" -ForegroundColor Yellow
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
    $allFolders = Get-ChildItem -Path $projectRoot -Directory -Recurse -ErrorAction SilentlyContinue
    
    foreach ($folder in $allFolders) {
        $relativePath = $folder.FullName.Substring($projectRoot.Length).TrimStart('\')
        $projectData.folders += $relativePath
        Write-Host "  OK - $relativePath" -ForegroundColor Green
    }

    Write-Host "Capturando arquivos..." -ForegroundColor Yellow
    $allFiles = Get-ChildItem -Path $projectRoot -File -Recurse -ErrorAction SilentlyContinue
    
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
                Write-Host "  OK - $relativePath ($([math]::Round($fi