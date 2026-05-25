# criar_projeto.ps1
$ErrorActionPreference = 'Stop'
$baseDir = "C:\Users\$env:USERNAME\Desktop\Scripts_Adapta"
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
$logPath = Join-Path $baseDir "criar_projeto_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log { param([string]$Message, [string]$Color='White') Write-Host $Message -ForegroundColor $Color; Add-Content -Path $logPath -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $Message" }
try {
    $clip = Get-Clipboard
    if ([string]::IsNullOrWhiteSpace($clip) -or !$clip.Trim().StartsWith('# PROJECT:')) { throw "Clipboard inválido. Deve começar com '# PROJECT:'" }
    $lines = $clip -split "`r`n"
    $json = ($lines | Select-Object -Skip 1) -join "`n"
    $data = $json | ConvertFrom-Json
    $projName = $data.nome
    $projPath = Join-Path $baseDir $projName
    New-Item -ItemType Directory -Path $projPath -Force | Out-Null
    foreach ($folder in $data.estruturaPastas) { New-Item -ItemType Directory -Path (Join-Path $projPath $folder) -Force | Out-Null }
    foreach ($prop in $data.arquivos.PSObject.Properties) {
        $relPath = $prop.Name.Replace('/', '\')
        $fullPath = Join-Path $projPath $relPath
        $parent = Split-Path $fullPath -Parent
        if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $content = "# PATH ABSOLUTO: $fullPath`r`n" + $prop.Value
        Set-Content -Path $fullPath -Value $content -Encoding UTF8
        Write-Log "Criado: $fullPath" Green
    }
    Write-Log "Projeto $projName criado com sucesso em $projPath" Cyan
} catch { Write-Log "ERRO: $_" Red }
