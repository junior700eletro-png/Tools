# PATCH_APLICADO: Create_file_v4_enhanced.fix em 2026-05-18 14:15:30
# Utilitário para criar arquivo a partir do clipboard com validação extensiva, busca inteligente de nome em metadados,
# detecção avançada de extensão, logging, controle de versões em pasta Obsoleto e validação dupla de JSON.

Add-Type -AssemblyName System.Windows.Forms

# ---------- Logging ----------
$logFile = Join-Path $env:TEMP 'Create_file_v4.log'

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp | $Message" | Add-Content -Path $logFile -Encoding UTF8
    Write-Host "[LOG] $Message" -ForegroundColor Gray
}

# ---------- Versão de backup em Obsoleto ----------
function Get-NextBackupName {
    param([string]$baseName, [string]$extension, [string]$directory)
    
    $obsoleteFolder = Join-Path $directory 'Obsoleto'
    if (-not (Test-Path $obsoleteFolder)) {
        New-Item -ItemType Directory -Path $obsoleteFolder -Force | Out-Null
    }
    
    $version = 1
    $existingFiles = Get-ChildItem -Path $obsoleteFolder -Filter "$baseName*$extension" -ErrorAction SilentlyContinue
    
    foreach ($file in $existingFiles) {
        if ($file.BaseName -match "_V(\d+)$") {
            $extractedVersion = [int]$matches[1]
            if ($extractedVersion -ge $version) {
                $version = $extractedVersion + 1
            }
        }
    }
    
    return "$baseName`_V$('{0:D2}' -f $version)$extension"
}

# ---------- Busca de nome em JSON / comentários ----------
function Extract-JsonMetadata {
    param([string]$Content)
    
    try {
        $json = $Content | ConvertFrom-Json -ErrorAction Stop
        if ($json.filename) {
            return @($json.filename)
        }
    } catch {
        # Não é JSON válido, continua
    }
    return @()
}

function Extract-CommentMetadata {
    param([string]$Content)
    
    $names = @()
    $lines = $Content -split "`n"
    
    foreach ($line in $lines) {
        # Busca padrão @FILE: nome_do_arquivo
        if ($line -match '@FILE:\s*([a-zA-Z0-9_\-\.]+)') {
            $names += $matches[1]
        }
        # Busca padrão # filename: nome_do_arquivo
        elseif ($line -match '#\s*filename:\s*([a-zA-Z0-9_\-\.]+)') {
            $names += $matches[1]
        }
        # Busca padrão // filename: nome_do_arquivo
        elseif ($line -match '//\s*filename:\s*([a-zA-Z0-9_\-\.]+)') {
            $names += $matches[1]
        }
    }
    
    return $names
}

function Extract-AnyCommentFilename {
    param([string]$Content)
    
    $names = @()
    $lines = $Content -split "`n"
    
    foreach ($line in $lines | Select-Object -First 10) {
        # Busca comentários genéricos com padrão de nome de arquivo
        if ($line -match '#\s*([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]+)') {
            $names += $matches[1]
        }
        elseif ($line -match '//\s*([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]+)') {
            $names += $matches[1]
        }
        elseif ($line -match 'REM\s+([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]+)') {
            $names += $matches[1]
        }
    }
    
    return $names
}

function Select-FilenameFromList {
    param([string[]]$Names)
    
    if ($Names.Count -eq 0) {
        return $null
    }
    
    if ($Names.Count -eq 1) {
        return $Names[0]
    }
    
    Write-Host "`n=== Múltiplos nomes encontrados ===" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Names.Count; $i++) {
        Write-Host "$($i + 1). $($Names[$i])"
    }
    Write-Host "$($Names.Count + 1). Usar timestamp (padrão)"
    
    $choice = Read-Host "Escolha uma opção"
    
    if ([int]::TryParse($choice, [ref]$null)) {
        $choiceInt = [int]$choice
        if ($choiceInt -ge 1 -and $choiceInt -le $Names.Count) {
            return $Names[$choiceInt - 1]
        }
        elseif ($choiceInt -eq $Names.Count + 1) {
            return $null
        }
    }
    
    Write-Host "Opção inválida. Usando timestamp." -ForegroundColor Yellow
    return $null
}

function Get-FilenameFromMetadata {
    param([string]$Content, [switch]$Verbose)
    
    $allNames = @()
    
    # Busca em JSON
    $jsonNames = Extract-JsonMetadata -Content $Content
    if ($jsonNames.Count -gt 0) {
        $allNames += $jsonNames
        if ($Verbose) { Write-Host "Nomes encontrados em JSON: $($jsonNames -join ', ')" -ForegroundColor Green }
    }
    
    # Busca em comentários específicos (@FILE:, filename:)
    $commentNames = Extract-CommentMetadata -Content $Content
    if ($commentNames.Count -gt 0) {
        $allNames += $commentNames
        if ($Verbose) { Write-Host "Nomes encontrados em comentários: $($commentNames -join ', ')" -ForegroundColor Green }
    }
    
    # Busca em comentários genéricos
    $genericNames = Extract-AnyCommentFilename -Content $Content
    if ($genericNames.Count -gt 0) {
        $allNames += $genericNames
        if ($Verbose) { Write-Host "Nomes encontrados em comentários genéricos: $($genericNames -join ', ')" -ForegroundColor Green }
    }
    
    # Remove duplicatas
    $allNames = $allNames | Select-Object -Unique
    
    if ($allNames.Count -gt 0) {
        return Select-FilenameFromList -Names $allNames
    }
    
    return $null
}

function Get-FilenameFallbackWithTimestamp {
    param([string]$Content, [switch]$Verbose)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fallbackName = "arquivo_$timestamp"
    
    if ($Verbose) { Write-Host "Usando nome padrão com timestamp: $fallbackName" -ForegroundColor Yellow }
    
    return $fallbackName
}

# ---------- Detecção de extensão ----------
function Detect-ContentExtension {
    param([string]$Content)
    
    # PowerShell
    if ($Content -match '^\s*(function|param|Write-Host|Get-|Set-|New-|Remove-)' -or $Content -match '\$\w+\s*=') {
        return '.ps1'
    }
    
    # Python
    if ($Content -match '^\s*(import|from|def|class|if __name__)' -or $Content -match 'print\(' -or $Content -match '\.py') {
        return '.py'
    }
    
    # JSON
    if ($Content -match '^\s*\{' -or $Content -match '^\s*\[') {
        try {
            $Content | ConvertFrom-Json -ErrorAction Stop | Out-Null
            return '.json'
        } catch {
            # Pode ser JSON malformado, tenta mesmo assim
            return '.json'
        }
    }
    
    # BAT/CMD
    if ($Content -match '^\s*(@echo|REM|SETLOCAL|CALL|FOR)' -or $Content -match '\.bat|\.cmd') {
        return '.bat'
    }
    
    # JavaScript
    if ($Content -match '^\s*(function|const|let|var|console\.|document\.)' -or $Content -match '\.js') {
        return '.js'
    }
    
    # HTML
    if ($Content -match '^\s*<!DOCTYPE|<html|<head|<body') {
        return '.html'
    }
    
    # Padrão: TXT
    return '.txt'
}

# ---------- Validação de conteúdo ----------
function Validate-Script {
    param([string]$Path, [string]$Ext)
    
    $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        return @{ valid = $false; errors = @("Arquivo vazio ou inacessível") }
    }
    
    $errors = @()
    
    switch ($Ext) {
        '.ps1' {
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null) | Out-Null
            } catch {
                $errors += "Erro de sintaxe PowerShell: $($_.Exception.Message)"
            }
        }
        '.json' {
            try {
                $content | ConvertFrom-Json -ErrorAction Stop | Out-Null
            } catch {
                $errors += "JSON inválido: $($_.Exception.Message)"
            }
        }
        '.py' {
            # Validação básica Python
            if ($content -match 'def\s+\w+\s*\(' -and $content -notmatch 'def\s+\w+\s*\([^)]*\):') {
                $errors += "Possível erro de sintaxe em definição de função"
            }
        }
        '.bat' {
            # Validação básica BAT
            if ($content -match 'GOTO\s+\w+' -and $content -notmatch ':\w+') {
                $errors += "GOTO sem label correspondente"
            }
        }
    }
    
    return @{ valid = ($errors.Count -eq 0); errors = $errors }
}

function Validate-AndFix-Json {
    param([string]$Content)
    
    $errors = @()
    $fixed = $false
    $fixedContent = $Content
    
    try {
        $Content | ConvertFrom-Json -ErrorAction Stop | Out-Null
        return @{ valid = $true; errors = @(); fixed = $false; content = $Content }
    } catch {
        $errors += "JSON inválido: $($_.Exception.Message)"
    }
    
    # Tenta corrigir problemas comuns
    if ($fixedContent -match ',\s*}' -or $fixedContent -match ',\s*\]') {
        $fixedContent = $fixedContent -replace ',(\s*[}\]])', '$1'
        $fixed = $true
        Write-Host "Corrigido: vírgula antes de fechamento" -ForegroundColor Yellow
    }
    
    if ($fixedContent -match '":\s*undefined' -or $fixedContent -match '":\s*null') {
        $fixedContent = $fixedContent -replace '":\s*undefined', '": null'
        $fixed = $true
        Write-Host "Corrigido: undefined para null" -ForegroundColor Yellow
    }
    
    # Valida novamente após correção
    if ($fixed) {
        try {
            $fixedContent | ConvertFrom-Json -ErrorAction Stop | Out-Null
            $errors = @()
            return @{ valid = $true; errors = @(); fixed = $true; content = $fixedContent }
        } catch {
            $errors += "Ainda há erros após correção: $($_.Exception.Message)"
        }
    }
    
    return @{ valid = $false; errors = $errors; fixed = $false; content = $Content }
}

# ---------- Expansão de JSON customizado (files[].path/content) ----------
function Expand-CustomJsonProject {
    param([string]$JsonPath, [string]$TargetRoot)
    
    if (-not (Test-Path $JsonPath)) {
        Write-Host "Arquivo JSON não encontrado: $JsonPath" -ForegroundColor Red
        return $false
    }
    
    try {
        $json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "Erro ao ler JSON: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    if (-not $json.files) {
        Write-Host "JSON não contém propriedade 'files'" -ForegroundColor Red
        return $false
    }
    
    $projectName = $json.project_name -or "projeto"
    $projectPath = Join-Path $TargetRoot $projectName
    
    if (-not (Test-Path $projectPath)) {
        New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
    }
    
    foreach ($file in $json.files) {
        $filePath = Join-Path $projectPath $file.path
        $fileDir = Split-Path -Path $filePath
        
        if (-not (Test-Path $fileDir)) {
            New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
        }
        
        try {
            Set-Content -Path $filePath -Value $file.content -Encoding UTF8 -ErrorAction Stop
            Write-Host "Criado: $filePath" -ForegroundColor Green
        } catch {
            Write-Host "Erro ao criar $filePath : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "Projeto expandido em: $projectPath" -ForegroundColor Green
    return $true
}

# ---------- Remoção de comentários ----------
function Remove-Comments {
    param([string]$Content, [string]$Ext)
    
    $lines = $Content -split "`n"
    $filtered = @()
    
    foreach ($line in $lines) {
        $keep = $true
        
        switch ($Ext) {
            '.ps1' {
                if ($line -match '^\s*#') { $keep = $false }
            }
            '.py' {
                if ($line -match '^\s*#') { $keep = $false }
            }
            '.bat' {
                if ($line -imatch '^\s*(REM|::)') { $keep = $false }
            }
            '.js' {
                if ($line -match '^\s*//') { $keep = $false }
            }
            '.java' {
                if ($line -match '^\s*//') { $keep = $false }
            }
        }
        
        if ($keep) {
            $filtered += $line
        }
    }
    
    return $filtered -join "`n"
}

# ---------- Validação Extensiva Dupla ----------
function Perform-ExtensiveValidation {
    param([string]$Content, [string]$Extension, [int]$Iteration = 1)
    
    Write-Host "`n=== Varredura de Validação #$Iteration ===" -ForegroundColor Cyan
    
    $validationResult = Validate-Script -Path ([System.IO.Path]::GetTempFileName()) -Ext $Extension
    
    if ($Extension -eq '.json') {
        $jsonResult = Validate-AndFix-Json -Content $Content
        if (-not $jsonResult.valid) {
            Write-Host "❌ JSON inválido encontrado" -ForegroundColor Red
            foreach ($error in $jsonResult.errors) {
                Write-Host "   - $error" -ForegroundColor Red
            }
            if ($jsonResult.fixed) {
                Write-Host "✓ Correções aplicadas, executando varredura novamente..." -ForegroundColor Yellow
                return Perform-ExtensiveValidation -Content $jsonResult.content -Extension $Extension -Iteration ($Iteration + 1)
            }
            return @{ valid = $false; content = $Content; iterations = $Iteration }
        } else {
            Write-Host "✓ JSON válido" -ForegroundColor Green
            return @{ valid = $true; content = $jsonResult.content; iterations = $Iteration }
        }
    }
    
    if ($validationResult.valid) {
        Write-Host "✓ Arquivo válido" -ForegroundColor Green
        return @{ valid = $true; content = $Content; iterations = $Iteration }
    } else {
        Write-Host "❌ Erros encontrados:" -ForegroundColor Red
        foreach ($error in $validationResult.errors) {
            Write-Host "   - $error" -ForegroundColor Red
        }
        return @{ valid = $false; content = $Content; iterations = $Iteration }
    }
}

# ---------- Fluxo principal ----------
Write-Host "Create_file_v4_enhanced.ps1 - Criando arquivo a partir do clipboard" -ForegroundColor Cyan
Write-Log "Script iniciado"

# Seleciona pasta de destino
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Selecione a pasta de destino"
$folderBrowser.ShowNewFolderButton = $true

if ($folderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada." -ForegroundColor Yellow
    exit
}

$selectedFolder = $folderBrowser.SelectedPath
Write-Host "Pasta selecionada: $selectedFolder" -ForegroundColor Green

# Lê conteúdo do clipboard
$contentOriginal = Get-Clipboard
if ([string]::IsNullOrWhiteSpace($contentOriginal)) {
    Write-Host "Clipboard vazio! Nenhum conteúdo para processar." -ForegroundColor Red
    Write-Log "Erro: Clipboard vazio"
    exit
}

Write-Host "Conteúdo lido do clipboard ($(($contentOriginal -split "`n").Count) linhas)" -ForegroundColor Green
Write-Log "Conteúdo lido do clipboard"

# Salva em arquivo temporário
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $contentOriginal -Encoding UTF8

# Detecta extensão
$extension = Detect-ContentExtension -Content $contentOriginal
Write-Host "Extensão detectada: $extension" -ForegroundColor Green
Write-Log "Extensão detectada: $extension"

# Busca nome do arquivo em metadados/comentários
$filename = Get-FilenameFromMetadata -Content $contentOriginal -Verbose
if (-not $filename) {
    $filename = Get-FilenameFallbackWithTimestamp -Content $contentOriginal -Verbose
}

Write-Host "Nome do arquivo: $filename" -ForegroundColor Green
Write-Log "Nome do arquivo: $filename"

# Adiciona extensão se não tiver
if ($filename -notmatch '\.\w+$') {
    $filename = "$filename$extension"
}

# Menu interativo
$menuLoop = $true
while ($menuLoop) {
    Write-Host "`n=== Menu de Opções ===" -ForegroundColor Cyan
    Write-Host "1. Validar conteúdo"
    Write-Host "2. Remover comentários"
    Write-Host "3. Salvar com backup"
    Write-Host "4. Copiar nome do arquivo"
    Write-Host "5. Expandir JSON customizado"
    Write-Host "6. Sair"
    
    $choice = Read-Host "Escolha uma opção"
    
    switch ($choice) {
        '1' {
            $validationResult = Validate-Script -Path $tempFile -Ext $extension
            if ($validationResult.valid) {
                Write-Host "✓ Arquivo válido!" -ForegroundColor Green
            } else {
                Write-Host "❌ Erros encontrados:" -ForegroundColor Red
                foreach ($error in $validationResult.errors) {
                    Write-Host "   - $error" -ForegroundColor Red
                }
            }
        }
        '2' {
            $contentOriginal = Remove-Comments -Content $contentOriginal -Ext $extension
            Set-Content -Path $tempFile -Value $contentOriginal -Encoding UTF8
            Write-Host "✓ Comentários removidos" -ForegroundColor Green
            Write-Log "Comentários removidos"
        }
        '3' {
            # Cria pasta Obsoleto se não existir
            $obsoleteFolder = Join-Path $selectedFolder 'Obsoleto'
            if (-not (Test-Path $obsoleteFolder)) {
                New-Item -ItemType Directory -Path $obsoleteFolder -Force | Out-Null
            }
            
            # Verifica se arquivo já existe
            $filePath = Join-Path $selectedFolder $filename
            if (Test-Path $filePath) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $ext = [System.IO.Path]::GetExtension($filename)
                $backupName = Get-NextBackupName -baseName $baseName -extension $ext -directory $selectedFolder
                $backupPath = Join-Path $obsoleteFolder $backupName
                
                Copy-Item -Path $filePath -Destination $backupPath -Force
                Write-Host "✓ Backup criado: $backupName" -ForegroundColor Green
                Write-Log "Backup criado: $backupName"
            }
            
            # Executa validação extensiva
            $extensiveValidation = Perform-ExtensiveValidation -Content $contentOriginal -Extension $extension
            
            if ($extensiveValidation.valid) {
                # Salva arquivo final
                Set-Content -Path $filePath -Value $extensiveValidation.content -Encoding UTF8
                Write-Host "✓ Arquivo salvo com sucesso: $filePath" -ForegroundColor Green
                Write-Log "Arquivo salvo: $filePath"
                $menuLoop = $false
            } else {
                Write-Host "❌ Arquivo não pode ser salvo devido a erros de validação" -ForegroundColor Red
                Write-Host "Corrija os erros e tente novamente." -ForegroundColor Yellow
            }
        }
        '4' {
            $filename | Set-Clipboard
            Write-Host "✓ Nome copiado para clipboard: $filename" -ForegroundColor Green
        }
        '5' {
            $jsonPath = Read-Host "Caminho do arquivo JSON"
            if (Test-Path $jsonPath) {
                Expand-CustomJsonProject -JsonPath $jsonPath -TargetRoot $selectedFolder
            } else {
                Write-Host "Arquivo não encontrado: $jsonPath" -ForegroundColor Red
            }
        }
        '6' {
            Write-Host "Saindo..." -ForegroundColor Yellow
            $menuLoop = $false
        }
        default {
            Write-Host "Opção inválida" -ForegroundColor Red
        }
    }
}

# Limpeza
if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}

Write-Host "`nScript finalizado." -ForegroundColor Green
Write-Log "Script finalizado"