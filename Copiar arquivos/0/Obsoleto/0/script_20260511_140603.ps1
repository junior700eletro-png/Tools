
$jsonPath = 'C:\temp\bootstrap_temp.json'
$backupFolder = 'C:\temp'

# Lê o JSON
$jsonContent = Get-Content -Path $jsonPath -Raw -ErrorAction SilentlyContinue
if (-not $jsonContent) {
    Write-Host 'Erro: Arquivo JSON não encontrado.' -ForegroundColor Red
    exit
}
$json = $jsonContent | ConvertFrom-Json
$restoredFolder = $json.source_folder

if (-not (Test-Path $backupFolder)) {
    Write-Host "Pasta original ($backupFolder) não encontrada." -ForegroundColor Red
    exit
}
if (-not (Test-Path $restoredFolder)) {
    Write-Host "Pasta restaurada ($restoredFolder) não encontrada." -ForegroundColor Red
    exit
}

# Funções para contar pastas e arquivos
function Get-FolderCount($path) {
    (Get-ChildItem -Path $path -Directory -Recurse -ErrorAction SilentlyContinue).Count
}

function Get-FileCount($path) {
    (Get-ChildItem -Path $path -File -Recurse -ErrorAction SilentlyContinue).Count
}

$origFolders = Get-FolderCount $backupFolder
$restFolders = Get-FolderCount $restoredFolder
$restFileCount = Get-FileCount $restoredFolder

# Lista de arquivos originais (excluindo o JSON de metadados)
$origFilesList = Get-ChildItem -Path $backupFolder -File -Recurse -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne 'bootstrap_temp.json' } |
                 ForEach-Object {
                     $relPath = $_.FullName.Substring($backupFolder.Length).TrimStart('\')
                     $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                     [PSCustomObject]@{
                         RelativePath = $relPath
                         Size = $_.Length
                         Hash = $hash
                     }
                 }

$origFiles = $origFilesList.Count

# Verifica arquivos idênticos e coleta diferenças
$identicalCount = 0
$differences = @()

foreach ($file in $origFilesList) {
    $restFilePath = Join-Path -Path $restoredFolder -ChildPath $file.RelativePath
    
    if (-not (Test-Path $restFilePath -PathType Leaf)) {
        $differences += "FALTANDO: $($file.RelativePath)"
        continue
    }
    
    $restFileInfo = Get-Item $restFilePath
    if ($restFileInfo.Length -ne $file.Size) {
        $differences += "TAMANHO DIFERENTE: $($file.RelativePath) (orig: $($file.Size) bytes, rest: $($restFileInfo.Length) bytes)"
        continue
    }
    
    $restHash = (Get-FileHash -Path $restFilePath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
    if ($restHash -ne $file.Hash) {
        $differences += "CONTEÚDO DIFERENTE: $($file.RelativePath)"
        continue
    }
    
    $identicalCount++
}

# Verifica arquivos extras na pasta restaurada
$restFilesRelPaths = Get-ChildItem -Path $restoredFolder -File -Recurse -ErrorAction SilentlyContinue |
                     ForEach-Object {
                         $_.FullName.Substring($restoredFolder.Length).TrimStart('\')
                     }

$origRelPaths = $origFilesList | ForEach-Object { $_.RelativePath }

foreach ($restRelPath in $restFilesRelPaths) {
    if ($origRelPaths -notcontains $restRelPath) {
        $differences += "EXTRA: $restRelPath"
    }
}

# Calcula índice de identidade
totalFiles = if ($origFiles -gt 0) { $origFiles } else { 1 }
$identityPercent = [math]::Round(($identicalCount / $totalFiles) * 100, 2)

# Exibe resultados
Write-Host "\n=== RESULTADOS DA VALIDAÇÃO ===" -ForegroundColor Cyan
Write-Host "Pasta original (backup): $backupFolder" 
Write-Host "Pasta restaurada: $restoredFolder" 
Write-Host "Número de pastas original: $origFolders"
Write-Host "Número de pastas restaurado: $restFolders"
Write-Host "Número de arquivos original: $origFiles"
Write-Host "Número de arquivos restaurado: $restFileCount"
Write-Host "Índice de identidade: ${identityPercent}%" -ForegroundColor Yellow

if ($identityPercent -ge 90) {
    Write-Host "VALIDADO" -ForegroundColor Green
} else {
    Write-Host "TRUNCADO" -ForegroundColor Red
}

if ($differences.Count -gt 0) {
    Write-Host "\nDiferenças encontradas (${$differences.Count}):" -ForegroundColor Yellow
    $differences | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
    }
} else {
    Write-Host "\nNenhuma diferença encontrada!" -ForegroundColor Green
}


