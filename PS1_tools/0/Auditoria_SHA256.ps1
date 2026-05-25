# Auditoria_SHA256.ps1
# Ferramenta de diagnóstico para comparar bytes em memória vs bytes gravados em disco,
# com seleção de arquivo e de relatório TXT via Windows Forms.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Select-InputFile {
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = "Selecione o arquivo para diagnóstico"
    $ofd.Filter = "Todos os arquivos (*.*)|*.*"
    $ofd.CheckFileExists = $true
    $ofd.Multiselect = $false

    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw "Nenhum arquivo selecionado."
    }

    return $ofd.FileName
}

function Select-OutputTxtFile {
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Title = "Escolha onde salvar o relatório TXT"
    $sfd.Filter = "Arquivo de texto (*.txt)|*.txt"
    $sfd.DefaultExt = "txt"
    $sfd.AddExtension = $true
    $sfd.OverwritePrompt = $true

    if ($sfd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw "Nenhum destino selecionado."
    }

    return $sfd.FileName
}

function Get-Sha256HexFromBytes {
    param([byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return ($hash | ForEach-Object { $_.ToString("x2") }) -join ""
    }
    finally {
        $sha.Dispose()
    }
}

function Get-Sha256HexFromFile {
    param([string]$FilePath)

    $fs = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hash = $sha.ComputeHash($fs)
            return ($hash | ForEach-Object { $_.ToString("x2") }) -join ""
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $fs.Dispose()
    }
}

function Compare-ByteArrays {
    param(
        [byte[]]$Expected,
        [byte[]]$Actual,
        [int]$Context = 16
    )

    $min = [Math]::Min($Expected.Length, $Actual.Length)
    $firstDiff = -1

    for ($i = 0; $i -lt $min; $i++) {
        if ($Expected[$i] -ne $Actual[$i]) {
            $firstDiff = $i
            break
        }
    }

    if ($firstDiff -eq -1 -and $Expected.Length -eq $Actual.Length) {
        return [pscustomobject]@{
            Match = $true
            FirstDifferenceOffset = $null
            ExpectedByteAtOffset = $null
            ActualByteAtOffset = $null
            ExpectedAroundDifference = "Os bytes são idênticos."
            ActualAroundDifference = "Os bytes são idênticos."
        }
    }

    if ($firstDiff -eq -1) {
        $firstDiff = $min
    }

    $start = [Math]::Max(0, $firstDiff - $Context)
    $endExp = [Math]::Min($Expected.Length - 1, $firstDiff + $Context)
    $endAct = [Math]::Min($Actual.Length - 1, $firstDiff + $Context)

    $expSlice = for ($i = $start; $i -le $endExp; $i++) {
        if ($i -lt $Expected.Length) { $Expected[$i] }
    }

    $actSlice = for ($i = $start; $i -le $endAct; $i++) {
        if ($i -lt $Actual.Length) { $Actual[$i] }
    }

    [pscustomobject]@{
        Match = $false
        FirstDifferenceOffset = $firstDiff
        ExpectedByteAtOffset = if ($firstDiff -lt $Expected.Length) { "0x{0:x2}" -f $Expected[$firstDiff] } else { "<EOF>" }
        ActualByteAtOffset = if ($firstDiff -lt $Actual.Length) { "0x{0:x2}" -f $Actual[$firstDiff] } else { "<EOF>" }
        ExpectedAroundDifference = ($expSlice | ForEach-Object { $_.ToString("x2") }) -join " "
        ActualAroundDifference = ($actSlice | ForEach-Object { $_.ToString("x2") }) -join " "
    }
}

function BytesToHexDump {
    param(
        [byte[]]$Bytes,
        [int]$BytesPerLine = 16
    )

    $lines = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Bytes.Length; $i += $BytesPerLine) {
        $end = [Math]::Min($i + $BytesPerLine - 1, $Bytes.Length - 1)
        $slice = $Bytes[$i..$end]
        $hex = ($slice | ForEach-Object { $_.ToString("x2") }) -join " "
        $ascii = ($slice | ForEach-Object {
            if ($_ -ge 32 -and $_ -le 126) { [char]$_ } else { "." }
        }) -join ""
        $lines.Add(("{0:D8}  {1,-47}  {2}" -f $i, $hex, $ascii))
    }

    return ($lines -join [Environment]::NewLine)
}

function Write-ReportTxt {
    param(
        [string]$ReportPath,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($ReportPath, $Content, [System.Text.Encoding]::UTF8)
}

try {
    # Seleção do arquivo e do relatório
    $inputPath = Select-InputFile
    $reportPath = Select-OutputTxtFile

    # Lê o arquivo de entrada como bytes puros
    $memoryBytes = [System.IO.File]::ReadAllBytes($inputPath)
    $memoryHash = Get-Sha256HexFromBytes -Bytes $memoryBytes

    # Grava em arquivo temporário para forçar o ciclo de escrita + flush
    $tempPath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        ([System.IO.Path]::GetRandomFileName() + [System.IO.Path]::GetExtension($inputPath))
    )

    $fs = [System.IO.File]::Open(
        $tempPath,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    try {
        $fs.Write($memoryBytes, 0, $memoryBytes.Length)
        $fs.Flush($true)
    }
    finally {
        $fs.Dispose()
    }

    # Lê o que foi persistido em disco
    $fileBytes = [System.IO.File]::ReadAllBytes($tempPath)
    $fileHash = Get-Sha256HexFromFile -FilePath $tempPath

    $cmp = Compare-ByteArrays -Expected $memoryBytes -Actual $fileBytes -Context 24

    $report = New-Object System.Text.StringBuilder
    [void]$report.AppendLine("DIAGNOSTICO DE BUFFER VS DISCO")
    [void]$report.AppendLine("Data/Hora: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine("")
    [void]$report.AppendLine("Arquivo de entrada: $inputPath")
    [void]$report.AppendLine("Arquivo temporario gravado: $tempPath")
    [void]$report.AppendLine("Relatorio TXT: $reportPath")
    [void]$report.AppendLine("")
    [void]$report.AppendLine("Tamanho em memoria: $($memoryBytes.Length) bytes")
    [void]$report.AppendLine("Tamanho em disco:   $($fileBytes.Length) bytes")
    [void]$report.AppendLine("SHA256 em memoria:  $memoryHash")
    [void]$report.AppendLine("SHA256 em disco:    $fileHash")
    [void]$report.AppendLine("Hashes iguais:      $($memoryHash -eq $fileHash)")
    [void]$report.AppendLine("Bytes iguais:       $($cmp.Match)")
    [void]$report.AppendLine("")

    if ($cmp.Match) {
        [void]$report.AppendLine("Nenhuma divergencia encontrada.")
    }
    else {
        [void]$report.AppendLine("Primeira divergencia no offset: $($cmp.FirstDifferenceOffset)")
        [void]$report.AppendLine("Byte esperado: $($cmp.ExpectedByteAtOffset)")
        [void]$report.AppendLine("Byte encontrado: $($cmp.ActualByteAtOffset)")
        [void]$report.AppendLine("")
        [void]$report.AppendLine("Bytes ao redor da diferença - MEMORIA:")
        [void]$report.AppendLine($cmp.ExpectedAroundDifference)
        [void]$report.AppendLine("")
        [void]$report.AppendLine("Bytes ao redor da diferença - DISCO:")
        [void]$report.AppendLine($cmp.ActualAroundDifference)
        [void]$report.AppendLine("")
        [void]$report.AppendLine("HEX DUMP - MEMORIA:")
        [void]$report.AppendLine((BytesToHexDump -Bytes $memoryBytes))
        [void]$report.AppendLine("")
        [void]$report.AppendLine("HEX DUMP - DISCO:")
        [void]$report.AppendLine((BytesToHexDump -Bytes $fileBytes))
    }

    Write-ReportTxt -ReportPath $reportPath -Content $report.ToString()

    [System.Windows.Forms.MessageBox]::Show(
        "Relatorio salvo em:`n$reportPath",
        "Diagnostico concluido",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Erro: $($_.Exception.Message)",
        "Falha na Auditoria",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
finally {
    if ($tempPath -and (Test-Path $tempPath)) {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }
}