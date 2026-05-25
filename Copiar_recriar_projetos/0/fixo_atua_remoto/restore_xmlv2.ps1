# restore_xmlv2.ps1
# Restaura projeto a partir de XML em formato HEX, com suporte a GZip opcional.
# Permite escolher entre carregar o XML de um arquivo ou do Clipboard.

param(
    [switch]$IgnoreSizeMismatch   # se presente, ignora divergência de tamanho (usa só hash)
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression

function HexToBytes {
    param([string]$Hex)
    $len   = $Hex.Length
    $bytes = [byte[]]::new($len / 2)
    for ($i = 0; $i -lt $len; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($Hex.Substring($i, 2), 16)
    }
    return $bytes
}

function Decompress-BytesGZip {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        return [byte[]]::new(0)
    }

    $input  = New-Object System.IO.MemoryStream(,$Bytes)
    $output = New-Object System.IO.MemoryStream
    $gzip   = New-Object System.IO.Compression.GZipStream(
        $input, [System.IO.Compression.CompressionMode]::Decompress
    )
    try {
        $buffer = New-Object byte[] 8192
        while ($true) {
            $read = $gzip.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            $output.Write($buffer, 0, $read)
        }
    }
    finally {
        $gzip.Dispose()
        $input.Dispose()
    }
    return $output.ToArray()
}

# ---------- Escolha da origem: Arquivo ou Clipboard ----------

$choice = [System.Windows.Forms.MessageBox]::Show(
    "Deseja carregar o XML de um ARQUIVO?`n`nSim = Arquivo (OpenFileDialog)`nNão = Clipboard (texto da área de transferência)",
    "Origem do XML",
    [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($choice -eq [System.Windows.Forms.DialogResult]::Cancel) {
    Write-Host "Operação cancelada pelo usuário." -ForegroundColor Yellow
    exit
}

$xmlSource        = $null
$xmlFromClipboard = $false
$xmlPath          = $null

if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
    # ---------- ARQUIVO ----------
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.InitialDirectory = "$env:LOCALAPPDATA\estruturas_XML"
    $ofd.Filter           = "XML|*.xml"
    $ofd.Title            = "Selecione o bootstrap XML (hex + gzip opcional)"

    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Operação cancelada na seleção do arquivo XML." -ForegroundColor Yellow
        exit
    }

    $xmlPath = $ofd.FileName
    if (-not $xmlPath) {
        Write-Host "Nenhum arquivo XML selecionado." -ForegroundColor Yellow
        exit
    }

    try {
        $xmlSource = Get-Content $xmlPath -Raw -Encoding UTF8
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            ("Erro ao ler XML do arquivo:`n{0}`n`n{1}" -f $xmlPath, $_.Exception.Message),
            "Erro"
        ) | Out-Null
        Read-Host "Enter para sair"
        exit
    }
}
else {
    # ---------- CLIPBOARD ----------
    try {
        $clipboardText = Get-Clipboard
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            ("Erro ao acessar o Clipboard:`n{0}" -f $_.Exception.Message),
            "Erro"
        ) | Out-Null
        Read-Host "Enter para sair"
        exit
    }

    if ([string]::IsNullOrWhiteSpace($clipboardText)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Clipboard está vazio ou não contém texto.",
            "Erro"
        ) | Out-Null
        Read-Host "Enter para sair"
        exit
    }

    $xmlSource        = $clipboardText
    $xmlFromClipboard = $true
}

# ---------- Parse do XML ----------

try {
    [xml]$xml = $xmlSource
}
catch {
    $srcInfo = if ($xmlFromClipboard) { "Clipboard" } else { $xmlPath }
    [System.Windows.Forms.MessageBox]::Show(
        ("Erro ao interpretar o XML de {0}:`n`n{1}" -f $srcInfo, $_.Exception.Message),
        "Erro"
    ) | Out-Null
    Read-Host "Enter para sair"
    exit
}

# Nome do projeto
$projName = $xml.project.name
if ([string]::IsNullOrWhiteSpace($projName)) {
    if ($xmlFromClipboard -or -not $xmlPath) {
        $projName = "Projeto_do_Clipboard"
    }
    else {
        $projName = [IO.Path]::GetFileNameWithoutExtension($xmlPath)
    }
}

# ---------- Pasta de destino ----------

$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description  = "Pasta de destino para restaurar '$projName'"
$fbd.SelectedPath = "$env:LOCALAPPDATA\estruturas_XML"

if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada na seleção da pasta de destino." -ForegroundColor Yellow
    exit
}
$dest = $fbd.SelectedPath

# ---------- Cria pastas ----------

Write-Host "Criando pastas..." -ForegroundColor Cyan

foreach ($folder in $xml.project.folders.folder) {
    $folderRel = $folder.InnerText
    if ([string]::IsNullOrWhiteSpace($folderRel)) { continue }

    $fullFolder = Join-Path $dest $folderRel

    if (-not (Test-Path -LiteralPath $fullFolder)) {
        New-Item -ItemType Directory -Path $fullFolder -Force | Out-Null
    }
}

# ---------- Restaura arquivos ----------

$ok    = 0
$falha = 0

$sumOriginalSize = 0
$sumHexSize      = 0

Write-Host "`nProcessando arquivos..." -ForegroundColor Cyan

$totalFiles = $xml.project.files.file.Count
$index      = 0

foreach ($file in $xml.project.files.file) {
    $index++

    $rel         = $file.GetAttribute("path")
    $storedHash  = $file.GetAttribute("hash")
    $encoding    = $file.GetAttribute("encoding")
    $compressed  = $file.GetAttribute("compressed")
    $sizeAttr    = $file.GetAttribute("size")
    $hexSizeAttr = $file.GetAttribute("hexSize")
    $expAttr     = $file.GetAttribute("expansion")
    $chunked     = $file.GetAttribute("chunked")

    # barra de progresso
    $percent = [int](($index / $totalFiles) * 100)
    Write-Progress -Activity "Restaurando arquivos" `
                   -Status   "Processando $index de $totalFiles" `
                   -PercentComplete $percent

    # feedback visual
    if (-not [string]::IsNullOrWhiteSpace($rel)) {
        Write-Host "[$index/$totalFiles] Restaurando: $rel" -ForegroundColor Cyan
    }
    else {
        Write-Host "[$index/$totalFiles] Restaurando: <sem path>" -ForegroundColor Yellow
    }

    if ([string]::IsNullOrWhiteSpace($rel)) {
        Write-Host "  [AVISO] Nó <file> sem atributo 'path' ignorado." -ForegroundColor Yellow
        continue
    }

    $fullPath = Join-Path $dest $rel
    $dir      = Split-Path $fullPath -Parent

    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    try {
        if ($encoding -ne "hex") {
            throw "Encoding desconhecido: $encoding em $rel (esperado: hex)"
        }

        if ($chunked -eq "true") {
            Write-Host "  [INFO] Arquivo marcado como chunked (reunificação por hex plano)" -ForegroundColor DarkYellow
        }

        $hex = $file.hex

        if ($null -eq $hex) {
            throw "Nó <hex> ausente em $rel"
        }

        # aceita <hex> vazio como arquivo de 0 bytes
        if ($hex.Length -eq 0) {
            $bytes = [byte[]]::new(0)
        }
        else {
            # se algum dia o HEX vier com espaços/linhas, pode-se limpar com: $hex = $hex -replace '\s',''
            $bytes = HexToBytes -Hex $hex

            if ($compressed -eq "true" -and $bytes.Length -gt 0) {
                $bytes = Decompress-BytesGZip -Bytes $bytes
            }
        }

        [System.IO.File]::WriteAllBytes($fullPath, $bytes)

        # Hash e tamanho do arquivo restaurado
        $newHash  = "sha256:$((Get-FileHash $fullPath -Algorithm SHA256).Hash.ToUpper())"
        $sizeReal = (Get-Item $fullPath).Length

        # Atualiza somatórios para relatório de expansão
        if (-not [string]::IsNullOrWhiteSpace($sizeAttr)) {
            $sumOriginalSize += [int64]$sizeAttr
        } else {
            $sumOriginalSize += $sizeReal
        }

        if (-not [string]::IsNullOrWhiteSpace($hexSizeAttr)) {
            $sumHexSize += [int64]$hexSizeAttr
        } else {
            $sumHexSize += ($hex.Length)
        }

        # Checagem de tamanho, se fornecido
        $sizeOk = $true
        if (-not [string]::IsNullOrWhiteSpace($sizeAttr)) {
            $sizeEsperado = [int64]$sizeAttr
            if ($sizeEsperado -ne $sizeReal -and -not $IgnoreSizeMismatch) {
                $sizeOk = $false
            }
        }

        if ($newHash -eq $storedHash -and $sizeOk) {
            Write-Host "  [OK] $rel" -ForegroundColor Green
            $ok++
        }
        else {
            Write-Host "  [FALHA HASH/SIZE] $rel" -ForegroundColor Red
            Write-Host "    esperado hash : $storedHash" -ForegroundColor Gray
            Write-Host "    obtido   hash : $newHash"   -ForegroundColor Gray
            if (-not [string]::IsNullOrWhiteSpace($sizeAttr)) {
                Write-Host "    esperado size : $sizeAttr" -ForegroundColor Gray
                Write-Host "    obtido   size : $sizeReal" -ForegroundColor Gray
            }
            $falha++
        }
    }
    catch {
        Write-Host "  [ERRO] $rel : $($_.Exception.Message)" -ForegroundColor Red
        $falha++
    }
}

# ---------- Relatório final ----------

$color = if ($falha -eq 0) { 'Green' } else { 'Red' }
Write-Host "`nOK: $ok | Falhas: $falha" -ForegroundColor $color

$expGlobal = 0
if ($sumOriginalSize -gt 0) {
    $expGlobal = [math]::Round(($sumHexSize / $sumOriginalSize), 3)
}

Write-Host ("Tamanho total original (bytes): {0}" -f $sumOriginalSize) -ForegroundColor Cyan
Write-Host ("Tamanho total em hex (chars):  {0}" -f $sumHexSize)      -ForegroundColor Cyan
Write-Host ("Taxa global de expansão:       {0}" -f $expGlobal)       -ForegroundColor Cyan

$srcLabel = if ($xmlFromClipboard) { "Clipboard" } else { "Arquivo" }

if ($falha -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        ("{0} arquivos restaurados a partir de {1} em:`n{2}`nExpansão global: {3}" -f $ok, $srcLabel, $dest, $expGlobal),
        "Sucesso"
    ) | Out-Null
}
else {
    [System.Windows.Forms.MessageBox]::Show(
        ("{0} OK | {1} falhas (origem: {2})`nExpansão global: {3}" -f $ok, $falha, $srcLabel, $expGlobal),
        "Resultado"
    ) | Out-Null
}

Read-Host "Enter para sair"