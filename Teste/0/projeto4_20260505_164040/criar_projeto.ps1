
Add-Type -AssemblyName System.Windows.Forms

$desktop = [Environment]::GetFolderPath('Desktop')
$logPath = Join-Path $desktop "file_saver_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Color = "Green")
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $logPath -Value $logEntry -Encoding UTF8
    Write-Host $logEntry -ForegroundColor $Color
}

try {
    Write-Host "╔╗" -ForegroundColor Cyan
    Write-Host "║          Salvar Arquivo do Clipboard                        ║" -ForegroundColor Cyan
    Write-Host "╚╝" -ForegroundColor Cyan
    Write-Host ""
    
    $ScriptPath = $PSScriptRoot
    if (-not $ScriptPath) {
        $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    
    Write-Log "📂 Pasta: $ScriptPath"
    
    $clipboard = Get-Clipboard | Out-String
    
    if ([string]::IsNullOrWhiteSpace($clipboard)) {
        Write-Log "❌ Clipboard vazio!" "Red"
        exit 1
    }
    
    Write-Log "📋 Clipboard lido ($($clipboard.Length) caracteres)"
    
    $lines = $clipboard -split "`r?`n"
    $firstLine = $lines[0].Trim()
    
    Write-Log "Primeira linha: $firstLine"
    
    if ($firstLine -notmatch '^#\s+(.+\..+)$') {
        Write-Log "❌ Formato inválido! Primeira linha deve ser: # arquivo.xx" "Red"
        Write-Host ""
        Write-Host "Exemplos válidos:" -ForegroundColor Yellow
        Write-Host "  # main.py" -ForegroundColor White
        Write-Host "  # script.bat" -ForegroundColor White
        Write-Host "  # config.json" -ForegroundColor White
        exit 1
    }
    
    $filename = $matches[1]
    $filepath = Join-Path $ScriptPath $filename
    
    Write-Log "📁 Nome do arquivo: $filename"
    
    $content = $lines[1..($lines.Count-1)] -join "`r`n"
    
    $commentPrefixes = @('#', ';', '//', 'REM', 'rem')
    $processedLines = @()
    
    foreach ($line in ($content -split "`r?`n")) {
        $trimmed = $line.TrimStart()
        $isComment = $false
        
        foreach ($prefix in $commentPrefixes) {
            if ($trimmed.StartsWith($prefix)) {
                $isComment = $true
                break
            }
        }
        
        if (-not $isComment -or $trimmed -eq '') {
            $processedLines += $line
        }
    }
    
    $finalContent = $processedLines -join "`r`n"
    
    if (Test-Path $filepath) {
        Write-Host ""
        Write-Host "⚠️  Arquivo já existe: $filename" -ForegroundColor Yellow
        $response = Read-Host "Deseja sobrescrever? (S/N)"
        
        if ($response -notmatch '^[Ss]') {
            Write-Log "❌ Criação cancelada pelo usuário"
            exit 0
        }
        
        $obsoletoDir = Join-Path $ScriptPath '.obsoleto'
        if (-not (Test-Path $obsoletoDir)) {
            New-Item -ItemType Directory -Path $obsoletoDir -Force | Out-Null
            $obsoletoItem = Get-Item $obsoletoDir
            $obsoletoItem.Attributes = 'Hidden'
        }
        
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
        $ext = [System.IO.Path]::GetExtension($filename)
        $backupName = "${baseName}_V01${ext}"
        
        $counter = 1
        while (Test-Path (Join-Path $obsoletoDir $backupName)) {
            $counter++
            $backupName = "${baseName}_V$($counter.ToString('D2'))${ext}"
        }
        
        $backupPath = Join-Path $obsoletoDir $backupName
        Copy-Item -Path $filepath -Destination $backupPath -Force
        Write-Log "💾 Backup criado: $backupName"
    }
    
    Set-Content -Path $filepath -Value $finalContent -Encoding UTF8 -Force
    
    if (Test-Path $filepath) {
        Write-Host ""
        Write-Host "" -ForegroundColor Green
        Write-Host "✓ Arquivo salvo com sucesso!" -ForegroundColor Green
        Write-Host "" -ForegroundColor Green
        Write-Host ""
        Write-Host "📁 Arquivo: $filename" -ForegroundColor Green
        Write-Host "📂 Pasta: $ScriptPath" -ForegroundColor Green
        Write-Host "📝 Tamanho: $([System.IO.FileInfo]$filepath).Length bytes" -ForegroundColor Green
        Write-Host ""
        
        Write-Log "✓ Arquivo salvo: $filepath"
        
        Start-Process explorer.exe -ArgumentList "/select,`"$filepath`""
    } else {
        Write-Log "❌ Erro ao salvar arquivo!" "Red"
        exit 1
    }
    
} catch {
    Write-Log "❌ ERRO: $($_.Exception.Message)" "Red"
    Write-Log "Linha: $($_.InvocationInfo.ScriptLineNumber)" "Red"
    exit 1
}

Write-Host "Pressione ENTER para fechar..." -ForegroundColor Yellow
Read-Host