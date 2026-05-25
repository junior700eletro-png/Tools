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
        $customPath = (Read-Host "Digite o caminho completo").Trim()
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

function Get-FolderSize {
    param([string]$Path)
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) { $size = 0 }
        return $size
    } catch {
        return 0
    }
}

function Show-LargeFoldersMenu {
    param([array]$LargeFolders)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PASTAS GRANDES ENCONTRADAS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Essas pastas sao grandes e podem ser lentas:" -ForegroundColor Green
    Write-Host ""
    foreach ($folder in $LargeFolders) {
        $sizeMB = [math]::Round($folder.Size / 1MB, 2)
        Write-Host "  - $($folder.Name) ($sizeMB MB)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Opcoes:" -ForegroundColor Yellow
    Write-Host "  [1] IGNORAR pastas grandes (RECOMENDADO - mais rapido)" -ForegroundColor Green
    Write-Host "  [2] PROCESSAR TUDO (pode ser muito lento)" -ForegroundColor Yellow
    Write-Host ""
    $choice = Read-Host "Escolha uma opcao"
    if ($choice -eq "1") {
        return $true
    } elseif ($choice -eq "2") {
        return $false
    } else {
        Write-Host "Opcao invalida!" -ForegroundColor Red
        return Show-LargeFoldersMenu $LargeFolders
    }
}

function Read-FileContent {
    param([string]$FilePath)
    try {
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        $streamReader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::UTF8)
        $fileContent = $streamReader.ReadToEnd()
        $streamReader.Dispose()
        $fileStream.Dispose()
        return $fileContent
    } catch {
        try {
            $fileStream = [System.IO.File]::OpenRead($FilePath)
            $streamReader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::Default)
            $fileContent = $streamReader.ReadToEnd()
            $streamReader.Dispose()
            $fileStream.Dispose()
            return $fileContent
        } catch {
            try {
                $fileStream = [System.IO.File]::OpenRead($FilePath)
                $streamReader = New-Object System.IO.StreamReader($fileStream, [System.Text.Encoding]::ASCII)
                $fileContent = $streamReader.ReadToEnd()
                $streamReader.Dispose()
                $fileStream.Dispose()
                return $fileContent
            } catch {
                return $null
            }
        }
    }
}

function Get-FilesRecursive {
    param([string]$Path, [array]$IgnoreFolders, [array]$AllowedExtensions, [int]$MaxFiles = 500, [bool]$UseIgnore = $true)
    $files = @()
    $fileCount = 0
    $ignoredCount = 0
    $errorCount = 0
    function Recurse-Folder {
        param([string]$CurrentPath, [int]$Depth = 0)
        if ($fileCount -ge $MaxFiles) { return }
        if ($Depth -gt 15) { return }
        try {
            $items = Get-ChildItem -Path $CurrentPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if ($fileCount -ge $MaxFiles) { return }
                if ($item.PSIsContainer) {
                    if ($UseIgnore -and $IgnoreFolders -contains $item.Name) {
                        $ignoredCount++
                    } else {
                        Recurse-Folder -CurrentPath $item.FullName -Depth ($Depth + 1)
                    }
                } else {
                    $ext = $item.Extension.ToLower()
                    if ($AllowedExtensions -contains $ext) {
                        $fileContent = Read-FileContent -FilePath $item.FullName
                        if ($null -ne $fileContent -and $fileContent.Length -lt 5MB) {
                            $relativePath = $item.FullName.Substring($Path.Length).TrimStart('\')
                            $files += @{"path" = $relativePath; "content" = $fileContent; "size" = $item.Length}
                            $fileCount++
                            Write-Host "  OK - $($item.Name) ($fileCount/$MaxFiles)" -ForegroundColor Green
                        } else {
                            $errorCount++
                            Write-Host "  ERRO - $($item.Name) (arquivo vazio ou muito grande)" -ForegroundColor Red
                        }
                    }
                }
            }
        } catch {
            Write-Host "  ERRO ao acessar - $CurrentPath" -ForegroundColor Red
        }
    }
    Recurse-Folder -CurrentPath $Path
    Write-Host ""
    Write-Host "Resumo da captura:" -ForegroundColor Cyan
    Write-Host "  Arquivos capturados: $fileCount" -ForegroundColor Green
    Write-Host "  Erros ao ler: $errorCount" -ForegroundColor Yellow
    if ($UseIgnore) {
        Write-Host "  Pastas ignoradas: $ignoredCount" -ForegroundColor Yellow
    }
    return $files
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
    $projectName = (Read-Host "Digite o nome do projeto").Trim()
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = Split-Path -Leaf $projectRoot
    }
    Write-Host ""
    Write-Host "Capturando projeto: $projectName" -ForegroundColor Yellow
    Write-Host ""
    $projectData = @{"project_name" = $projectName; "version" = "1.0.0"; "created_date" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; "source_folder" = $projectRoot; "folders" = @(); "files" = @()}
    $ignoreFolders = @("node_modules", ".git", ".vscode", "__pycache__", "bin", "obj", ".vs", "dist", "build", "venv", "env", ".env", "Obsoleto", ".next", ".nuxt", "coverage", ".pytest_cache", "vendor", "packages", ".gradle", ".m2", "target")
    $allowedExtensions = @(".ps1", ".bat", ".py", ".js", ".html", ".css", ".json", ".txt", ".md", ".xml", ".yaml", ".yml", ".ini", ".conf", ".config", ".sh", ".rb", ".php", ".java", ".cs", ".cpp", ".c", ".h", ".sql", ".r", ".lua", ".go", ".rs", ".ts", ".jsx", ".tsx", ".vue", ".svelte", ".gradle", ".maven", ".sbt", ".toml", ".lock")
    Write-Host "Analisando tamanho das pastas..." -ForegroundColor Yellow
    Write-Host ""
    $allFolders = @(Get-ChildItem -Path $projectRoot -Directory -ErrorAction SilentlyContinue)
    $largeFolders = @()
    foreach ($folder in $allFolders) {
        $size = Get-FolderSize -Path $folder.FullName
        $sizeMB = [math]::Round($size / 1MB, 2)
        if ($size -gt 50MB) {
            $largeFolders += @{Name = $folder.Name; Size = $size; Path = $folder.FullName}
            Write-Host "  GRANDE - $($folder.Name) ($sizeMB MB)" -ForegroundColor Yellow
        } else {
            Write-Host "  OK - $($folder.Name) ($sizeMB MB)" -ForegroundColor Green
        }
    }
    Write-Host ""
    $ignoreMode = $false
    if ($largeFolders.Count -gt 0) {
        $ignoreMode = Show-LargeFoldersMenu $largeFolders
    }
    $projectData.ignore_mode = $ignoreMode
    Write-Host ""
    Write-Host "Capturando estrutura de pastas..." -ForegroundColor Yellow
    if ($ignoreMode) {
        $foldersToCapture = @($allFolders | Where-Object {$ignoreFolders -notcontains $_.Name})
    } else {
        $foldersToCapture = $allFolders
    }
    foreach ($folder in $foldersToCapture) {
        $relativePath = $folder.FullName.Substring($projectRoot.Length).TrimStart('\')
        $projectData.folders += $relativePath
        Write-Host "  OK - $relativePath" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Capturando arquivos..." -ForegroundColor Yellow
    $capturedFiles = Get-FilesRecursive -Path $projectRoot -IgnoreFolders $ignoreFolders -AllowedExtensions $allowedExtensions -MaxFiles 500 -UseIgnore $ignoreMode
    foreach ($file in $capturedFiles) {
        $projectData.files += $file
    }
    if ($projectData.files.Count -eq 0) {
        Write-Host ""
        Write-Host "AVISO: Nenhum arquivo foi capturado!" -ForegroundColor Yellow
        Write-Host "Verifique se:" -ForegroundColor Yellow
        Write-Host "  - A pasta tem arquivos com extensoes permitidas" -ForegroundColor Cyan
        Write-Host "  - Os arquivos nao estao abertos em outro programa" -ForegroundColor Cyan
        Write-Host "  - Voce tem permissao de leitura" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Pressione ENTER para sair..."
        Read-Host
        exit 1
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
    Write-Host "Modo ignorar: $(if ($ignoreMode) { 'ATIVADO' } else { 'DESATIVADO' })" -ForegroundColor Cyan
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