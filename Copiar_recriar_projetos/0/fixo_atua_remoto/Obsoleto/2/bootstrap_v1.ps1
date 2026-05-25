# Arquivo: bootstrap_v1.ps1
# Caminho: Scripts / bootstrap_v1.ps1
# Propósito: Capturar projeto em JSON e TXT, salvando em estruturas_JSON, com seleção de pasta via Windows Forms - CORRIGIDO

Add-Type -AssemblyName System.Windows.Forms

try {
    $jsonBasePath = "$env:LOCALAPPDATA\estruturas_JSON"
    Write-Host "Verificando pasta de destino: $jsonBasePath" -ForegroundColor Yellow

    if (!(Test-Path $jsonBasePath)) {
        New-Item -ItemType Directory -Path $jsonBasePath -Force | Out-Null
        Write-Host "Pasta criada: $jsonBasePath" -ForegroundColor Green
    }

    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Selecione a pasta do projeto a capturar"
    $folderBrowser.ShowNewFolderButton = $false
    $folderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer

    if ($folderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Nenhuma pasta selecionada. Saindo." -ForegroundColor Red
        exit 1
    }

    $sourceFolder = $folderBrowser.SelectedPath
    Write-Host "Pasta selecionada: $sourceFolder" -ForegroundColor Green

    $projectName = Split-Path $sourceFolder -Leaf
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $jsonFileName = "${projectName}_${timestamp}.json"
    $txtFileName = "${projectName}_${timestamp}.txt"
    $jsonPath = Join-Path $jsonBasePath $jsonFileName
    $txtPath = Join-Path $jsonBasePath $txtFileName

    Write-Host "Lendo arquivos da pasta..." -ForegroundColor Yellow
    $allFiles = @(Get-ChildItem -Path $sourceFolder -Recurse -File -ErrorAction Stop)
    Write-Host "Lidos $($allFiles.Count) arquivos." -ForegroundColor Green

    Write-Host "Coletando pastas..." -ForegroundColor Yellow
    $allFolders = @(Get-ChildItem -Path $sourceFolder -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $_.FullName.Substring($sourceFolder.Length).TrimStart('\')
    })
    Write-Host "Encontradas $($allFolders.Count) pastas." -ForegroundColor Green

    Write-Host "Construindo estrutura JSON..." -ForegroundColor Yellow
    
    # Construir JSON manualmente para evitar loop infinito
    $filesJson = @()
    foreach ($file in $allFiles) {
        $relativePath = $file.FullName.Substring($sourceFolder.Length).TrimStart('\')
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
            # Escapar conteúdo para JSON
            $content = $content -replace '\\', '\\\\' -replace '"', '\\"' -replace "`n", '\n' -replace "`r", '\r'
            $filesJson += @"
    {
      "path": "$relativePath",
      "content": "$content",
      "size": $($file.Length)
    }
"@
        } catch {
            Write-Warning "Erro ao ler $relativePath : $($_.Exception.Message)"
        }
    }

    $foldersJson = ""
    if ($allFolders.Count -gt 0) {
        $foldersJson = ($allFolders | ForEach-Object { "`"$_`"" }) -join ", "
    }

    $createdDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")

    # Montar JSON manualmente
    $jsonContent = @"
{
  "created_date": "$createdDate",
  "version": "1.0",
  "project_name": "$projectName",
  "files": [
$($filesJson -join ",`n")
  ],
  "folders": [$foldersJson],
  "source_folder": "$sourceFolder"
}
"@

    Write-Host "Salvando arquivos..." -ForegroundColor Yellow
    $jsonContent | Out-File -FilePath $jsonPath -Encoding UTF8 -Force
    $jsonContent | Out-File -FilePath $txtPath -Encoding UTF8 -Force

    Write-Host "✓ Arquivos salvos com sucesso!" -ForegroundColor Green
    Write-Host "  JSON: $jsonPath" -ForegroundColor Cyan
    Write-Host "  TXT:  $txtPath" -ForegroundColor Cyan
    Write-Host "  Tamanho: $(([System.IO.FileInfo]$jsonPath).Length / 1KB) KB" -ForegroundColor Cyan

} catch {
    Write-Host "✗ Erro durante a execução: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "StackTrace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "Processo concluído!" -ForegroundColor Green
pause

