# Arquivo: restore_bootstrap_v1.ps1
# Caminho: Scripts / restore_bootstrap_v1.ps1
# Propósito: Restaurar projeto a partir de JSON em estruturas_JSON, com seleção de pasta via Windows Forms

# Carrega Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Diretório base dos arquivos de estrutura
$jsonDir = Join-Path $env:LOCALAPPDATA 'estruturas_JSON'

if (!(Test-Path $jsonDir)) {
    Write-Host "Diretório não encontrado: $jsonDir" -ForegroundColor Red
    pause
    exit 1
}

# Busca arquivos .json e .txt
# $files = Get-ChildItem -Path $jsonDir -File -Include *.json, *.txt | Sort-Object Name
$files = Get-ChildItem -Path (Join-Path $jsonDir '*') -File -Include *.json, *.txt | Sort-Object Name

if ($files.Count -eq 0) {
    Write-Host "Nenhum arquivo .json ou .txt encontrado em $jsonDir" -ForegroundColor Red
    pause
    exit 1
}

Clear-Host
Write-Host "Arquivos encontrados em $jsonDir :" -ForegroundColor Yellow
for ($i = 0; $i -lt $files.Count; $i++) {
    Write-Host "  $i : $($files[$i].Name)" -ForegroundColor White
}

# Seleção do arquivo
$choiceNum = -1
do {
    $inputChoice = Read-Host "\nDigite o número do arquivo a restaurar"
    $valid = [int32]::TryParse($inputChoice, [ref]$choiceNum)
    if ($valid -and $choiceNum -ge 0 -and $choiceNum -lt $files.Count) {
        break
    }
    Write-Host "Entrada inválida. Deve ser um número entre 0 e $($files.Count - 1)." -ForegroundColor Yellow
} while ($true)

$selectedFile = $files[$choiceNum]
Write-Host "\nArquivo selecionado: $($selectedFile.Name)" -ForegroundColor Cyan

# Seleção da pasta de destino
$fbd = New-Object System.Windows.Forms.FolderBrowserDialog
$fbd.Description = 'Selecione a pasta de destino para restaurar a estrutura'
$fbd.RootFolder = [System.Environment+SpecialFolder]::MyComputer
$fbd.ShowNewFolderButton = $true

$result = $fbd.ShowDialog()
if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Operação cancelada pelo usuário." -ForegroundColor Red
    pause
    exit 1
}

$destPath = $fbd.SelectedPath
Write-Host "Pasta de destino: $destPath" -ForegroundColor Cyan

try {
    $content = Get-Content $selectedFile.FullName -Raw -Encoding UTF8
    $expectedPaths = @()
    $createdCount = 0
    $failedCreates = 0

    if ($selectedFile.Extension -eq '.json') {
        Write-Host "Lendo JSON..." -ForegroundColor Cyan
        $structure = $content | ConvertFrom-Json

        foreach ($prop in Get-Member -InputObject $structure -MemberType NoteProperty) {
            $relPath = $prop.Name
            $fileContent = $structure.$relPath
            $expectedPaths += $relPath

            $fullPath = Join-Path $destPath $relPath
            try {
                $parentDir = Split-Path $fullPath -Parent
                if (!(Test-Path $parentDir) -and $parentDir) {
                    New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                }
                [System.IO.File]::WriteAllText($fullPath, $fileContent, [System.Text.Encoding]::UTF8)
                Write-Host "  Criado: $relPath" -ForegroundColor Green
                $createdCount++
            } catch {
                Write-Host "  Erro ao criar $relPath`: $($_.Exception.Message)" -ForegroundColor Red
                $failedCreates++
            }
        }
    } elseif ($selectedFile.Extension -eq '.txt') {
        Write-Host "Lendo TXT (estrutura de pastas/arquivos vazios)..." -ForegroundColor Cyan
        $lines = $content -split "`n" | Where-Object { $_.Trim() }

        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            if ([string]::IsNullOrEmpty($trimmedLine)) { continue }

            if ($trimmedLine.EndsWith('/')) {
                $relPath = $trimmedLine.Substring(0, $trimmedLine.Length - 1).TrimEnd('/')
                $itemType = 'Directory'
            } else {
                $relPath = $trimmedLine
                $itemType = 'File'
            }
            $expectedPaths += $relPath

            $fullPath = Join-Path $destPath $relPath
            try {
                if ($itemType -eq 'Directory') {
                    New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                } else {
                    $parentDir = Split-Path $fullPath -Parent
                    if ($parentDir -and !(Test-Path $parentDir)) {
                        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
                    }
                    New-Item -Path $fullPath -ItemType File -Force | Out-Null
                }
                Write-Host "  Criado: $relPath ($itemType)" -ForegroundColor Green
                $createdCount++
            } catch {
                Write-Host "  Erro ao criar $relPath`: $($_.Exception.Message)" -ForegroundColor Red
                $failedCreates++
            }
        }
    }

    # Validação
    Write-Host "\nValidando criações..." -ForegroundColor Yellow
    $failedValidations = 0
    foreach ($relPath in $expectedPaths) {
        $fullPath = Join-Path $destPath $relPath
        if (!(Test-Path $fullPath)) {
            Write-Host "  Faltando: $relPath" -ForegroundColor Red
            $failedValidations++
        }
    }

    Write-Host "\nResumo:" -ForegroundColor Yellow
    Write-Host "  Criados: $createdCount" -ForegroundColor Green
    if ($failedCreates -gt 0) { Write-Host "  Falhas na criação: $failedCreates" -ForegroundColor Red }
    if ($failedValidations -gt 0) { Write-Host "  Falhas na validação: $failedValidations" -ForegroundColor Red }
    if ($failedCreates -eq 0 -and $failedValidations -eq 0) {
        Write-Host "  \¡Sucesso total!\" -ForegroundColor Green
    } else {
        Write-Host "  Concluído com avisos." -ForegroundColor Yellow
    }

} catch {
    Write-Host "\nErro geral: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "\nPressione qualquer tecla para sair..." -ForegroundColor Gray
pause
