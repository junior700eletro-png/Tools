<# 
    Fix_file_v1.ps1

    Fluxo:
    - Lê conteúdo do patch a partir do CLIPBOARD.
    - Primeira linha deve ser: "# nome_do_patch.fix".
    - Salva o .fix em uma pasta temporária.
    - Pergunta a pasta de origem dos scripts (FolderBrowserDialog).
    - Escolhe o script a ser corrigido dentro dessa pasta (OpenFileDialog).
    - Faz backup do script em Subpasta Obsoleto (com _V01, _V02, ...).
    - Aplica substituições definidas no .fix (FIND/REPLACE).
    - Insere comentário no topo do script: "# PATCH_APLICADO: nome.fix em AAAA-MM-DD HH:mm:ss".
    - Copia o .fix para %LOCALAPPDATA%\Scripts_Patch\<NomeDoScript>\timestamp_nome.fix.
#>

Add-Type -AssemblyName System.Windows.Forms

# ---------- Configuração de paths ----------

$localBase = Join-Path $env:LOCALAPPDATA 'Scripts_Patch'

# ---------- Funções auxiliares ----------

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] $Message"
}

function Select-FolderDialog {
    param(
        [string]$Description = "Selecione a pasta"
    )

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $Description
    $dialog.RootFolder  = 'MyComputer'

    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.SelectedPath
    }
    return $null
}

function Select-FileDialog {
    param(
        [string]$Title,
        [string]$InitialDirectory = "",
        [string]$Filter = "Todos os arquivos (*.*)|*.*"
    )

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title  = $Title
    $dialog.Filter = $Filter
    if ($InitialDirectory -and (Test-Path $InitialDirectory)) {
        $dialog.InitialDirectory = $InitialDirectory
    }

    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.FileName
    }
    return $null
}

function Parse-FixFile {
    param(
        [string]$FixPath
    )

    $text = Get-Content $FixPath -Raw
    $lines = $text -split "`r?`n"

    $patches = @()
    $current = $null

    foreach ($line in $lines) {
        if ($line -match '^\s*#PATCH\b') {
            if ($current) {
                $patches += $current
            }
            $current = [ordered]@{
                Find    = $null
                Replace = $null
            }
            continue
        }

        if ($line -match '^\s*FIND:\s*(.*)$') {
            if (-not $current) {
                $current = [ordered]@{ Find = $null; Replace = $null }
            }
            $current.Find = $matches[1]
            continue
        }

        if ($line -match '^\s*REPLACE:\s*(.*)$') {
            if (-not $current) {
                $current = [ordered]@{ Find = $null; Replace = $null }
            }
            $current.Replace = $matches[1]
            continue
        }
    }

    if ($current) {
        $patches += $current
    }

    return $patches
}

function Apply-PatchesToContent {
    param(
        [string]$Content,
        [array]$Patches
    )

    $newContent = $Content

    foreach ($p in $Patches) {
        $find    = $p.Find
        $replace = $p.Replace

        if ([string]::IsNullOrWhiteSpace($find)) {
            continue
        }

        if ($newContent -notlike "*$find*") {
            Write-Log "Aviso: trecho 'FIND:' não encontrado no conteúdo: $find"
        } else {
            Write-Log "Aplicando patch: '$find' -> '$replace'"
        }

        $newContent = $newContent.Replace($find, $replace)
    }

    return $newContent
}

function Ensure-PatchFolder {
    param(
        [string]$ScriptPath
    )

    $scriptBase = [IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptFolder = Join-Path $localBase $scriptBase

    if (-not (Test-Path $scriptFolder)) {
        New-Item -ItemType Directory -Path $scriptFolder -Force | Out-Null
    }

    return $scriptFolder
}

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

# ---------- Fluxo principal (sem menu complexo) ----------

Clear-Host
Write-Host "=== Aplica_Patch.ps1 ===" -ForegroundColor Cyan

# 1) Ler patch do CLIPBOARD

try {
    $clip = Get-Clipboard
} catch {
    Write-Log "Erro ao ler clipboard: $_"
    Read-Host "Pressione Enter para sair"
    exit
}

if ([string]::IsNullOrWhiteSpace($clip)) {
    Write-Log "Clipboard vazio ou inválido. Esperado conteúdo de .fix."
    Read-Host "Pressione Enter para sair"
    exit
}

$clipLines = $clip -split "`r?`n"
if ($clipLines.Count -eq 0) {
    Write-Log "Clipboard não contém linhas para patch."
    Read-Host "Pressione Enter para sair"
    exit
}

$firstLine = $clipLines[0]

if ($firstLine -notmatch '^\s*#\s*(.+\.fix)\s*$') {
    Write-Log "Primeira linha do clipboard não segue o padrão '# nome.fix'."
    Write-Host "Exemplo esperado: # meu_patch.fix" -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit
}

$patchFileName = $matches[1].Trim()
Write-Log "Nome do patch detectado no clipboard: $patchFileName"

# 2) Salvar .fix em arquivo temporário

$tempPatchDir  = Join-Path $env:TEMP "Aplica_Patch"
if (-not (Test-Path $tempPatchDir)) {
    New-Item -ItemType Directory -Path $tempPatchDir -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$tempFixPath = Join-Path $tempPatchDir "$timestamp`_$patchFileName"

$clip | Out-File -FilePath $tempFixPath -Encoding utf8
Write-Log "Patch salvo temporariamente em: $tempFixPath"

# 3) Selecionar pasta de origem dos scripts

$scriptsFolder = Select-FolderDialog -Description "Selecione a pasta onde está o script a ser corrigido"
if (-not $scriptsFolder) {
    Write-Log "Operação cancelada (nenhuma pasta selecionada)."
    Read-Host "Enter para sair"
    exit
}

Write-Log "Pasta de scripts selecionada: $scriptsFolder"

# 4) Selecionar script dentro dessa pasta

$scriptPath = Select-FileDialog -Title "Selecione o script a ser corrigido" `
                                -InitialDirectory $scriptsFolder `
                                -Filter "Scripts PowerShell (*.ps1)|*.ps1|Todos (*.*)|*.*"
if (-not $scriptPath) {
    Write-Log "Operação cancelada (nenhum script selecionado)."
    Read-Host "Enter para sair"
    exit
}

if (-not (Test-Path $scriptPath)) {
    Write-Log "Script não encontrado: $scriptPath"
    Read-Host "Enter para sair"
    exit
}

Write-Log "Script alvo: $scriptPath"

# 5) Ler e interpretar o .fix salvo

$patches = Parse-FixFile -FixPath $tempFixPath
if (-not $patches -or $patches.Count -eq 0) {
    Write-Log "Nenhum bloco #PATCH válido encontrado em: $tempFixPath"
    Read-Host "Enter para sair"
    exit
}

Write-Host "Patches encontrados: $($patches.Count)" -ForegroundColor Green

# 6) Criar backup em pasta Obsoleto (versão controlada)

$scriptDir      = Split-Path $scriptPath -Parent
$scriptName     = [IO.Path]::GetFileName($scriptPath)
$nameWithoutExt = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
$extWithDot     = [IO.Path]::GetExtension($scriptPath)

$obsoletoDir = Join-Path $scriptDir 'Obsoleto'

if (-not (Test-Path $obsoletoDir)) {
    New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
    (Get-Item $obsoletoDir).Attributes = 'Hidden'
    Write-Log "Pasta Obsoleto criada e ocultada: $obsoletoDir"
}

$backupName = Get-NextBackupName -baseName $nameWithoutExt -extension $extWithDot -directory $obsoletoDir
$backupPath = Join-Path $obsoletoDir $backupName

Copy-Item -Path $scriptPath -Destination $backupPath -Force
Write-Log "Backup criado em Obsoleto: $backupPath"

# 7) Aplicar patches ao conteúdo do script

$originalContent = Get-Content $scriptPath -Raw -Encoding utf8
$patchedContent  = Apply-PatchesToContent -Content $originalContent -Patches $patches

# 8) Comentário de auditoria no topo do script

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$auditHeader = "# PATCH_APLICADO: $patchFileName em $now"

if ($patchedContent -notlike "$auditHeader*") {
    $patchedContent = "$auditHeader`n$patchedContent"
}

# 9) Salvar script modificado

$patchedContent | Out-File -FilePath $scriptPath -Encoding utf8
Write-Log "Script atualizado: $scriptPath"

# 10) Copiar patch para %LOCALAPPDATA%\Scripts_Patch\<NomeDoScript>\

$finalPatchFolder = Ensure-PatchFolder -ScriptPath $scriptPath
$finalPatchName   = "$timestamp`_$patchFileName"
$finalPatchPath   = Join-Path $finalPatchFolder $finalPatchName

Copy-Item -Path $tempFixPath -Destination $finalPatchPath -Force
Write-Log "Patch arquivado em: $finalPatchPath"

Write-Host "`nPatch aplicado com sucesso." -ForegroundColor Green
Read-Host "Pressione Enter para sair"

