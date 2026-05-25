# bootstrap_xml.ps1 - Captura projeto em XML (HEX, GZip opcional)
# Versão: 2 híbrida - usa tmp/stream apenas para arquivos grandes

param(
    [switch]$Compress,       # se presente, usa GZip antes do HEX
    [switch]$NoPrompt,       # se presente, não pergunta em GUI (usa só o parâmetro acima)
    [int]$BlockSizeMB = 5    # também usado como limiar de "arquivo grande"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression

function BytesToHex {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Count -eq 0) {
        return ""
    }

    return ($Bytes | ForEach-Object { $_.ToString("X2") }) -join ""
}

function Compress-BytesGZip {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Count -eq 0) { return [byte[]]@() }

    $output = New-Object System.IO.MemoryStream
    $gzip   = New-Object System.IO.Compression.GZipStream(
        $output, [System.IO.Compression.CompressionMode]::Compress, $true
    )
    try {
        $gzip.Write($Bytes, 0, $Bytes.Length)
    }
    finally {
        $gzip.Dispose()
    }
    return $output.ToArray()
}

# ---------- Decide se vai comprimir (GZip) ----------

$useCompress = $Compress.IsPresent

if (-not $NoPrompt.IsPresent -and -not $Compress.IsPresent) {
    $msg = "Deseja usar compressão GZip dentro do HEX?`n" +
           "Sim = compressão ativada`nNão = sem compressão"

    $res = [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Compressão GZip",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
        $useCompress = $true
    } else {
        $useCompress = $false
    }
}

# ---------- Seleciona pasta do projeto ----------
$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description = "Selecione a pasta do projeto"

if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada na seleção da pasta." -ForegroundColor Yellow
    exit
}

$src = $fbd.SelectedPath
if (-not $src) {
    Write-Host "Nenhuma pasta selecionada." -ForegroundColor Yellow
    exit
}

$proj = Split-Path $src -Leaf

# ---------- Pasta padrão de saída ----------
$xmlRoot = Join-Path $env:LOCALAPPDATA 'estruturas_XML'
if (!(Test-Path $xmlRoot)) {
    New-Item $xmlRoot -Force | Out-Null
}

# ---------- Escolhe arquivo de saída ----------
$savedlg = New-Object System.Windows.Forms.SaveFileDialog
$savedlg.InitialDirectory = $xmlRoot
$savedlg.Filter           = "XML|*.xml"
$savedlg.FileName         = "bootstrap_${proj}_$(Get-Date -Format 'yyyyMMddHHmmss').xml"

if ($savedlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada na escolha do XML de saída." -ForegroundColor Yellow
    exit
}

$out = $savedlg.FileName
if (-not $out) {
    Write-Host "Nenhum arquivo de saída selecionado." -ForegroundColor Yellow
    exit
}

# ---------- Lista de pastas e arquivos ----------
$folders = Get-ChildItem $src -Directory -Recurse |
    ForEach-Object { $_.FullName.Substring($src.Length).TrimStart('\\') } |
    Sort-Object

$allFiles = Get-ChildItem $src -File -Recurse

# ---------- Configuração do XmlWriter ----------
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent          = $true
$settings.IndentChars     = '  '
$settings.Encoding        = New-Object System.Text.UTF8Encoding($false)
$settings.NewLineHandling = [System.Xml.NewLineHandling]::None

$w = [System.Xml.XmlWriter]::Create($out, $settings)

# ---------- Cabeçalho do XML ----------
$w.WriteStartDocument()
$w.WriteStartElement('project')
$w.WriteAttributeString('name',    $proj)
$w.WriteAttributeString('created', (Get-Date -Format 'o'))
$w.WriteAttributeString('version', '1.3-hybrid')
$w.WriteAttributeString('compressedDefault', ($useCompress.ToString().ToLower()))

# ---------- Pastas ----------
$w.WriteStartElement('folders')
foreach ($f in $folders) {
    if ([string]::IsNullOrWhiteSpace($f)) { continue }
    $w.WriteElementString('folder', $f)
}
$w.WriteEndElement() # folders

# ---------- Arquivos ----------
$w.WriteStartElement('files')
$count           = 0
$totalFiles      = $allFiles.Count
$blockLimitBytes = $BlockSizeMB * 1MB      # limiar de "arquivo grande"
$chunkBufferSize = 64KB                    # tamanho do chunk em bytes

foreach ($f in $allFiles) {

    $count++

    # Barra de progresso
    $percent = [int](($count / $totalFiles) * 100)
    Write-Progress -Activity "Capturando arquivos" `
                   -Status   "Processando $count de $totalFiles" `
                   -PercentComplete $percent

    Write-Host "[$count/$totalFiles] Capturando: $($f.FullName)" -ForegroundColor Cyan

    $rel          = $f.FullName.Substring($src.Length).TrimStart('\\')
    $originalSize = $f.Length
    $hashRef      = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToUpper()

    $isLargeFile    = $originalSize -gt $blockLimitBytes
    $compressedFlag = $false
    $hexSize        = 0
    $expansion      = 0

    if ($isLargeFile) {
        Write-Host "   -> Arquivo grande, usando tmp/chunks" -ForegroundColor Yellow
    }

    # ---------- Início do elemento <file> ----------
    $w.WriteStartElement('file')
    $w.WriteAttributeString('path',     $rel)
    $w.WriteAttributeString('hash',     "sha256:$hashRef")
    $w.WriteAttributeString('encoding', 'hex')
    $w.WriteAttributeString('chunked',  $isLargeFile.ToString().ToLower())

    if (-not $isLargeFile) {
        # ---------- ARQUIVO PEQUENO/MÉDIO: fluxo original em memória ----------

        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)

        if ($useCompress) {
            $bytes = Compress-BytesGZip -Bytes $bytes
            $compressedFlag = $true
        }

        $hex       = BytesToHex -Bytes $bytes
        $hexSize   = $hex.Length
        $expansion = if ($originalSize -gt 0) {
            [math]::Round($hexSize / $originalSize, 3)
        } else { 0 }

        $w.WriteAttributeString('compressed', $compressedFlag.ToString().ToLower())
        $w.WriteAttributeString('size',       $originalSize.ToString())
        $w.WriteAttributeString('hexSize',    $hexSize.ToString())
        $w.WriteAttributeString('expansion',  $expansion.ToString())

        $w.WriteElementString('hex', $hex)
    }
    else {
        # ---------- ARQUIVO GRANDE: híbrido com tmp + chunks ----------

        $tmpHexPath = [System.IO.Path]::Combine(
            [System.IO.Path]::GetTempPath(),
            [System.IO.Path]::GetRandomFileName() + ".hex"
        )

        $buffer = New-Object byte[] $chunkBufferSize

        # 1) Ler arquivo original por chunks, opcionalmente comprimir, converter para HEX e gravar no tmp
        $fs = [System.IO.File]::OpenRead($f.FullName)
        try {
            $tmpWriter = [System.IO.StreamWriter]::new($tmpHexPath, $false, [System.Text.Encoding]::UTF8)
            try {
                while (($read = $fs.Read($buffer, 0, $chunkBufferSize)) -gt 0) {

                    $chunkBytes = if ($read -eq $chunkBufferSize) {
                        $buffer
                    } else {
                        $buffer[0..($read-1)]
                    }

                    if ($useCompress) {
                        $chunkBytes = Compress-BytesGZip -Bytes $chunkBytes
                        $compressedFlag = $true
                    }

                    $chunkHex = BytesToHex -Bytes $chunkBytes
                    $hexSize += $chunkHex.Length
                    $tmpWriter.Write($chunkHex)
                }
            }
            finally {
                $tmpWriter.Flush()
                $tmpWriter.Dispose()
            }
        }
        finally {
            $fs.Dispose()
        }

        $expansion = if ($originalSize -gt 0) {
            [math]::Round($hexSize / $originalSize, 3)
        } else { 0 }

        # 2) Atributos com base no HEX gerado
        $w.WriteAttributeString('compressed', $compressedFlag.ToString().ToLower())
        $w.WriteAttributeString('size',       $originalSize.ToString())
        $w.WriteAttributeString('hexSize',    $hexSize.ToString())
        $w.WriteAttributeString('expansion',  $expansion.ToString())

        # 3) Streamar o conteúdo HEX do tmp para dentro do <hex> no XML
        $w.WriteStartElement('hex')
        try {
            $tmpReader = [System.IO.StreamReader]::new($tmpHexPath, [System.Text.Encoding]::UTF8)
            try {
                $chunkTextBuffer = New-Object char[] 65536
                while (($charsRead = $tmpReader.Read($chunkTextBuffer, 0, $chunkTextBuffer.Length)) -gt 0) {
                    $chunkText = New-Object string ($chunkTextBuffer, 0, $charsRead)
                    $w.WriteString($chunkText)
                }
            }
            finally {
                $tmpReader.Dispose()
            }
        }
        finally {
            if (Test-Path $tmpHexPath) {
                Remove-Item $tmpHexPath -Force -ErrorAction SilentlyContinue
            }
        }
        $w.WriteEndElement() # hex
    }

    $w.WriteEndElement() # file
}

$w.WriteEndElement() # files
$w.WriteEndElement() # project
$w.WriteEndDocument()
$w.Close()

# ---------- Gera TXT idêntico ----------
try {
    $txtPath = [System.IO.Path]::ChangeExtension($out, ".txt")
    # lê o XML como texto e grava no TXT com mesma codificação (UTF-8 sem BOM)
    $xmlText = Get-Content $out -Raw -Encoding UTF8
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($txtPath, $xmlText, $utf8NoBom)
}
catch {
    Write-Host "Aviso: não foi possível gerar o TXT: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "OK: $count arquivos" -ForegroundColor Green
Write-Host "XML: $out" -ForegroundColor Cyan
Write-Host "TXT: $txtPath" -ForegroundColor Cyan

$mode = if ($useCompress) { "com compressão GZip" } else { "sem compressão" }
[System.Windows.Forms.MessageBox]::Show(
    "$count arquivos capturados ($mode).`nXML: $out`nTXT: $txtPath",
    "Sucesso"
) | Out-Null

Read-Host "Enter para sair"