param(
    [string]$RemoteUrl  # ex: https://github.com/SEU_USUARIO/SEU_REPO.git
)

if (-not $RemoteUrl) {
    Write-Host "ERRO: Informe a URL do repositório remoto (RemoteUrl)." -ForegroundColor Red
    Write-Host "Exemplo:" -ForegroundColor Yellow
    Write-Host "  .\publicar_pasta_github.ps1 -RemoteUrl https://github.com/SEU_USUARIO/SEU_REPO.git"
    exit 1
}

# Carregar Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Escolher pasta
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Selecione a pasta que você quer publicar no GitHub"
$dialog.SelectedPath = [Environment]::GetFolderPath('Desktop')

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK -or
    [string]::IsNullOrWhiteSpace($dialog.SelectedPath)) {
    Write-Host "Operação cancelada. Nenhuma pasta selecionada." -ForegroundColor Yellow
    exit 1
}

$RepoPath = $dialog.SelectedPath
Write-Host "Pasta selecionada: $RepoPath" -ForegroundColor Cyan

Set-Location $RepoPath

Write-Host "== Publicando pasta '$RepoPath' no repositório '$RemoteUrl' ==" -ForegroundColor Cyan

# 1) Inicializar repositório Git, se ainda não existir
if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    Write-Host "[1/6] Inicializando repositório Git..." -ForegroundColor Yellow
    git init
} else {
    Write-Host "[1/6] Repositório Git já existe, seguindo..." -ForegroundColor Yellow
}

# 2) Criar .gitignore básico se não existir
$gitignorePath = Join-Path $RepoPath ".gitignore"
if (-not (Test-Path $gitignorePath)) {
    Write-Host "[2/6] Criando .gitignore básico..." -ForegroundColor Yellow
    @"
.venv/
__pycache__/
*.db
credentials.json
token.json
"@ | Out-File -FilePath $gitignorePath -Encoding UTF8
} else {
    Write-Host "[2/6] .gitignore já existe, seguindo..." -ForegroundColor Yellow
}

# 3) Adicionar arquivos
Write-Host "[3/6] Adicionando arquivos ao índice..." -ForegroundColor Yellow
git add .

# 4) Commit inicial (se ainda não houver commits)
$hasCommits = git rev-parse --quiet --verify HEAD 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[4/6] Criando commit inicial..." -ForegroundColor Yellow
    git commit -m "Primeiro commit da pasta publicada"
} else {
    Write-Host "[4/6] Criando commit de atualização..." -ForegroundColor Yellow
    git commit -m "Atualização da pasta publicada" 2>$null
}

# 5) Configurar branch main
Write-Host "[5/6] Garantindo que a branch principal é 'main'..." -ForegroundColor Yellow
git branch -M main

# 6) Configurar remoto e fazer push
Write-Host "[6/6] Configurando remoto 'origin' e enviando para o GitHub..." -ForegroundColor Yellow

# Remover origin antigo se existir
$hasOrigin = git remote | Select-String -Pattern "^origin$"
if ($hasOrigin) {
    git remote remove origin
}

git remote add origin $RemoteUrl

git push -u origin main

Write-Host "== Publicação concluída. Verifique no GitHub: $RemoteUrl ==" -ForegroundColor Green