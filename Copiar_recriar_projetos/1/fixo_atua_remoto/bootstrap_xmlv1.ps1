# bootstrap_xml.ps1 - Captura projeto em XML (HEX, GZip opcional)
# Versão: 1.3 - Além do XML, gera um TXT idêntico (mesmo conteúdo, extensão .txt)

param(
    [switch]$Compress,       # se presente, usa GZip antes do HEX
    [switch]$NoPrompt,       # se presente, não pergunta em GUI (usa só o parâmetro acima)
    [int]$BlockSizeMB = 5
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression

function BytesToHex {
    param([byte[]]$Bytes)
    return ($Bytes | ForEach-Object { $_.ToString("X2") }) -join ""
}

function Compress-BytesGZip {
    param([byte[]]$Bytes)

    $output = New-Object System.IO.MemoryStream
    $gzip   = New-Object System.IO.Compression.GZipStream(
        $output, [System.IO.Compression.CompressionMode]::Compress
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
    ForEach-Object { $_.FullName.Substring($src.Length).TrimStart('\') } |
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
$w.WriteAttributeString('version', '1.3')
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
$blockLimitBytes = $BlockSizeMB * 1MB

foreach ($f in $allFiles) {
    $rel          = $f.FullName.Substring($src.Length).TrimStart('\')
    $originalSize = $f.Length
    $bytes        = [System.IO.File]::ReadAllBytes($f.FullName)
    $hashRef      = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToUpper()

    $compressedFlag = $false
    if ($useCompress) {
        $bytes = Compress-BytesGZip -Bytes $bytes
        $compressedFlag = $true
    }

    $hex       = BytesToHex -Bytes $bytes
    $hexSize   = $hex.Length
    $expansion = if ($originalSize -gt 0) {
        [math]::Round($hexSize / $originalSize, 3)
    } else { 0 }

    $isChunked = $originalSize -gt $blockLimitBytes

    $w.WriteStartElement('file')
    $w.WriteAttributeString('path',       $rel)
    $w.WriteAttributeString('hash',       "sha256:$hashRef")
    $w.WriteAttributeString('encoding',   'hex')
    $w.WriteAttributeString('compressed', $compressedFlag.ToString().ToLower())
    $w.WriteAttributeString('size',       $originalSize.ToString())
    $w.WriteAttributeString('hexSize',    $hexSize.ToString())
    $w.WriteAttributeString('expansion',  $expansion.ToString())
    $w.WriteAttributeString('chunked',    $isChunked.ToString().ToLower())
    $w.WriteElementString('hex', $hex)
    $w.WriteEndElement()

    $count++
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