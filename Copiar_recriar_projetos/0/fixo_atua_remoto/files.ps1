Add-Type -AssemblyName System.Windows.Forms

# Função para obter o próximo nome de backup com versão

function Get-NextBackupName {
    param(
        [string]$baseName,
        [string]$extension,
        [string]$directory
    )

    $pattern = "^${baseName}_V(\d{2})$"
    $files = Get-ChildItem -Path $directory -ErrorAction SilentlyContinue | Where-Object {
        $_.BaseName -match $pattern -and $_.Extension -eq $extension
    }

    $numbers = $files | ForEach-Object {
        [int]([regex]::Match($_.BaseName, $pattern).Groups[1].Value)
    } | Sort-Object

    $nextNum = if ($numbers) { $numbers[-1] + 1 } else { 1 }
    return "${baseName}_V{0:D2}${extension}" -f $nextNum
}

# Comentários mantidos/explicados para trechos corrigidos conforme regras
# CORRIGIDO: Sempre copiar + deletar, nunca mover
# CORRIGIDO: Pasta Obsoleto criada apenas se necessário e marcada como oculta
# CORRIGIDO: Versões incrementais V01, V02... apenas se arquivo existir

try {
    Write-Host "$( '=' * 50 )" -ForegroundColor Cyan
    Write-Host "Iniciando processamento do clipboard..." -ForegroundColor Yellow

    # Ler clipboard
    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ([string]::IsNullOrWhiteSpace($clipboard)) {
        throw "Clipboard vazio ou inválido."
    }

    # Extrair nome do arquivo da primeira linha (# nome.txt)
    $lines = $clipboard -split "`r?`n"
    $firstLine = $lines[0].Trim()
    if ($firstLine -notmatch '^#\s*([\w\-.]+\.[\w]+)\s*$') {
        throw "Primeira linha inválida. Use formato: # nome.txt"
    }
    $filename = $matches[1]
    $path = Join-Path $PWD.Path $filename

    Write-Host "Nome do arquivo extraído: $filename" -ForegroundColor Green

    # Regex/Processar: remover comentários (#, ;, //, REM, rem)
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
        if (-not $isComment) {
            $line
        }
    }

    $content = $processedLines -join "`r`n"
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Conteúdo processado vazio (apenas comentários?)."
    }

    # Bloco principal IF/ELSE conforme regras
    $obsoletoDir = Join-Path $PWD.Path 'Obsoleto'

    if (Test-Path $path) {
        Write-Host "Arquivo existe. Preparando backup em Obsoleto..." -ForegroundColor Yellow

        # Verificar/criar pasta Obsoleto oculta
        if (-not (Test-Path $obsoletoDir)) {
            New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
            $obsoletoItem = Get-Item $obsoletoDir
            $obsoletoItem.Attributes = 'Hidden'
            Write-Host "Pasta Obsoleto criada e ocultada." -ForegroundColor Green
        }

        # CORRIGIDO: Gerar próxima versão
        $nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($filename)
        $ext = [IO.Path]::GetExtension($filename)
        $backupName = Get-NextBackupName -baseName $nameWithoutExt -extension $ext -directory $obsoletoDir
        $backupPath = Join-Path $obsoletoDir $backupName

        # Copiar + deletar (nunca mover)
        Copy-Item -Path $path -Destination $backupPath -Force
        Remove-Item -Path $path -Force
        Write-Host "Backup criado: $backupName" -ForegroundColor Green
    } else {
        Write-Host "Arquivo não existe. Criando diretamente..." -ForegroundColor Yellow
    }

    # Criar/salvar novo arquivo em UTF8
    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)

    Write-Host "Sucesso! Arquivo salvo: $filename" -ForegroundColor Green
    Write-Host "$( '=' * 50 )" -ForegroundColor Cyan

} catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "$( '=' * 50 )" -ForegroundColor Red
    exit 1
}