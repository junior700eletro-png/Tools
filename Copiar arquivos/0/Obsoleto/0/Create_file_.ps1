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

# --- Selecionar pasta de destino via menu ---

$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$folderDialog.Description = "Selecione a pasta de DESTINO onde o arquivo será criado"
$folderDialog.RootFolder = [System.Environment+SpecialFolder]::MyComputer

# opcional: diretorio inicial
#$folderDialog.SelectedPath = $PWD.Path

$form = New-Object System.Windows.Forms.Form
$form.TopMost = $true  # garante que o diálogo apareça em primeiro plano

$dialogResult = $folderDialog.ShowDialog($form)

if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or
    [string]::IsNullOrWhiteSpace($folderDialog.SelectedPath)) {
    Write-Host "Operação cancelada. Nenhuma pasta de destino selecionada." -ForegroundColor Yellow
    return
}

$destRoot = $folderDialog.SelectedPath
Write-Host "Pasta de destino selecionada: $destRoot" -ForegroundColor Cyan

# --------------------------------------------------------------------
# A PARTIR DAQUI, SEU SCRIPT ORIGINAL, USANDO $destRoot EM VEZ DE $PWD
# --------------------------------------------------------------------

try {
    Write-Host ('=' * 50) -ForegroundColor Cyan
    Write-Host "Iniciando processamento do clipboard..." -ForegroundColor Yellow

    $clipboard = [System.Windows.Forms.Clipboard]::GetText()
    if ([string]::IsNullOrWhiteSpace($clipboard)) {
        throw "Clipboard vazio ou inválido."
    }

    $lines = $clipboard -split "`r?`n"
    $firstLine = $lines[0].Trim()

    if ($firstLine -notmatch '^#\s*([\w\-.]+\.[\w]+)\s*$') {
        throw "Primeira linha inválida. Use formato: # nome.txt"
    }

    $filename = $matches[1]

    # Usa a pasta de destino selecionada
    $path = Join-Path $destRoot $filename
    Write-Host "Nome do arquivo extraído: $filename" -ForegroundColor Green
    Write-Host "Caminho completo de destino: $path" -ForegroundColor Green

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
        throw "Conteúdo processado vazio (apenas comentários?)."
    }

    # Pasta Obsoleto na MESMA pasta do arquivo criado
    $obsoletoDir = Join-Path $destRoot 'Obsoleto'

    if (Test-Path $path) {
        Write-Host "Arquivo existe. Preparando backup em Obsoleto..." -ForegroundColor Yellow

        if (-not (Test-Path $obsoletoDir)) {
            New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
            (Get-Item $obsoletoDir).Attributes = 'Hidden'
            Write-Host "Pasta Obsoleto criada e ocultada em: $obsoletoDir" -ForegroundColor Green
        }

        $nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($filename)
        $ext = [IO.Path]::GetExtension($filename)
        $backupName = Get-NextBackupName -baseName $nameWithoutExt -extension $ext -directory $obsoletoDir
        $backupPath = Join-Path $obsoletoDir $backupName

        Copy-Item -Path $path -Destination $backupPath -Force
        Remove-Item -Path $path -Force
        Write-Host "Backup criado: $backupName" -ForegroundColor Green
    }
    else {
        Write-Host "Arquivo não existe no destino. Criando diretamente..." -ForegroundColor Yellow
    }

    [System.IO.File]::WriteAllText($path, $content, [System.Text.Encoding]::UTF8)

    Write-Host "Sucesso! Arquivo salvo: $filename" -ForegroundColor Green
    Write-Host ('=' * 50) -ForegroundColor Cyan
}
catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ('=' * 50) -ForegroundColor Red
    exit 1
}