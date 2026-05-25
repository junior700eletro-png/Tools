# restore_xmlv1.ps1
# Restaura projeto a partir de XML em formato HEX, com suporte a GZip opcional.
# Compatível com bootstrap_xml.ps1 versão 1.1 (encoding="hex", compressed="true|false").

param(
    [switch]$IgnoreSizeMismatch   # se presente, ignora divergência de tamanho (usa só hash)
)

Add-Type -AssemblyName System.Windows.Forms

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

# ---------- Seleção do XML de bootstrap ----------

$ofd = New-Object System.Windows.Forms.OpenFileDialog
$ofd.InitialDirectory = "$env:LOCALAPPDATA\estruturas_XML"
$ofd.Filter           = "XML|*.xml"
$ofd.Title            = "Selecione o bootstrap XML (hex + gzip opcional)"

if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$xmlPath = $ofd.FileName

# ---------- Carrega XML ----------

try {
    [xml]$xml = Get-Content $xmlPath -Raw -Encoding UTF8
}
catch {
    [System.Windows.Forms.MessageBox]::Show("Erro ao ler XML:`n$($_.Exception.Message)", "Erro")
    Read-Host "Enter para sair"
    exit
}

# Nome do projeto
$projName = $xml.project.name
if ([string]::IsNullOrWhiteSpace($projName)) {
    $projName = [IO.Path]::GetFileNameWithoutExtension($xmlPath)
}

# ---------- Pasta de destino ----------

$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description  = "Pasta de destino para restaurar '$projName'"
$fbd.SelectedPath = "$env:LOCALAPPDATA\estruturas_XML"

if ($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }
$dest = $fbd.SelectedPath

# ---------- Cria pastas ----------

Write-Host "Criando pastas..." -ForegroundColor Cyan

foreach ($folder in $xml.project.folders.folder) {
    $folderRel = $folder.InnerText
    if ([string]::IsNullOrWhiteSpace($folderRel)) { continue }

    $fullFolder = Join-Path $dest $folderRel
    New-Item -ItemType Directory -Path $fullFolder -Force | Out-Null
}

# ---------- Restaura arquivos ----------

$ok    = 0
$falha = 0

$sumOriginalSize = 0
$sumHexSize      = 0

Write-Host "`nProcessando arquivos..." -ForegroundColor Cyan

foreach ($file in $xml.project.files.file) {
    $rel         = $file.GetAttribute("path")
    $storedHash  = $file.GetAttribute("hash")
    $encoding    = $file.GetAttribute("encoding")
    $compressed  = $file.GetAttribute("compressed")
    $sizeAttr    = $file.GetAttribute("size")
    $hexSizeAttr = $file.GetAttribute("hexSize")
    $expAttr     = $file.GetAttribute("expansion")
    $chunked     = $file.GetAttribute("chunked")

    if ([string]::IsNullOrWhiteSpace($rel)) {
        Write-Host "  [AVISO] Nó <file> sem atributo 'path' ignorado." -ForegroundColor Yellow
        continue
    }

    $fullPath = Join-Path $dest $rel
    $dir      = Split-Path $fullPath -Parent

    if (!(Test-Path $dir)) {
        New-Item $dir -Force | Out-Null
    }

    try {
        if ($encoding -ne "hex") {
            throw "Encoding desconhecido: $encoding em $rel (esperado: hex)"
        }

        if ($chunked -eq "true") {
            Write-Host "  [AVISO] Arquivo marcado como chunked (fragmentação ainda não implementada): $rel" -ForegroundColor Yellow
        }

        $hex = $file.hex
        if ([string]::IsNullOrWhiteSpace($hex)) {
            throw "Conteúdo <hex> vazio em $rel"
        }

        $bytes = HexToBytes -Hex $hex

        if ($compressed -eq "true") {
            $bytes = Decompress-BytesGZip -Bytes $bytes
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

# Mensagem GUI
if ($falha -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "$ok arquivos restaurados em:`n$dest`nExpansão global: $expGlobal",
        "Sucesso"
    ) | Out-Null
}
else {
    [System.Windows.Forms.MessageBox]::Show(
        "$ok OK | $falha falhas`nExpansão global: $expGlobal",
        "Resultado"
    ) | Out-Null
}

Read-Host "Enter para sair"