param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AgentProject = 'C:\Users\user\Desktop\Tools\Agente_Independente\0'
$ProjetoCotacao = 'C:\Users\user\Python\ProjetoPython\ProjetoCotacao'

try {
    Write-Host '=\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\=' -ForegroundColor Cyan
    Write-Host 'Iniciando teste do agente...' -ForegroundColor Cyan
    Write-Host '=\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\==\=' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Verificando Python...' -ForegroundColor Yellow
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonCmd) {
        throw 'Python não encontrado! Instale o Python e adicione ao PATH.'
    }
    $pythonVersion = & python --version 2>$null
    Write-Host "Python encontrado: $pythonVersion" -ForegroundColor Green
    Write-Host ''

    Write-Host 'Validando caminhos dos projetos...' -ForegroundColor Yellow
    if (-not (Test-Path $AgentProject)) {
        throw "Projeto agente não encontrado: $AgentProject"
    }
    Write-Host "Projeto agente OK: $AgentProject" -ForegroundColor Green

    if (-not (Test-Path $ProjetoCotacao)) {
        throw "Projeto Cotação não encontrado: $ProjetoCotacao"
    }
    Write-Host "Projeto Cotação OK: $ProjetoCotacao" -ForegroundColor Green
    Write-Host ''

    Set-Location $AgentProject
    Write-Host "Diretório atual: $(Get-Location)" -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Criando estrutura de pastas...' -ForegroundColor Yellow
    $srcDir = Join-Path $AgentProject 'src'
    $analyzerDir = Join-Path $srcDir 'analyzer'

    if (-not (Test-Path $srcDir)) {
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
        Write-Host 'Pasta src/ criada.' -ForegroundColor Green
    }

    if (-not (Test-Path $analyzerDir)) {
        New-Item -ItemType Directory -Path $analyzerDir -Force | Out-Null
        Write-Host 'Pasta src/analyzer criada.' -ForegroundColor Green
    } else {
        Write-Host 'Pasta src/analyzer já existe.' -ForegroundColor Cyan
    }
    Write-Host ''

    $filesToAnalyzer = @(
        '__init__.py',
        'project_analyzer.py',
        'pytest_runner.py',
        'linter_runner.py',
        'report_generator.py'
    )

    Write-Host 'Copiando arquivos para src/analyzer...' -ForegroundColor Yellow
    $copiedCount = 0
    foreach ($file in $filesToAnalyzer) {
        $source = Join-Path $AgentProject $file
        $dest = Join-Path $analyzerDir $file
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $dest -Force
            Write-Host "  Copiado: $file" -ForegroundColor Green
            $copiedCount++
        } else {
            Write-Warning "  Arquivo não encontrado: $file"
        }
    }
    Write-Host "Total copiado para analyzer: $copiedCount/5" -ForegroundColor Cyan

    Write-Host 'Copiando main.py para src/...' -ForegroundColor Yellow
    $mainSource = Join-Path $AgentProject 'main.py'
    $mainDest = Join-Path $srcDir 'main.py'
    if (Test-Path $mainSource) {
        Copy-Item -Path $mainSource -Destination $mainDest -Force
        Write-Host '  Copiado: main.py -> src/' -ForegroundColor Green
    } else {
        Write-Warning '  main.py não encontrado no diretório raiz.'
    }
    Write-Host ''

    Write-Host 'Executando o agente...' -ForegroundColor Yellow
    $output = & python 'src/main.py' $ProjetoCotacao 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host '✅ Teste executado com SUCESSO!' -ForegroundColor Green
        Write-Host ''
        Write-Host 'Saída do script:' -ForegroundColor Cyan
        Write-Host $output -ForegroundColor White
        Write-Host ''

        $reportFiles = Get-ChildItem -Path $AgentProject -Filter '*report*.html' -Recurse -ErrorAction SilentlyContinue
        if ($reportFiles) {
            Write-Host '📊 Relatórios gerados:' -ForegroundColor Green
            foreach ($report in $reportFiles) {
                Write-Host "   $($report.FullName)" -ForegroundColor Green
            }
        } else {
            Write-Host 'ℹ️  Verifique a saída acima para o caminho do relatório.' -ForegroundColor Yellow
        }
    } else {
        Write-Host '❌ ERRO na execução do teste! (Código: $exitCode)' -ForegroundColor Red
        Write-Host ''
        Write-Host 'Saída de erro:' -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
    }

    Write-Host ''
    Write-Host '🎉 Processo concluído!' -ForegroundColor Cyan

} catch {
    Write-Host ''
    Write-Host '💥 ERRO CRÍTICO:' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
