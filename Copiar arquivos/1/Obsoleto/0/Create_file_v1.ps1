# Create_file_v1.ps1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-NextBackupName {
    param(
        [string]$baseName,
        [string]$extension,
        [string]$directory
    )

    $escapedBase = [regex]::Escape($baseName)
    $escapedExt  = [regex]::Escape($extension)
    $pattern = "^${escapedBase}_V(\d{2})${escapedExt}$"

    $numbers = Get-ChildItem -Path $directory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $pattern } |
        ForEach-Object {
            [int]([regex]::Match($_.Name, $pattern).Groups[1].Value)
        }

    $nextNum = if ($numbers) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
    return ('{0}_V{1:D2}{2}' -f $baseName, $nextNum, $extension)
}

function Test-FileSyntax {
    param([string]$content, [string]$extension)
    
    switch ($extension.ToLower()) {
        '.json' { 
            # Fallback PS 5.1: try/catch com ConvertFrom-Json
            try {
                $null = $content | ConvertFrom-Json -ErrorAction Stop
                return $true
            }
            catch {
                return $false
            }
        }
        '.ps1' { 
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$errors)
            return (-not $errors -or $errors.Count -eq 0) 
        }
        { $_ -in @('.bat', '.cmd') } {
            # BAT igual (regex básico)
            $errors = $content -split "`r?`n" | Where-Object { 
                $trim = $_.Trim()
                -not ($trim -match '^\s*(?:@|echo|rem|pause|exit|goto|if|for|set|call|cls|title|color|mode)\b' -or [string]::IsNullOrWhiteSpace($trim))
            }
            return $errors.Count -eq 0
        }
        '.py' { 
            # PY igual (indent/blocos)
            $lines = $content -split "`r?`n"
            $indentLevels = 0
            foreach ($line in $lines) {
                $trimmed = $line.TrimStart()
                if ($trimmed -match '^(def|class|if|for|while)\s') {
                    $indentLevels++
                } elseif ($trimmed -match '^(else|elif):?\s') {
                    if ($indentLevels -le 0) { return $false }
                } elseif (-not [string]::IsNullOrWhiteSpace($trimmed) -and -not $trimmed.StartsWith('#')) {
                    if ($line -match '^\s{4,}' -and $indentLevels -eq 0) { return $false }
                }
            }
            return $true
        }
        default { return $true }
    }
}

# --- Selecionar pasta de destino ---
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Selecione a pasta de DESTINO onde o arquivo será criado"
$folderDialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer

$form = New-Object System.Windows.Forms.Form
$form.TopMost = $true

$dialogResult = $folderDialog.ShowDialog($form)

if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or
    [string]::IsNullOrWhiteSpace($folderDialog.SelectedPath)) {
    Write-Host "Operação cancelada. Nenhuma pasta de destino selecionada." -ForegroundColor Yellow
    return
}

$destRoot = $folderDialog.SelectedPath
if (-not (Test-Path $destRoot -PathType Container)) {
    throw "Pasta de destino inválida ou inacessível."
}

Write-Host "Pasta de destino selecionada: $destRoot" -ForegroundColor Cyan

try {
    Write-Host ('=' * 50) -ForegroundColor Cyan
    Write-Host "Iniciando processamento do clipboard..." -ForegroundColor Yellow

    # PASSO 1: Copiar clipboard para TEMP .tmp IMEDIATAMENTE
    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ([string]::IsNullOrWhiteSpace($clipboard)) {
        throw "Clipboard vazio ou inválido."
    }

    $tempFile = [System.IO.Path]::GetTempFileName() + '.tmp'
    [System.IO.File]::WriteAllText($tempFile, $clipboard, [System.Text.Encoding]::UTF8)
    Write-Host "Conteúdo salvo em TEMP: $tempFile" -ForegroundColor Gray

    # Ler do TEMP para processamento
    $lines = [System.IO.File]::ReadAllLines($tempFile, [System.Text.Encoding]::UTF8)
    $firstLine = $lines[0].Trim()

    if ($firstLine -notmatch '^#\s*(.+?\.\w+)\s*$') {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    throw "Primeira linha inválida. Use: '# nome do arquivo.txt' (espaços OK)"
    }

    $filename = $matches[1].Trim()
    
    Write-Host "=== DEBUG PRIMEIRA LINHA ===" -ForegroundColor Magenta
    Write-Host "Raw: '$firstLine'" -ForegroundColor White
    Write-Host "Match? $($firstLine -match '^#\s*(.+?\.\w+)\s*$')" -ForegroundColor White
    if ($matches) { Write-Host "Capturado: '$($matches[1])'" -ForegroundColor Green }
    Write-Host "========================" -ForegroundColor Magenta
    
    $path = Join-Path $destRoot $filename
    Write-Host "Nome do arquivo extraído: $filename" -ForegroundColor Green
    Write-Host "Caminho completo de destino: $path" -ForegroundColor Green

    # Processar comentários
    $commentPrefixes = @('#', ';', '//', 'REM', 'rem')
    $processedLines = foreach ($line in $lines) {
        $trimmedStart = $line -replace '^\s+', ''
        $isComment = $false
        foreach ($prefix in $commentPrefixes) {
            if ($trimmedStart.StartsWith($prefix)) {
                $isComment = $true
                break
            }
        }
        if (-not $isComment) { $line }
    }

    $content = $processedLines -join "`r`n"
    if ([string]::IsNullOrWhiteSpace($content)) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        throw "Conteúdo processado vazio (apenas comentários?)."
    }

    # PASSO 2: VALIDAÇÃO EXTRA por extensão
    $ext = [IO.Path]::GetExtension($filename)
    if (-not (Test-FileSyntax -content $content -extension $ext)) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        throw "Sintaxe inválida para $ext. Verifique o conteúdo."
    }
    Write-Host "Validação de sintaxe OK para $ext" -ForegroundColor Green

    # Backup se existir
    $obsoletoDir = Join-Path $destRoot 'Obsoleto'
    if (Test-Path $path) {
        Write-Host "Arquivo existe. Preparando backup em Obsoleto..." -ForegroundColor Yellow

        if (-not (Test-Path $obsoletoDir)) {
            New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
            (Get-Item $obsoletoDir).Attributes = 'Hidden'
            Write-Host "Pasta Obsoleto criada e ocultada: $obsoletoDir" -ForegroundColor Green
        }

        $nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($filename)
        $backupName = Get-NextBackupName -baseName $nameWithoutExt -extension $ext -directory $obsoletoDir
        $backupPath = Join-Path $obsoletoDir $backupName

        Copy-Item -Path $path -Destination $backupPath -Force
        Remove-Item -Path $path -Force
        Write-Host "Backup criado: $backupName" -ForegroundColor Green
    } else {
        Write-Host "Arquivo não existe. Criando diretamente..." -ForegroundColor Yellow
    }

    # PASSO 3: SALVAR ARQUIVO FINAL do processado
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)

    # Limpeza TEMP
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    Write-Host "Sucesso! Arquivo salvo: $filename" -ForegroundColor Green
    Write-Host ('=' * 50) -ForegroundColor Cyan
}
catch {
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ('=' * 50) -ForegroundColor Red
    exit 1
}