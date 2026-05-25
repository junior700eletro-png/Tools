
<#
.SYNOPSIS
    Integrador completo para workflows IA-Automate.

.DESCRIPTION
    Menu interativo que orquestra bootstrap, restore, validação, criação de arquivos e ciclo completo.

[CmdletBinding()]
param()

Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Continue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$RequiredScripts = @(
    'bootstrap_ps1.ps1',
    'restore_bootstrap_ps1.ps1',
    'Validate-JSONDiff.ps1',
    'files_ps1.ps1'
)

foreach ($ScriptName in $RequiredScripts) {
    $ScriptPath = Join-Path $ScriptDir $ScriptName
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "ERRO: Script ausente: $ScriptName" -ForegroundColor Red
        exit 1
    }
}

$LogPath = Join-Path $ScriptDir "IA-Automate-Log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
Start-Transcript -Path $LogPath -Append

function Write-Success {
    param([string]$Text)
    Write-Host "✓  $Text" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Text)
    Write-Host "✗  $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "> $Text" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Text)
    Write-Host "! $Text" -ForegroundColor Yellow
}

function Get-LatestBootstrapJson {
    $Files = Get-ChildItem (Join-Path $ScriptDir 'bootstrap_*.json') | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($Files) { return $Files.FullName }
    return $null
}

function Show-Menu {
    Clear-Host
    Write-Host "`n╔═════════════════════════════════╔" -ForegroundColor Yellow
    Write-Host "║  IA_AUTOMATE INTEGRATION MENU          ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════╚" -ForegroundColor Yellow
    Write-Host '`nEscolha uma ação:' -ForegroundColor White
    Write-Host '  [1] BOOTSTRAP - Exportar projeto para JSON' -ForegroundColor White
    Write-Host '  [2] RESTORE - Restaurar projeto do JSON' -ForegroundColor White
    Write-Host '  [3] VALIDATE & EXECUTE - Validar e executar mudanças' -ForegroundColor White
    Write-Host '  [4] CREATE FILE - Criar arquivo do clipboard' -ForegroundColor White
    Write-Host '  [5] FULL CYCLE - Ciclo completo (IA)' -ForegroundColor White
    Write-Host '  [0] Sair' -ForegroundColor White
    Write-Host '' -ForegroundColor White
}

function Execute-Bootstrap {
    $ProjectPath = Read-Host 'Digite a pasta do projeto (padrão: diretório atual)'
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Get-Location }
    if (-not (Test-Path $ProjectPath)) {
        Write-ErrorMsg 'Pasta não existe.'
        return
    }
    Write-Info "Executando Bootstrap em $ProjectPath"
    & (Join-Path $ScriptDir 'bootstrap_ps1.ps1') -ProjectPath $ProjectPath *>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Bootstrap concluído. JSON salvo.'
    } else {
        Write-ErrorMsg 'Erro no Bootstrap.'
    }
    Read-Host 'Pressione Enter para continuar'
}

function Execute-Restore {
    $LatestJson = Get-LatestBootstrapJson
    $JsonPathInput = Read-Host "Digite o arquivo JSON (padrão: último $LatestJson )"
    if ([string]::IsNullOrWhiteSpace($JsonPathInput) -and $LatestJson) { $JsonPathInput = $LatestJson }
    if (-not $JsonPathInput -or -not (Test-Path $JsonPathInput)) {
        Write-ErrorMsg 'Arquivo JSON inválido ou não encontrado.'
        return
    }
    Write-Info "Restaurando de $JsonPathInput"
    & (Join-Path $ScriptDir 'restore_bootstrap_ps1.ps1') -JsonPath $JsonPathInput *>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Restore concluído.'
    } else {
        Write-ErrorMsg 'Erro no Restore.'
    }
    Read-Host 'Pressione Enter para continuar'
}

function Get-NewJsonPath {
    param([string]$InputPrompt)
    $NewInput = Read-Host $InputPrompt
    $NewPath = $null
    if ($NewInput -eq 'clipboard' -or $NewInput -eq 'c') {
        try {
            $JsonObj = Get-Clipboard | ConvertFrom-Json -Depth 20
            $TempDir = [System.IO.Path]::GetTempPath()
            $NewPath = Join-Path $TempDir "ia-new-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$([guid]::NewGuid().ToString('N')[0..7]).json"
            $JsonObj | ConvertTo-Json -Depth 20 | Out-File -FilePath $NewPath -Encoding utf8
            Write-Info "JSON do clipboard salvo temporariamente em: $NewPath"
        } catch {
            Write-ErrorMsg 'Conteúdo do clipboard não é JSON válido.'
            return $null
        }
    } elseif (Test-Path $NewInput) {
        $NewPath = $NewInput
    } else {
        Write-ErrorMsg 'Arquivo não encontrado.'
        return $null
    }
    return $NewPath
}

function Execute-ValidateAndExecute {
    $NewPath = Get-NewJsonPath 'Novo JSON: caminho do arquivo ou "clipboard"'
    if (-not $NewPath) { return }

    $OldPath = Get-LatestBootstrapJson
    if (-not $OldPath) {
        Write-Warn 'Nenhum JSON anterior encontrado. Pulando validação.'
    } else {
        Write-Info "Validando $NewPath contra $OldPath"
        & (Join-Path $ScriptDir 'Validate-JSONDiff.ps1') -OldJsonPath $OldPath -NewJsonPath $NewPath *>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg 'Validação falhou.'
            if ($NewPath -match 'temp') { Remove-Item $NewPath -ErrorAction SilentlyContinue }
            return
        }
        Write-Success 'Validação aprovada.'
    }

    Write-Info "Executando Restore com $NewPath"
    & (Join-Path $ScriptDir 'restore_bootstrap_ps1.ps1') -JsonPath $NewPath *>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Projeto atualizado com sucesso.'
    } else {
        Write-ErrorMsg 'Erro no Restore.'
    }

    if ($NewPath -match 'temp') { Remove-Item $NewPath -ErrorAction SilentlyContinue }
    Read-Host 'Pressione Enter para continuar'
}

function Execute-CreateFile {
    $Folder = Read-Host 'Pasta destino (padrão: diretório atual)'
    if ([string]::IsNullOrWhiteSpace($Folder)) { $Folder = Get-Location }
    if (-not (Test-Path $Folder -PathType Container)) {
        try { New-Item -Path $Folder -ItemType Directory | Out-Null }
        catch { Write-ErrorMsg 'Não foi possível criar pasta.'; return }
    }
    Write-Info "Criando arquivo do clipboard em $Folder"
    & (Join-Path $ScriptDir 'files_ps1.ps1') -ProjectFolder $Folder *>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        Write-Success 'Arquivo criado com backup.'
    } else {
        Write-ErrorMsg 'Erro na criação do arquivo.'
    }
    Read-Host 'Pressione Enter para continuar'
}

function Execute-FullCycle {
    $Logs = @("=== FULL CYCLE IA ===")
    $NewPath = Get-NewJsonPath 'JSON novo da IA: caminho ou "clipboard"'
    if (-not $NewPath) { return }

    $OldPath = Get-LatestBootstrapJson
    $OverallSuccess = $true
    $Logs += "Novo JSON: $NewPath"

    if ($OldPath) {
        $Logs += "JSON anterior: $OldPath"
        Write-Info "Validando..."
        $ValidateOutput = & (Join-Path $ScriptDir 'Validate-JSONDiff.ps1') -OldJsonPath $OldPath -NewJsonPath $NewPath *>&1
        $ValidateOutput | ForEach-Object { Write-Host $_ }
        $Logs += "Validate: $($ValidateOutput -join ' | ')"
        if ($LASTEXITCODE -ne 0) {
            $OverallSuccess = $false
        }
    } else {
        $Logs += 'Sem anterior, pulando validação.'
    }

    if ($OverallSuccess) {
        Write-Info "Restore..."
        $RestoreOutput = & (Join-Path $ScriptDir 'restore_bootstrap_ps1.ps1') -JsonPath $NewPath *>&1
        $RestoreOutput | ForEach-Object { Write-Host $_ }
        $Logs += "Restore: $($RestoreOutput -join ' | ')"
        if ($LASTEXITCODE -ne 0) { $OverallSuccess = $false }
    }

    $Feedback = @{
        status = if ($OverallSuccess) { 'success' } else { 'failure' }
        message = if ($OverallSuccess) { 'Sistema atualizado.' } else { 'Erro no processo.' }
        logs = $Logs -join "`n"
        timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    } | ConvertTo-Json -Depth 10

    Write-Host "`nFEEDBACK JSON:`n$Feedback" -ForegroundColor Cyan
    $Feedback | Out-File (Join-Path $ScriptDir 'feedback.json') -Encoding utf8
    Set-Clipboard $Feedback
    Write-Success 'Feedback salvo em feedback.json e copiado para clipboard.'

    if ($NewPath -match 'temp') { Remove-Item $NewPath -ErrorAction SilentlyContinue }
    Read-Host 'Pressione Enter para continuar'
}

try {
    while ($true) {
        Show-Menu
        $Choice = Read-Host 'Opção'
        switch ($Choice) {
            '1' { Execute-Bootstrap }
            '2' { Execute-Restore }
            '3' { Execute-ValidateAndExecute }
            '4' { Execute-CreateFile }
            '5' { Execute-FullCycle }
            '0' { break }
            default { Write-Warn 'Opção inválida. Tente novamente.'; Read-Host 'Enter' }
        }
    }
} finally {
    Stop-Transcript
    Write-Host "Log salvo em: $LogPath" -ForegroundColor Cyan
}