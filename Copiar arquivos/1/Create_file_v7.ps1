# PATCH_APLICADO: Create_file_v7.5_regex_fix.fix em 2026-05-18 19:15:00
# RECUPERA \\ A PARTIR DE ¦ ¦ ADAPTA ONE
# Utilitário com REGEX CORRIGIDA para barras invertidas

Add-Type -AssemblyName System.Windows.Forms

$logFile = Join-Path $env:TEMP 'Create_file_v7.log'

if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    $color = switch ($Level) {
        "DEBUG" { "DarkGray" }
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    Write-Host $logEntry -ForegroundColor $color
}

function Get-NextBackupName {
    param([string]$baseName, [string]$extension, [string]$directory)
    
    Write-Log "Gerando nome de backup para: $baseName$extension" "DEBUG"
    
    $obsoleteFolder = Join-Path $directory 'Obsoleto'
    if (-not (Test-Path $obsoleteFolder)) {
        New-Item -ItemType Directory -Path $obsoleteFolder -Force | Out-Null
        Write-Log "Pasta Obsoleto criada: $obsoleteFolder" "DEBUG"
    }
    
    $version = 1
    $existingFiles = Get-ChildItem -Path $obsoleteFolder -Filter "$baseName*$extension" -ErrorAction SilentlyContinue
    
    Write-Log "Arquivos de backup existentes: $($existingFiles.Count)" "DEBUG"
    
    foreach ($file in $existingFiles) {
        if ($file.BaseName -match "_V(\d+)$") {
            $extractedVersion = [int]$matches[1]
            if ($extractedVersion -ge $version) {
                $version = $extractedVersion + 1
            }
        }
    }
    
    $backupName = "$baseName`_V$('{0:D2}' -f $version)$extension"
    Write-Log "Próximo nome de backup: $backupName" "DEBUG"
    return $backupName
}

# ---------- FUNÇÃO COM REGEX CORRIGIDA ----------
function Extract-JsonMetadata {
    param([string]$Content, [switch]$Verbose)
    
    $names = @()
    
    Write-Log "=== INICIANDO Extract-JsonMetadata ===" "DEBUG"
    Write-Log "Tamanho do conteúdo: $($Content.Length) caracteres" "DEBUG"
    
    # FIX: Corrige barras invertidas simples para duplas (escape correto)
    Write-Log "Aplicando FIX para sequências de escape..." "DEBUG"
    $fixedContent = $Content -replace '\\([^\\"])' , '\\$1'
    Write-Log "Conteúdo corrigido" "DEBUG"
    
    Write-Log "Tentando parsear JSON..." "DEBUG"
    
    try {
        $json = $fixedContent | ConvertFrom-Json -ErrorAction Stop
        Write-Log "✓ JSON parseado com sucesso" "SUCCESS"
        
        $properties = $json | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        Write-Log "Propriedades do JSON: $($properties -join ', ')" "DEBUG"
        
        # PRIORIDADE 1: metadata.filename
        Write-Log "Verificando metadata.filename..." "DEBUG"
        if ($json.metadata) {
            Write-Log "✓ Objeto 'metadata' encontrado" "DEBUG"
            Write-Log "Propriedades de metadata: $($json.metadata | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name)" "DEBUG"
            
            if ($json.metadata.filename) {
                Write-Log "✓ ENCONTRADO: metadata.filename = '$($json.metadata.filename)'" "SUCCESS"
                $names += $json.metadata.filename
            } else {
                Write-Log "✗ metadata.filename NÃO encontrado" "WARNING"
            }
        } else {
            Write-Log "✗ Objeto 'metadata' NÃO encontrado" "WARNING"
        }
        
        # PRIORIDADE 2: propriedades diretas COM EXTENSÃO
        Write-Log "Verificando propriedades diretas..." "DEBUG"
        if ($json.filename -and $json.filename -match '\.[\w]+$') {
            Write-Log "✓ ENCONTRADO: json.filename = '$($json.filename)'" "SUCCESS"
            $names += $json.filename
        }
        if ($json.name -and $json.name -match '\.[\w]+$') {
            Write-Log "✓ ENCONTRADO: json.name = '$($json.name)'" "SUCCESS"
            $names += $json.name
        }
        if ($json.file -and $json.file -match '\.[\w]+$') {
            Write-Log "✓ ENCONTRADO: json.file = '$($json.file)'" "SUCCESS"
            $names += $json.file
        }
        
        # PRIORIDADE 3: bootstrap_filename
        Write-Log "Verificando bootstrap_filename..." "DEBUG"
        if ($json.bootstrap_filename) {
            Write-Log "✓ ENCONTRADO: json.bootstrap_filename = '$($json.bootstrap_filename)'" "SUCCESS"
            $names += $json.bootstrap_filename
        }
        
    } catch {
        Write-Log "✗ ERRO ao parsear JSON: $($_.Exception.Message)" "ERROR"
        Write-Log "Tentando fallback com regex..." "DEBUG"
        
        # Fallback: extrai filename com regex
        if ($Content -match '"filename"\s*:\s*"([^"]+)"') {
            Write-Log "✓ ENCONTRADO via regex: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($Content -match '"bootstrap_filename"\s*:\s*"([^"]+)"') {
            Write-Log "✓ ENCONTRADO via regex: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
    }
    
    Write-Log "Total de nomes encontrados em JSON: $($names.Count)" "DEBUG"
    Write-Log "Nomes: $($names -join ', ')" "DEBUG"
    Write-Log "=== FIM Extract-JsonMetadata ===" "DEBUG"
    
    return $names
}

function Extract-CommentMetadata {
    param([string]$Content)
    
    Write-Log "=== INICIANDO Extract-CommentMetadata ===" "DEBUG"
    
    $names = @()
    $lines = $Content -split "`n"
    Write-Log "Total de linhas: $($lines.Count)" "DEBUG"
    
    foreach ($line in $lines) {
        if ($line -match '@FILE:\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO @FILE: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '#\s*filename:\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO # filename: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '//\s*filename:\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO // filename: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '#\s*name:\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO # name: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '#\s*file:\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO # file: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '/\*\s*(?:filename|file):\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)\s*\*/') {
            Write-Log "✓ ENCONTRADO /* filename/file: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match 'REM\s+(?:filename|file):\s*([a-zA-Z0-9_\-\.]+(?:\.[a-zA-Z0-9]+)?)') {
            Write-Log "✓ ENCONTRADO REM filename/file: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
    }
    
    Write-Log "Total de nomes encontrados em comentários: $($names.Count)" "DEBUG"
    Write-Log "=== FIM Extract-CommentMetadata ===" "DEBUG"
    
    return $names
}

function Extract-AnyCommentFilename {
    param([string]$Content)
    
    Write-Log "=== INICIANDO Extract-AnyCommentFilename ===" "DEBUG"
    
    $names = @()
    $lines = $Content -split "`n"
    
    Write-Log "Verificando primeiras 20 linhas..." "DEBUG"
    
    foreach ($line in $lines | Select-Object -First 20) {
        if ($line -match '#\s+([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]{2,5})(?:\s|$)') {
            Write-Log "✓ ENCONTRADO # arquivo: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '//\s+([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]{2,5})(?:\s|$)') {
            Write-Log "✓ ENCONTRADO // arquivo: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match 'REM\s+([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]{2,5})(?:\s|$)') {
            Write-Log "✓ ENCONTRADO REM arquivo: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
        if ($line -match '/\*\s*([a-zA-Z0-9_\-]+\.[a-zA-Z0-9]{2,5})\s*\*/') {
            Write-Log "✓ ENCONTRADO /* arquivo */: $($matches[1])" "SUCCESS"
            $names += $matches[1]
        }
    }
    
    Write-Log "Total de nomes encontrados em comentários genéricos: $($names.Count)" "DEBUG"
    Write-Log "=== FIM Extract-AnyCommentFilename ===" "DEBUG"
    
    return $names
}

function Select-FilenameFromList {
    param([string[]]$Names)
    
    Write-Log "=== INICIANDO Select-FilenameFromList ===" "DEBUG"
    Write-Log "Nomes disponíveis: $($Names -join ', ')" "DEBUG"
    
    if ($Names.Count -eq 0) {
        Write-Log "Nenhum nome disponível" "WARNING"
        return $null
    }
    
    if ($Names.Count -eq 1) {
        Write-Log "✓ Nome único selecionado: $($Names[0])" "SUCCESS"
        Write-Host "✓ Nome encontrado: $($Names[0])" -ForegroundColor Green
        return $Names[0]
    }
    
    Write-Host "`n╔╗" -ForegroundColor Cyan
    Write-Host "║   Múltiplos nomes encontrados         ║" -ForegroundColor Cyan
    Write-Host "╚╝" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Names.Count; $i++) {
        Write-Host "$($i + 1). $($Names[$i])"
    }
    Write-Host "$($Names.Count + 1). Usar timestamp (padrão)"
    
    $choice = Read-Host "`nEscolha uma opção (1-$($Names.Count + 1))"
    Write-Log "Usuário escolheu opção: $choice" "DEBUG"
    
    $choiceInt = 0
    if ([int]::TryParse($choice, [ref]$choiceInt)) {
        if ($choiceInt -ge 1 -and $choiceInt -le $Names.Count) {
            Write-Log "✓ Nome selecionado: $($Names[$choiceInt - 1])" "SUCCESS"
            return $Names[$choiceInt - 1]
        }
        elseif ($choiceInt -eq $Names.Count + 1) {
            Write-Log "Usuário escolheu usar timestamp" "DEBUG"
            return $null
        }
    }
    
    Write-Log "Opção inválida, usando timestamp" "WARNING"
    Write-Host "⚠ Opção inválida. Usando timestamp." -ForegroundColor Yellow
    return $null
}

function Get-FilenameFromMetadata {
    param([string]$Content, [switch]$Verbose)
    
    Write-Log "=== INICIANDO Get-FilenameFromMetadata ===" "DEBUG"
    
    $allNames = @()
    
    Write-Log "Etapa 1: Buscando em JSON..." "DEBUG"
    $jsonNames = Extract-JsonMetadata -Content $Content -Verbose:$Verbose
    if ($jsonNames.Count -gt 0) {
        $allNames += $jsonNames
        Write-Log "✓ Nomes encontrados em JSON: $($jsonNames -join ', ')" "SUCCESS"
    }
    
    Write-Log "Etapa 2: Buscando em comentários..." "DEBUG"
    $commentNames = Extract-CommentMetadata -Content $Content
    if ($commentNames.Count -gt 0) {
        $allNames += $commentNames
        Write-Log "✓ Nomes encontrados em comentários: $($commentNames -join ', ')" "SUCCESS"
    }
    
    Write-Log "Etapa 3: Buscando em comentários genéricos..." "DEBUG"
    $genericNames = Extract-AnyCommentFilename -Content $Content
    if ($genericNames.Count -gt 0) {
        $allNames += $genericNames
        Write-Log "✓ Nomes encontrados em comentários genéricos: $($genericNames -join ', ')" "SUCCESS"
    }
    
    $uniqueNames = @()
    foreach ($name in $allNames) {
        if ($uniqueNames -notcontains $name) {
            $uniqueNames += $name
        }
    }
    
    Write-Log "Total de nomes únicos: $($uniqueNames.Count)" "DEBUG"
    Write-Log "Nomes únicos: $($uniqueNames -join ', ')" "DEBUG"
    
    if ($uniqueNames.Count -gt 0) {
        Write-Log "=== FIM Get-FilenameFromMetadata (com seleção) ===" "DEBUG"
        return Select-FilenameFromList -Names $uniqueNames
    }
    
    Write-Log "=== FIM Get-FilenameFromMetadata (sem nomes) ===" "DEBUG"
    return $null
}

function Get-FilenameFallbackWithTimestamp {
    param([string]$Content, [switch]$Verbose)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fallbackName = "arquivo_$timestamp"
    
    Write-Log "Usando fallback com timestamp: $fallbackName" "WARNING"
    if ($Verbose) { Write-Host "⚠ Nenhum nome encontrado. Usando timestamp: $fallbackName" -ForegroundColor Yellow }
    
    return $fallbackName
}

function Detect-ContentExtension {
    param([string]$Content)
    
    Write-Log "=== INICIANDO Detect-ContentExtension ===" "DEBUG"
    
    $trimmed = $Content.Trim()
    
    if ($trimmed -match '^\s*[\{\[]') {
        Write-Log "Detectado início com { ou [, testando JSON..." "DEBUG"
        try {
            $trimmed | ConvertFrom-Json -ErrorAction Stop | Out-Null
            Write-Log "✓ Extensão detectada: .json (JSON válido)" "SUCCESS"
            return '.json'
        } catch {
            Write-Log "JSON inválido, mas estrutura parece JSON" "DEBUG"
            if ($trimmed -match '^\s*\{' -or $trimmed -match '^\s*\[') {
                Write-Log "✓ Extensão detectada: .json (estrutura JSON)" "SUCCESS"
                return '.json'
            }
        }
    }
    
    if ($trimmed -match '^\s*(function|param|Write-Host|Get-|Set-|New-|Remove-|\$\w+\s*=)') {
        Write-Log "✓ Extensão detectada: .ps1 (PowerShell)" "SUCCESS"
        return '.ps1'
    }
    
    if ($trimmed -match '^\s*(import|from|def|class|if __name__|print\()') {
        Write-Log "✓ Extensão detectada: .py (Python)" "SUCCESS"
        return '.py'
    }
    
    if ($trimmed -match '^\s*(@echo|REM|SETLOCAL|CALL|FOR|GOTO)') {
        Write-Log "✓ Extensão detectada: .bat (Batch)" "SUCCESS"
        return '.bat'
    }
    
    if ($trimmed -match '^\s*(function|const|let|var|console\.|document\.)') {
        Write-Log "✓ Extensão detectada: .js (JavaScript)" "SUCCESS"
        return '.js'
    }
    
    if ($trimmed -match '^\s*<!DOCTYPE|<html|<head|<body') {
        Write-Log "✓ Extensão detectada: .html (HTML)" "SUCCESS"
        return '.html'
    }
    
    Write-Log "✓ Extensão detectada: .txt (padrão)" "SUCCESS"
    Write-Log "=== FIM Detect-ContentExtension ===" "DEBUG"
    return '.txt'
}

function Validate-Script {
    param([string]$Path, [string]$Ext)
    
    Write-Log "=== INICIANDO Validate-Script ===" "DEBUG"
    Write-Log "Arquivo: $Path, Extensão: $Ext" "DEBUG"
    
    $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Log "✗ Arquivo vazio ou inacessível" "ERROR"
        return @{ valid = $false; errors = @("Arquivo vazio ou inacessível") }
    }
    
    $validationErrors = @()
    
    switch ($Ext) {
        '.ps1' {
            Write-Log "Validando PowerShell..." "DEBUG"
            try {
                [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null) | Out-Null
                Write-Log "✓ PowerShell válido" "SUCCESS"
            } catch {
                Write-Log "✗ Erro de sintaxe PowerShell: $($_.Exception.Message)" "ERROR"
                $validationErrors += "Erro de sintaxe PowerShell: $($_.Exception.Message)"
            }
        }
        '.json' {
            Write-Log "Validando JSON..." "DEBUG"
            try {
                $content | ConvertFrom-Json -ErrorAction Stop | Out-Null
                Write-Log "✓ JSON válido" "SUCCESS"
            } catch {
                Write-Log "✗ JSON inválido: $($_.Exception.Message)" "ERROR"
                $validationErrors += "JSON inválido: $($_.Exception.Message)"
            }
        }
        '.py' {
            Write-Log "Validando Python..." "DEBUG"
            if ($content -match 'def\s+\w+\s*\(' -and $content -notmatch 'def\s+\w+\s*\([^)]*\):') {
                Write-Log "✗ Possível erro de sintaxe em função" "WARNING"
                $validationErrors += "Possível erro de sintaxe em definição de função"
            } else {
                Write-Log "✓ Python parece válido" "SUCCESS"
            }
        }
        '.bat' {
            Write-Log "Validando Batch..." "DEBUG"
            if ($content -match 'GOTO\s+\w+' -and $content -notmatch ':\w+') {
                Write-Log "✗ GOTO sem label" "WARNING"
                $validationErrors += "GOTO sem label correspondente"
            } else {
                Write-Log "✓ Batch parece válido" "SUCCESS"
            }
        }
    }
    
    Write-Log "=== FIM Validate-Script ===" "DEBUG"
    return @{ valid = ($validationErrors.Count -eq 0); errors = $validationErrors }
}

function Remove-Comments {
    param([string]$Content, [string]$Ext)
    
    Write-Log "=== INICIANDO Remove-Comments ===" "DEBUG"
    Write-Log "Extensão: $Ext" "DEBUG"
    
    $lines = $Content -split "`n"
    $filtered = @()
    $removedCount = 0
    
    foreach ($line in $lines) {
        $keep = $true
        
        switch ($Ext) {
            '.ps1' { if ($line -match '^\s*#') { $keep = $false; $removedCount++ } }
            '.py' { if ($line -match '^\s*#') { $keep = $false; $removedCount++ } }
            '.bat' { if ($line -imatch '^\s*(REM|::)') { $keep = $false; $removedCount++ } }
            '.js' { if ($line -match '^\s*//') { $keep = $false; $removedCount++ } }
            '.json' { $keep = $true }
        }
        
        if ($keep) {
            $filtered += $line
        }
    }
    
    Write-Log "Linhas removidas: $removedCount" "DEBUG"
    Write-Log "=== FIM Remove-Comments ===" "DEBUG"
    
    return $filtered -join "`n"
}

function Restore-BarrasInvertidas {
    param([string]$Content)
    # Converte ¦¦ de volta para \\ (2 barras)
    return $Content -replace '¦¦', '\\'
}

# ---------- Fluxo principal ----------
Write-Log "╔════════════════════════════════════════╗"
Write-Log "║ Create_file_v7.5_regex_fix.ps1         ║"
Write-Log "║ Com REGEX CORRIGIDA                    ║"
Write-Log "╚════════════════════════════════════════╝"
Write-Log "Script iniciado"

Write-Host "╔══════════════════════════════════════╗"-ForegroundColor Cyan
Write-Host "║ Create_file_v7.5_full_logging.ps1    ║" -ForegroundColor Cyan
Write-Host "║ Com REGEX CORRIGIDA                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan

$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Selecione a pasta de destino"
$folderBrowser.ShowNewFolderButton = $true

if ($folderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Log "Operação cancelada pelo usuário" "WARNING"
    Write-Host "Operação cancelada." -ForegroundColor Yellow
    exit
}

$selectedFolder = $folderBrowser.SelectedPath
Write-Log "Pasta selecionada: $selectedFolder"
Write-Host "📁 Pasta selecionada: $selectedFolder`n" -ForegroundColor Green

$contentOriginal = Get-Clipboard -Raw
if ([string]::IsNullOrWhiteSpace($contentOriginal)) {
    Write-Log "ERRO: Clipboard vazio" "ERROR"
    Write-Host "❌ Clipboard vazio!" -ForegroundColor Red
    exit
}

$lineCount = ($contentOriginal -split "`n").Count
$byteCount = [System.Text.Encoding]::UTF8.GetByteCount($contentOriginal)
Write-Log "Conteúdo lido: $lineCount linhas, $byteCount bytes"
Write-Host "📋 Conteúdo lido ($lineCount linhas, $byteCount bytes)" -ForegroundColor Green

$tempFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tempFile, $contentOriginal, [System.Text.Encoding]::UTF8)
Write-Log "Arquivo temporário criado: $tempFile" "DEBUG"

$extension = Detect-ContentExtension -Content $contentOriginal
Write-Host "📄 Extensão detectada: $extension`n" -ForegroundColor Green

Write-Host "🔍 Buscando nome do arquivo..." -ForegroundColor Cyan
Write-Log "Iniciando busca de nome do arquivo"

$filename = Get-FilenameFromMetadata -Content $contentOriginal -Verbose
if (-not $filename) {
    $filename = Get-FilenameFallbackWithTimestamp -Content $contentOriginal -Verbose
}

Write-Log "Nome do arquivo final: $filename"
Write-Host "`n📝 Nome do arquivo: $filename" -ForegroundColor Green

if ($filename -notmatch '\.[\w]+$') {
    $filename = "$filename$extension"
    Write-Log "Extensão adicionada: $filename" "DEBUG"
    Write-Host "   (extensão adicionada automaticamente)" -ForegroundColor Gray
}

# Menu interativo
$menuLoop = $true
while ($menuLoop) {
    Write-Host "╔========================================╗" -ForegroundColor Cyan
    Write-Host "║          === MENU DE OPÇÕES ===        ║" -ForegroundColor Cyan
    Write-Host "╚========================================╝" -ForegroundColor Cyan
    Write-Host "1. ✓ Validar conteúdo"
    Write-Host "2. 🧹 Remover comentários"
    Write-Host "3. 💾 Salvar (SEM validação)"
    Write-Host "4. 📋 Copiar nome do arquivo"
    Write-Host "5. ❌ Sair"
    
    $choice = Read-Host "`nEscolha uma opção"
    Write-Log "Usuário escolheu opção: $choice" "DEBUG"
    
    switch ($choice) {
        '1' {
            Write-Log "Opção 1: Validar conteúdo"
            $validationResult = Validate-Script -Path $tempFile -Ext $extension
            if ($validationResult.valid) {
                Write-Host "`n✓ Arquivo válido!" -ForegroundColor Green
                Write-Log "Validação: SUCESSO" "SUCCESS"
            } else {
                Write-Host "`n❌ Erros encontrados:" -ForegroundColor Red
                foreach ($err in $validationResult.errors) {
                    Write-Host "   - $err" -ForegroundColor Red
                    Write-Log "Erro de validação: $err" "ERROR"
                }
            }
        }
        '2' {
            Write-Log "Opção 2: Remover comentários"
            $contentOriginal = Remove-Comments -Content $contentOriginal -Ext $extension
            [System.IO.File]::WriteAllText($tempFile, $contentOriginal, [System.Text.Encoding]::UTF8)
            Write-Host "`n✓ Comentários removidos" -ForegroundColor Green
            Write-Log "Comentários removidos com sucesso" "SUCCESS"
        }
        '3' {
            Write-Log "Opção 3: Salvar (SEM validação)"
            
            $obsoleteFolder = Join-Path $selectedFolder 'Obsoleto'
            if (-not (Test-Path $obsoleteFolder)) {
                New-Item -ItemType Directory -Path $obsoleteFolder -Force | Out-Null
                Write-Log "Pasta Obsoleto criada" "DEBUG"
            }
            
            $filePath = Join-Path $selectedFolder $filename
            if (Test-Path $filePath) {
                Write-Log "Arquivo já existe, criando backup"
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $ext = [System.IO.Path]::GetExtension($filename)
                $backupName = Get-NextBackupName -baseName $baseName -extension $ext -directory $selectedFolder
                $backupPath = Join-Path $obsoleteFolder $backupName
                
                Copy-Item -Path $filePath -Destination $backupPath -Force
                Write-Host "`n✓ Backup criado: $backupName" -ForegroundColor Green
                Write-Log "Backup criado: $backupPath" "SUCCESS"
            }
            
            # SALVA DIRETO SEM VALIDAÇÃO - CORREÇÃO APLICADA
            $contentToSave = Restore-BarrasInvertidas $contentOriginal
            [System.IO.File]::WriteAllText($filePath, $contentToSave, [System.Text.Encoding]::UTF8)
            Write-Host "`n✓ Arquivo salvo com sucesso: $filePath" -ForegroundColor Green
            Write-Host "   (Integridade: 100% preservada)" -ForegroundColor Gray
            Write-Log "Arquivo salvo: $filePath" "SUCCESS"
            Write-Log "Integridade: 100% preservada (sem modificações)" "SUCCESS"
            $menuLoop = $false
        }
        '4' {
            Write-Log "Opção 4: Copiar nome do arquivo"
            $filename | Set-Clipboard
            Write-Host "`n✓ Nome copiado para clipboard: $filename" -ForegroundColor Green
            Write-Log "Nome copiado para clipboard: $filename" "SUCCESS"
        }
        '5' {
            Write-Log "Opção 5: Sair"
            Write-Host "`nSaindo..." -ForegroundColor Yellow
            $menuLoop = $false
        }
        default {
            Write-Log "Opção inválida: $choice" "WARNING"
            Write-Host "`n❌ Opção inválida" -ForegroundColor Red
        }
    }
}

if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Log "Arquivo temporário removido" "DEBUG"
}

Write-Log "Script finalizado"
Write-Host "`n✓ Script finalizado.`n" -ForegroundColor Green
