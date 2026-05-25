
Add-Type -AssemblyName System.Windows.Forms

param(
    [string]$bootstrapFile = "bootstrap.json"
)

try {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "RESTORE - Adapta ONE Project Restore" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $bootstrapFile)) {
        throw "Arquivo bootstrap não encontrado: $bootstrapFile"
    }

    Write-Host "Lendo arquivo bootstrap..." -ForegroundColor Yellow
    $jsonContent = Get-Content $bootstrapFile -Raw -Encoding UTF8
    $projectData = $jsonContent | ConvertFrom-Json

    Write-Host "Projeto: $($projectData.project_name)" -ForegroundColor Green
    Write-Host "Versão: $($projectData.version)" -ForegroundColor Green
    Write-Host ""

    Write-Host "Criando estrutura de pastas..." -ForegroundColor Yellow
    foreach ($folder in $projectData.folders) {
        $folderPath = Join-Path (Get-Location) $folder
        if (-not (Test-Path $folderPath)) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
            Write-Host "  OK - $folder" -ForegroundColor Green
        }
    }

    Write-Host "Restaurando arquivos..." -ForegroundColor Yellow
    foreach ($file in $projectData.files) {
        $filePath = Join-Path (Get-Location) $file.path
        $fileDir = Split-Path $filePath
        
        if (-not (Test-Path $fileDir)) {
            New-Item -Path $fileDir -ItemType Directory -Force | Out-Null
        }

        [System.IO.File]::WriteAllText($filePath, $file.content, [System.Text.Encoding]::UTF8)
        Write-Host "  OK - $($file.path)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OK - Projeto restaurado com sucesso!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Próximos passos:" -ForegroundColor Yellow
    Write-Host "1. Execute: master_launcher.bat" -ForegroundColor Cyan
    Write-Host "2. Sistema iniciará automaticamente" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}