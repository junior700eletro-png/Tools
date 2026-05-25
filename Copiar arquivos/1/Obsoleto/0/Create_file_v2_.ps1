# Utilitário para criar arquivo a partir do clipboard com validação, menu,
# suporte a JSON customizado, detecção avançada de nome de arquivo
# e controle de versões em pasta Obsoleto.

Add-Type -AssemblyName System.Windows.Forms

# ---------- Versão de backup em Obsoleto ----------

function Get-NextBackupName {
    param(
        [string]$baseName,
        [string]$extension,  # com ponto, ex: ".ps1"
        [string]$directory
    )

    if ([string]::IsNullOrWhiteSpace($extension)) {
        $extension = ''
    }

    $escapedBase = [regex]::Escape($baseName)
    $escapedExt  = [regex]::Escape($extension)
    $pattern = "^${escapedBase}_V(\d{2})${escapedExt}$"

    $numbers = @()

    Get-ChildItem -Path $directory -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match $pattern) {
            $n = [int]$matches[1]
            $numbers += $n
        }
    }

    if ($numbers.Count -gt 0) {
        $nextNum = ($numbers | Measure-Object -Maximum).Maximum + 1
    } else {
        $nextNum = 1
    }

    $suffix = $nextNum.ToString().PadLeft(2, '0')
    return ($baseName + '_V' + $suffix + $extension)
}

# ---------- Funções de extração de nome ----------

function Extract-FirstLineFilename {
    param(
        [string]$Path,
        [ref]$HeaderLineRemovedContent
    )
    try {
        $allLines = Get-Content -Path $Path
        if ($allLines.Count -gt 0) {
            $firstLine = $allLines[0]

            # Header explícito de nome de arquivo em comentário da PRIMEIRA linha
            # Aceita: "# meu_script.ps1 - texto", "REM meu_script.bat", "// nome.py", "; nome.txt"
            if ($firstLine -match '^\s*(?:#|REM\b|rem\b|//|;|::)\s*([^\s]+\.\w+)') {
                # Aceita, por exemplo:
                #   # meu_script.ps1 - Script
                #   REM meu_script.bat
                #   :: meu_script.bat
                #   // meu_script.py
                #   ; dados.txt
                $HeaderLineRemovedContent.Value = ($allLines | Select-Object -Skip 1) -join "`n"
                return $matches[1].Trim()
            }
        }
    } catch {
        Write-Warning "Erro ao ler primeira linha: $_"
        Write-Log    "Erro ao ler primeira linha: $_"
    }
    return $null
}

# ----------Função: procura nome.ext em qualquer comentário ----------

function Extract-AnyCommentFilename {
    param([string]$Content)

    # Varre todas as linhas, procurando qualquer comentário com algo tipo nome.ext
    # Ex.:
    #   # meu_script.py
    #   REM meu_script.bat
    #   :: meu_script.bat
    #   // meu_script.ps1
    #   ; dados.txt
    $lines = $Content -split "`n"
    $matchesList = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*(?:#|REM\b|rem\b|//|;|::)\s*([^\s]+\.\w+)') {
            $matchesList += $matches[1].Trim()
        }
    }

    return $matchesList
}

function Get-FilenameFallbackWithTimestamp {
    param(
        [string]$Content,
        [switch]$Verbose
    )

    $fn = Get-FilenameFromMetadata -Content $Content -Verbose:$Verbose
    if ($fn) { return $fn }

    if ($Verbose) { Write-Host "Usando fallback com timestamp..." -ForegroundColor Yellow }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fn = "script_$timestamp"
    if ($Verbose) { Write-Host "✓ Fallback: $fn" -ForegroundColor Green }
    Write-Log "Nome por fallback timestamp: $fn"
    return $fn
}

function Extract-JsonMetadata {
    param([string]$Content)
    if ($Content -match '"filename"\s*:\s*"([^"]+\.\w+)"') {
        return $matches[1].Trim()
    }
    return $null
}

function Extract-CommentMetadata {
    param([string]$Content)

    $lines = $Content -split "`n"
    $matchesList = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*(?:#|//|;|REM\b|rem\b|::)?\s*@FILE:\s*(.+\.\w+)') {
            $matchesList += $matches[1].Trim()
        }
    }

    return $matchesList
}

function Extract-AnyCommentFilename {
    param([string]$Content)

    $lines = $Content -split "`n"
    $matchesList = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*(?:#|REM\b|rem\b|//|;|::)\s*([^\s]+\.\w+)') {
            $matchesList += $matches[1].Trim()
        }
    }

    return $matchesList
}

function Extract-CommentMetadata {
    param([string]$Content)

    # Aceita linhas como:
    #   # @FILE: nome.ext
    #   @FILE: nome.ext
    #   // @FILE: nome.ext
    #   ; @FILE: nome.ext
    #   REM @FILE: nome.ext
    #
    # Pode retornar vários nomes para escolha posterior.
    $lines = $Content -split "`n"
    $matchesList = @()

    foreach ($line in $lines) {
        if ($line -match '^\s*(?:#|//|;|REM\b|rem\b)?\s*@FILE:\s*(.+\.\w+)') {
            $matchesList += $matches[1].Trim()
        }
    }

    return $matchesList
}

function Select-FilenameFromList {
    param(
        [string[]]$Names
    )

    if (-not $Names -or $Names.Count -eq 0) {
        return $null
    }

    if ($Names.Count -eq 1) {
        return $Names[0]
    }

    Write-Host "Vários candidatos a nome de arquivo encontrados em @FILE:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Names.Count; $i++) {
        Write-Host ("{0}. {1}" -f ($i + 1), $Names[$i]) -ForegroundColor White
    }

    while ($true) {
        $choice = Read-Host ("Escolha o número desejado (1-{0}, ou Enter para cancelar)" -f $Names.Count)
        if ([string]::IsNullOrWhiteSpace($choice)) {
            return $null
        }
        if ($choice -as [int] -and $choice -ge 1 -and $choice -le $Names.Count) {
            return $Names[$choice - 1]
        }
        Write-Host "Opção inválida." -ForegroundColor Red
    }
}
function Get-FilenameFromMetadata {
    param(
        [string]$Content,
        [switch]$Verbose
    )

    if ($Verbose) { Write-Host "Buscando metadata JSON (\"filename\")..." -ForegroundColor Yellow }
    $fn = Extract-JsonMetadata $Content
    if ($fn) {
        if ($Verbose) { Write-Host "✓ JSON: $fn" -ForegroundColor Green }
        Write-Log "Nome detectado via JSON: $fn"
        return $fn
    }

    if ($Verbose) { Write-Host "Buscando @FILE nos comentários..." -ForegroundColor Yellow }
    $allFromComments = Extract-CommentMetadata $Content
    if ($allFromComments -and $allFromComments.Count -gt 0) {
        $chosen = Select-FilenameFromList -Names $allFromComments
        if ($chosen) {
            if ($Verbose) { Write-Host "✓ Comentário (@FILE): $chosen" -ForegroundColor Green }
            Write-Log "Nome selecionado via @FILE: $chosen"
            return $chosen
        } else {
            if ($Verbose) { Write-Host "Nenhum nome selecionado a partir de @FILE." -ForegroundColor Yellow }
        }
    }

    if ($Verbose) { Write-Host "Buscando nome em comentários gerais (#, REM, ::, //, ;)..." -ForegroundColor Yellow }
    $allFromAnyComments = Extract-AnyCommentFilename $Content
    if ($allFromAnyComments -and $allFromAnyComments.Count -gt 0) {
        $chosen2 = Select-FilenameFromList -Names $allFromAnyComments
        if ($chosen2) {
            if ($Verbose) { Write-Host "✓ Comentário (genérico): $chosen2" -ForegroundColor Green }
            Write-Log "Nome selecionado via comentário genérico: $chosen2"
            return $chosen2
        } else {
            if ($Verbose) { Write-Host "Nenhum nome selecionado a partir de comentários genéricos." -ForegroundColor Yellow }
        }
    }

    return $null
}

# ---------- Detecção de extensão ----------

function Detect-ContentExtension {
    param([string]$Content)

    $firstNonEmpty = ($Content -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 10) -join "`n"

    # Python: shebang, def main, imports típicos, indentação com :
    if ($firstNonEmpty -match '^\s*#\s*!/usr/bin/env\s+python' -or
        $firstNonEmpty -match '^\s*import\s+\w+' -or
        $firstNonEmpty -match '^\s*from\s+\w+\s+import\s+' -or
        $firstNonEmpty -match '^\s*def\s+\w+\(') {
        return 'py'
    }

    # PowerShell: param(), Write-Host, $PSVersionTable, function Nome { ... }
    if ($firstNonEmpty -match '^\s*param\(' -or
        $firstNonEmpty -match 'Write-Host' -or
        $firstNonEmpty -match '\$PSVersionTable' -or
        $firstNonEmpty -match '^\s*function\s+\w+\s*\{' -or
        $firstNonEmpty -match '^\s*\[CmdletBinding\(') {
        return 'ps1'
    }

    # BAT / CMD: @echo off, goto, REM etc.
    if ($firstNonEmpty -match '^\s*@echo\s+off' -or
        $firstNonEmpty -match '^\s*REM\s' -or
        $firstNonEmpty -match '^\s*goto\s+\w+') {
        return 'bat'
    }

    # JSON: começa com { ou [ e tem : depois
    if ($firstNonEmpty -match '^\s*[\{\[]' -and $Content -match '":\s*') {
        return 'json'
    }

    return 'txt'
}

# ---------- Validação de conteúdo ----------

function Validate-Script {
    param([string]$Path, [string]$Ext)

    switch ($Ext.ToLower()) {
        'ps1' {
            try {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
                if ($errors -and $errors.Count -gt 0) {
                    Write-Host "❌ Erros de sintaxe PS1:" -ForegroundColor Red
                    $errors | ForEach-Object {
                        Write-Host " - $($_.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "✓ PS1 válido (sintaxe)" -ForegroundColor Green
                }
            } catch {
                Write-Host "❌ Erro PS1: $_" -ForegroundColor Red
            }
        }
        'json' {
            Validate-AndFix-Json $Path
        }
        'bat' {
            Write-Host "✓ BAT básico OK (nenhuma validação profunda aplicada)" -ForegroundColor Green
        }
        'py' {
            Write-Host "✓ PY básico OK (sem validação de sintaxe profunda)" -ForegroundColor Green
        }
        default {
            Write-Host "✓ Tipo $Ext sem validação específica" -ForegroundColor Green
        }
    }
}

function Validate-AndFix-Json {
    param([string]$Path)
    try {
        $raw = Get-Content $Path -Raw
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        Write-Host "✓ JSON válido" -ForegroundColor Green
    } catch {
        Write-Host "❌ JSON inválido: $_" -ForegroundColor Red
    }
}

# ---------- Expansão de JSON customizado (files[].path/content) ----------

function Expand-CustomJsonProject {
    param(
        [string]$JsonPath,
        [string]$TargetRoot
    )

    try {
        $raw = Get-Content $JsonPath -Raw
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop

        if (-not $obj.files) {
            Write-Host "JSON não possui propriedade 'files'. Nada a expandir." -ForegroundColor Yellow
            return
        }

        # Define subpasta base: project_name ou nome do JSON
        $projectFolderName = $obj.project_name
        if ([string]::IsNullOrWhiteSpace($projectFolderName)) {
            $projectFolderName = [IO.Path]::GetFileNameWithoutExtension($JsonPath)
        }

        $projectRoot = Join-Path $TargetRoot $projectFolderName
        if (-not (Test-Path $projectRoot)) {
            New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
        }

        Write-Host "Expandindo projeto JSON em: $projectRoot" -ForegroundColor Cyan

        foreach ($file in $obj.files) {
            $relPath = $file.path
            $content = $file.content

            if ([string]::IsNullOrWhiteSpace($relPath)) {
                Write-Host " - Item sem 'path', ignorando." -ForegroundColor Yellow
                continue
            }

            $normalizedRelPath = $relPath -replace '\\\\', '\'
            $fullPath = Join-Path $projectRoot $normalizedRelPath

            $dir = Split-Path $fullPath -Parent
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }

            if ($content -is [string]) {
                $decoded = $content -replace '\\n', "`n"
            } else {
                $decoded = [string]$content
            }

            $decoded | Out-File -FilePath $fullPath -Encoding utf8 -Force
            Write-Host " - Criado: $fullPath" -ForegroundColor Green
        }

        Write-Host "Expansão de projeto JSON concluída." -ForegroundColor Cyan
    } catch {
        Write-Host "❌ Falha ao processar JSON customizado: $_" -ForegroundColor Red
    }
}

# ---------- Remoção de comentários ----------

function Remove-Comments {
    param([string]$Content, [string]$Ext)

    $lines = $Content -split "`n"
    $filtered = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        switch ($Ext.ToLower()) {
            'ps1' {
                # Header já foi tratado antes; aqui removemos comentários normais
                if (-not $trimmed.StartsWith('#')) {
                    $filtered += $line
                }
            }
            'py'  {
                if (-not $trimmed.StartsWith('#')) {
                    $filtered += $line
                }
            }
            'bat' {
                if (-not ($trimmed.StartsWith('REM') -or $trimmed.StartsWith('@REM'))) {
                    $filtered += $line
                }
            }
            default {
                $filtered += $line
            }
        }
    }

    return $filtered -join "`n"
}

# ---------- Fluxo principal ----------

Write-Host "Create_file_v2.ps1 - Criando arquivo a partir do clipboard" -ForegroundColor Cyan

# 1. Selecionar pasta
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Selecione a pasta de destino"
$folderBrowser.RootFolder = 'MyComputer'

if ($folderBrowser.ShowDialog() -ne 'OK') {
    Write-Host "Operação cancelada." -ForegroundColor Red
    exit
}

$targetFolder = $folderBrowser.SelectedPath
Write-Host "Pasta selecionada: $targetFolder" -ForegroundColor Green

# 2. Ler clipboard
$contentOriginal = Get-Clipboard
if ([string]::IsNullOrWhiteSpace($contentOriginal)) {
    Write-Host "Clipboard vazio ou inválido." -ForegroundColor Red
    exit
}

# 3. Salvar em TEMP e recarregar
$tempFile = [System.IO.Path]::GetTempFileName()
$contentOriginal | Out-File -FilePath $tempFile -Encoding utf8
Write-Host "Conteúdo salvo temporariamente em: $tempFile" -ForegroundColor Gray

# Conteúdo que será usado ao longo do fluxo (pode ter header removido)
# Lê todas as linhas para poder preservar a primeira linha original se quiser
$allLines = Get-Content $tempFile -Encoding utf8
$firstLineOriginal = $null
if ($allLines.Count -gt 0) {
    $firstLineOriginal = $allLines[0]
}
$content = $allLines -join "`n"

# 4. Extrair nome do arquivo e, se header existir, remover primeira linha do conteúdo lógico

Write-Host "`nDetectando nome do arquivo..." -ForegroundColor Cyan




$headerRemovedContent = ''
$filename = Extract-HeaderFilename -AllLines $allLines `
                                   -HeaderLineRemovedContent ([ref]$headerRemovedContent) `
                                   -HeaderLineIndex ([ref]$headerLineIndex)

$headerFound = $false
if ($filename) {
    $headerFound = $true
    Write-Host "✓ Header de nome detectado na linha $( $headerLineIndex + 1 ): $filename" -ForegroundColor Green
    Write-Log  "Header de nome detectado na linha $( $headerLineIndex + 1 ): $filename"

    if (-not [string]::IsNullOrWhiteSpace($headerRemovedContent)) {
        $content = $headerRemovedContent
    }
} else {
    Write-Host "❌ Nenhum header de nome encontrado nas primeiras linhas" -ForegroundColor Yellow
    Write-Log  "Nenhum header de nome; usando metadados/timestamp."
    $filename = Get-FilenameFallbackWithTimestamp -Content $content -Verbose
}

# Proteção extra: se ainda vier vazio por algum bug, força fallback
if (-not $filename) {
    Write-Host "⚠ Nome ainda vazio após metadados. Usando fallback com timestamp." -ForegroundColor Yellow
    Write-Log  "Nome vazio após metadados, forçando fallback."
    $filename = Get-FilenameFallbackWithTimestamp -Content $content -Verbose
}



# 5. Detectar extensão se não tiver
if ($filename -notmatch '\.\w+$') {
    $ext = Detect-ContentExtension -Content $content
    Write-Host "Extensão detectada: .$ext" -ForegroundColor Magenta
    $filename = "$filename.$ext"
}

$proposedPath = Join-Path $targetFolder $filename
Write-Host "`nArquivo proposto: $proposedPath" -ForegroundColor Cyan

# ---------- Menu interativo ----------

$exit = $false

do {
    Clear-Host
    Write-Host "=== MENU Create_file_v2 ===" -ForegroundColor Cyan

    Write-Host "Pasta destino : $targetFolder" -ForegroundColor White
    Write-Host "Nome detectado: $filename" -ForegroundColor White
    Write-Host "Temp file     : $tempFile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "1. Validar conteúdo" -ForegroundColor White
    Write-Host "2. Remover comentários (cria _clean.tmp)" -ForegroundColor White
    Write-Host "3. Gravar em: $proposedPath (com backup em Obsoleto)" -ForegroundColor White
    Write-Host "4. Copiar nome para clipboard" -ForegroundColor White
    Write-Host "5. Expandir JSON customizado (files[].path/content)" -ForegroundColor White
    Write-Host "6. Sair" -ForegroundColor White
    
    $choice = Read-Host "Escolha (1-6)"

    switch ($choice) {
        '1' {
            $ext = [System.IO.Path]::GetExtension($filename).TrimStart('.')
            Validate-Script -Path $tempFile -Ext $ext
            Read-Host "Pressione Enter para continuar"
        }
        '2' {
            $ext = [System.IO.Path]::GetExtension($filename).TrimStart('.')
            $cleanContent = Remove-Comments -Content $content -Ext $ext
            $cleanTemp = $tempFile -replace '\.tmp$', '_clean.tmp'
            $cleanContent | Out-File -FilePath $cleanTemp -Encoding utf8
            Set-Clipboard $cleanContent
            Write-Host "✓ Comentários removidos em: $cleanTemp" -ForegroundColor Green
            Write-Host "Conteúdo limpo copiado para clipboard" -ForegroundColor Green
            Read-Host "Pressione Enter para continuar"
        }
        '3' {
            $ext = [System.IO.Path]::GetExtension($filename).TrimStart('.')

            # Pergunta se quer re-inserir a linha de header, caso ela tenha sido detectada
            $finalContent = $content
            if ($headerFound -and $firstLineOriginal) {
                $resp = Read-Host "Adicionar a primeira linha original no topo do arquivo final? (S/N)"
                if ($resp -eq 'S' -or $resp -eq 's') {
                    # Reinsere a linha original completa, ex:
                    # "# meu_script.ps1 - Script de teste"
                    $finalContent = "$firstLineOriginal`n$finalContent"
                }
            }

            # Grava o conteúdo final em um arquivo temporário dedicado à validação/gravação
            $finalTemp = [System.IO.Path]::GetTempFileName()
            $finalContent | Out-File -FilePath $finalTemp -Encoding utf8

            Validate-Script -Path $finalTemp -Ext $ext

            # Controle de versões em Obsoleto
            $confirm = Read-Host "Confirmar gravação em $proposedPath? (S/N)"
            if ($confirm -eq 'S' -or $confirm -eq 's') {
                $destPath = $proposedPath
                $obsoletoDir = Join-Path $targetFolder 'Obsoleto'

                if (Test-Path $destPath) {
                    Write-Host "Arquivo já existe. Preparando backup em Obsoleto..." -ForegroundColor Yellow

                    if (-not (Test-Path $obsoletoDir)) {
                        New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
                        (Get-Item $obsoletoDir).Attributes = 'Hidden'
                        Write-Host "Pasta Obsoleto criada e ocultada: $obsoletoDir" -ForegroundColor Green
                    }

                    $nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($filename)
                    $extWithDot    = [IO.Path]::GetExtension($filename)   # isso retorna ".ps1"
                    $backupName    = Get-NextBackupName -baseName $nameWithoutExt -extension $extWithDot -directory $obsoletoDir
                    $backupPath    = Join-Path $obsoletoDir $backupName

                    Copy-Item -Path $destPath -Destination $backupPath -Force
                    Write-Host "Backup criado: $backupPath" -ForegroundColor Green
                }

                Copy-Item -Path $finalTemp -Destination $destPath -Force
                Write-Host "✓ Arquivo salvo: $destPath" -ForegroundColor Green
            }

            Remove-Item $finalTemp -Force -ErrorAction SilentlyContinue
            Read-Host "Pressione Enter para continuar"
        }
        '4' {
            Set-Clipboard $filename
            Write-Host "✓ Nome '$filename' copiado para clipboard" -ForegroundColor Green
            Read-Host "Pressione Enter para continuar"
        }
        '5' {
            $ext = [System.IO.Path]::GetExtension($filename).TrimStart('.')
            if ($ext -ne 'json') {
                Write-Host "Esta opção é específica para arquivos JSON." -ForegroundColor Yellow
            } else {
                Expand-CustomJsonProject -JsonPath $tempFile -TargetRoot $targetFolder
            }
            Read-Host "Pressione Enter para continuar"
        }
        '6' { $exit = $true }
        default {
            Write-Host "Opção inválida!" -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while (-not $exit)

# ---------- Limpeza ----------

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Write-Host "Sessão finalizada." -ForegroundColor Cyan
