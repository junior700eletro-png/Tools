# install.ps1
$baseDir = "C:\Users\$env:USERNAME\Desktop\Scripts_Adapta"
Write-Host "Criando ambiente em $baseDir..." -ForegroundColor Cyan
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir -Force | Out-Null }
Write-Host "Ambiente preparado! Coloque os scripts criar_projeto.ps1 e salvar_arquivo.ps1 na pasta $baseDir." -ForegroundColor Green
