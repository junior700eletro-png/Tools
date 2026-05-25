# Fix_File_v2.ps1
# Fluxo completo e simplificado:
# - Lê patch do clipboard
# - Salva .fix temporário
# - Pede script alvo via Windows Forms
# - Valida TODOS os FIND antes de aplicar
# - Se falhar: NÃO altera o script, só arquiva o .fix
# - Se passar: backup em Obsoleto, atualiza script, arquiva o .fix

Add-Type -AssemblyName System.Windows.Forms

Write-Host "Fix_File_v2.ps1 - Aplicando patch a partir do clipboard (validação total de FIND)" -ForegroundColor Cyan

# 1) Ler conteúdo do patch a partir do clipboard
$clip = Get-Clipboard -Raw
if ([string]::IsNullOrWhiteSpace($clip)) {
    Write-Host "Clipboard vazio ou inválido. Nenhum patch para aplicar." -ForegroundColor Red
    exit 1
}

# 2) Descobrir um nome para o patch (primeira linha com 'PATCH' ou fallback)
$primeiraLinha = ($clip -split "`r?`n" | Select-Object -First 1).Trim()
$patchName = "Patch_Manual"

if ($primeiraLinha -match 'PATCH[^\w]*(.+)$') {
    $patchName = $matches[1].Trim()
} elseif ($primeiraLinha -ne "") {
    $patchName = $primeiraLinha
}

# Sanitizar para nome de arquivo
$patchNameSanitized = ($patchName -replace '[\\/:*?"<>|]', '_')
if ([string]::IsNullOrWhiteSpace($patchNameSanitized)) {
    $patchNameSanitized = "Patch_Manual"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# 3) Salvar .fix temporário em pasta de trabalho do Fix_File
$baseTempDir = Join-Path $env:LOCALAPPDATA "Aplica_Patch"
if (-not (Test-Path $baseTempDir)) {
    New-Item -Path $baseTempDir -ItemType Directory -Force | Out-Null
}

$tmpFixName = "{0}_{1}.fix" -f $timestamp, $patchNameSanitized
$tmpFixPath = Join-Path $baseTempDir $tmpFixName

$clip | Out-File -FilePath $tmpFixPath -Encoding UTF8
Write-Host ("[{0}] Patch salvo temporariamente em: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $tmpFixPath) -ForegroundColor Gray

# 4) Selecionar pasta de scripts e script alvo (Windows Forms)

$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Selecione a pasta de scripts onde está o arquivo .ps1 a ser patchado"
$folderBrowser.RootFolder  = "MyComputer"

if ($folderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada. Nenhuma pasta selecionada." -ForegroundColor Yellow
    exit 1
}

$scriptFolder = $folderBrowser.SelectedPath
Write-Host ("[{0}] Pasta de scripts selecionada: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $scriptFolder) -ForegroundColor Green

$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.Title  = "Selecione o script .ps1 alvo do patch"
$ofd.Filter = "Scripts PowerShell (*.ps1)|*.ps1|Todos os arquivos (*.*)|*.*"
$ofd.InitialDirectory = $scriptFolder

if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada. Nenhum script selecionado." -ForegroundColor Yellow
    exit 1
}

$targetScriptPath = $ofd.FileName
Write-Host ("[{0}] Script alvo: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $targetScriptPath) -ForegroundColor Green

if (-not (Test-Path $targetScriptPath)) {
    Write-Host "Arquivo alvo não encontrado: $targetScriptPath" -ForegroundColor Red
    exit 1
}

# 5) Ler conteúdo do script alvo e do .fix temporário

$targetFullPath   = (Resolve-Path $targetScriptPath).Path
$originalContent  = Get-Content $targetFullPath -Raw -Encoding UTF8
$patchLines       = Get-Content $tmpFixPath -Encoding UTF8

# 6) Parse do .fix em blocos FIND/REPLACE

$blocks        = @()
$currentFind   = @()
$currentReplace= @()
$mode          = $null  # 'FIND' ou 'REPLACE'

foreach ($line in $patchLines) {
    if ($line -like '#PATCH*') {
        continue
    }

    if ($line -like 'FIND:*') {
        if ($currentFind.Count -gt 0 -or $currentReplace.Count -gt 0) {
            $blocks += [pscustomobject]@{
                Find    = ($currentFind -join "`r`n")
                Replace = ($currentReplace -join "`r`n")
            }
            $currentFind    = @()
            $currentReplace = @()
        }
        $mode = 'FIND'
        continue
    }

    if ($line -like 'REPLACE:*') {
        $mode = 'REPLACE'
        continue
    }

    if ($mode -eq 'FIND') {
        $currentFind += $line
    }
    elseif ($mode -eq 'REPLACE') {
        $currentReplace += $line
    }
}

if ($currentFind.Count -gt 0 -or $currentReplace.Count -gt 0) {
    $blocks += [pscustomobject]@{
        Find    = ($currentFind -join "`r`n")
        Replace = ($currentReplace -join "`r`n")
    }
}

if ($blocks.Count -eq 0) {
    Write-Host "Nenhum bloco FIND/REPLACE encontrado no patch." -ForegroundColor Red
    # Mesmo assim vamos arquivar o .fix mais abaixo
}

Write-Host ("Patches encontrados no arquivo .fix: {0}" -f $blocks.Count) -ForegroundColor Yellow

# 7) Verificar se TODOS os FIND existem no conteúdo original

$missing = @()

foreach ($b in $blocks) {
    if ($originalContent.IndexOf($b.Find, [System.StringComparison]::Ordinal) -lt 0) {
        $snippet = $b.Find.Split("`r`n")[0]
        Write-Host ("[{0}] FIND não encontrado: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $snippet) -ForegroundColor Red
        $missing += $b.Find
    }
}

$aplicarPatch = $true
if ($missing.Count -gt 0 -or $blocks.Count -eq 0) {
    Write-Host "Impossível aplicar patch nesta versão do arquivo: um ou mais trechos FIND não foram encontrados (ou não há FIND/REPLACE)." -ForegroundColor Red
    Write-Host "Nenhuma alteração será feita em:" -ForegroundColor Yellow
    Write-Host "  $targetFullPath" -ForegroundColor Yellow
    $aplicarPatch = $false
}

# 8) Se for para aplicar, faz tudo em memória, backup e grava

if ($aplicarPatch) {
    $newContent = $originalContent

    foreach ($b in $blocks) {
        $newContent = $newContent.Replace($b.Find, $b.Replace)
    }

    if ($newContent -eq $originalContent) {
        Write-Host "Aviso: conteúdo final é idêntico ao original. Nada para gravar." -ForegroundColor Yellow
    }
    else {
        # Criar backup em Obsoleto
        $targetDir  = Split-Path $targetFullPath -Parent
        $targetName = Split-Path $targetFullPath -Leaf

        $obsoletoDir = Join-Path $targetDir 'Obsoleto'
        if (-not (Test-Path $obsoletoDir)) {
            New-Item -Path $obsoletoDir -ItemType Directory -Force | Out-Null
            (Get-Item $obsoletoDir).Attributes = 'Hidden'
            Write-Host ("[{0}] Pasta Obsoleto criada e ocultada: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $obsoletoDir) -ForegroundColor Green
        }

        $baseName = [IO.Path]::GetFileNameWithoutExtension($targetName)
        $ext      = [IO.Path]::GetExtension($targetName)

        $existingBackups = Get-ChildItem -Path $obsoletoDir -Filter ("{0}_V*.ps1" -f $baseName) -ErrorAction SilentlyContinue
        $nextNum = 1
        if ($existingBackups) {
            $nums = @()
            foreach ($bkp in $existingBackups) {
                if ($bkp.BaseName -match '^.+_V(\d{2})$') {
                    $nums += [int]$matches[1]
                }
            }
            if ($nums.Count -gt 0) {
                $nextNum = ($nums | Measure-Object -Maximum).Maximum + 1
            }
        }
        $suffix = $nextNum.ToString().PadLeft(2, '0')
        $backupName = "{0}_V{1}{2}" -f $baseName, $suffix, $ext
        $backupPath = Join-Path $obsoletoDir $backupName

        Copy-Item -Path $targetFullPath -Destination $backupPath -Force
        Write-Host ("[{0}] Backup criado em Obsoleto: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $backupPath) -ForegroundColor Green

        # Gravar novo conteúdo
        $newContent | Out-File -FilePath $targetFullPath -Encoding UTF8
        Write-Host ("[{0}] Script atualizado: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $targetFullPath) -ForegroundColor Cyan
    }
}

# 9) Arquivar .fix definitivo por script (sempre, para diagnóstico)

$patchArchiveBase = Join-Path $env:LOCALAPPDATA "Scripts_Patch"
if (-not (Test-Path $patchArchiveBase)) {
    New-Item -Path $patchArchiveBase -ItemType Directory -Force | Out-Null
}

$scriptKey = [IO.Path]::GetFileNameWithoutExtension($targetFullPath)
$patchArchiveDir = Join-Path $patchArchiveBase $scriptKey
if (-not (Test-Path $patchArchiveDir)) {
    New-Item -Path $patchArchiveDir -ItemType Directory -Force | Out-Null
}

$finalFixName = "{0}_{1}.fix" -f (Get-Date -Format "yyyyMMdd_HHmmss"), $patchNameSanitized
$finalFixPath = Join-Path $patchArchiveDir $finalFixName

Copy-Item -Path $tmpFixPath -Destination $finalFixPath -Force
Write-Host ("[{0}] Patch arquivado em: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $finalFixPath) -ForegroundColor Gray

Write-Host ""
Write-Host "Patch concluído. Pressione Enter para sair..."
[void][System.Console]::ReadLine()

exit 0