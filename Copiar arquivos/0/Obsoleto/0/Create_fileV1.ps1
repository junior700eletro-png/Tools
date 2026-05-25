
$jsonPath = "C:\temp\bootstrap_temp.json"

if (-not (Test-Path $jsonPath)) {
    Write-Error "Arquivo JSON não encontrado: $jsonPath"
    exit 1
}

try {
    $jsonContent = Get-Content $jsonPath -Raw -Encoding UTF8
    $jsonData = $jsonContent | ConvertFrom-Json
    Write-Host "✅ JSON validado" -ForegroundColor Green
} catch {
    Write-Host "❌ JSON inválido: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$createdDate = $jsonData.created_date
$version = $jsonData.version
$projectName = $jsonData.project_name
$sourceFolder = $jsonData.source_folder
$folders = @($jsonData.folders)
$files = @($jsonData.files)

# Cria pasta base
New-Item -ItemType Directory -Path $sourceFolder -Force | Out-Null

# Cria pastas conforme 'folders'
foreach ($folder in $folders) {
    $fullFolder = Join-Path $sourceFolder $folder
    New-Item -ItemType Directory -Path $fullFolder -Force | Out-Null
}

# Regrava arquivos exatamente
$fileSuccessCount = 0
foreach ($file in $files) {
    $fullPath = Join-Path $sourceFolder $file.path
    $parentDir = Split-Path $fullPath -Parent
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    try {
        $bytes = [Convert]::FromBase64String($file.content)
        [System.IO.File]::WriteAllBytes($fullPath, $bytes)
        $actualSize = (Get-Item $fullPath -ErrorAction SilentlyContinue).Length
        if ($actualSize -eq $file.size) {
            $fileSuccessCount++
        } else {
            Write-Warning "Tamanho incorreto em $($file.path): esperado $($file.size), atual ${actualSize}"
        }
    } catch {
        Write-Warning "Falha ao processar $($file.path): $_"
    }
}

# Confirmações em VERDE
Write-Host "✅ $($folders.Count) pastas criadas" -ForegroundColor Green
Write-Host "✅ $fileSuccessCount arquivos regravados" -ForegroundColor Green
Write-Host "✅ Projeto restaurado em: $sourceFolder" -ForegroundColor Green