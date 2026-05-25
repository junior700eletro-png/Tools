
$projectPath = $PSScriptRoot

$bat1Path = Join-Path $projectPath 'iniciar1.bat'

if (-not (Test-Path $bat1Path)) {
    Write-Host 'ERRO: iniciar1.bat nao encontrado em ' $projectPath -ForegroundColor Red
    Read-Host 'Pressionar Enter para sair'
    exit 1
}

function Test-Health {
    try {
        $resp = Invoke-WebRequest -Uri 'http://localhost:8000' -TimeoutSec 5 -UseBasicParsing -MaximumRedirection 0
        return $resp.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Show-Status {
    Write-Host "\n=== STATUS DOS SERVICOS ===" -ForegroundColor Cyan
    Write-Host 'Servico Principal (porta 8000): ' -NoNewline
    if (Test-Health) {
        Write-Host 'ONLINE' -ForegroundColor Green
    } else {
        Write-Host 'OFFLINE' -ForegroundColor Red
    }
    Write-Host 'Processo iniciar1.bat: ' -NoNewline
    if ($proc1 -and -not $proc1.HasExited) {
        Write-Host "EXECUTANDO (PID: $($proc1.Id))" -ForegroundColor Green
    } elseif ($proc1) {
        Write-Host 'CONCLUIDO' -ForegroundColor Yellow
    } else {
        Write-Host 'NAO INICIADO' -ForegroundColor Red
    }
    Write-Host 'Servico Communication: ' -NoNewline
    if ($proc2 -and -not $proc2.HasExited) {
        Write-Host "EXECUTANDO (PID: $($proc2.Id))" -ForegroundColor Green
    } elseif ($proc2) {
        Write-Host 'CONCLUIDO' -ForegroundColor Yellow
    } else {
        Write-Host 'NAO INICIADO' -ForegroundColor Red
    }
    Write-Host 'Para logs detalhados, verifique as janelas dos processos ou arquivos de log.' -ForegroundColor Yellow
}

Write-Host '=== Iniciando IA Automate ===' -ForegroundColor Cyan
Write-Host 'Executando iniciar1.bat...' -ForegroundColor Green

$proc1 = Start-Process -FilePath $bat1Path -WorkingDirectory $projectPath -PassThru

if (-not $proc1) {
    Write-Host 'Falha ao iniciar iniciar1.bat!' -ForegroundColor Red
    Read-Host 'Pressionar Enter para sair'
    exit 1
}

Write-Host 'Aguardando health check na porta 8000...' -ForegroundColor Yellow
$dots = 0
while (-not (Test-Health)) {
    Write-Host '.' -NoNewline -ForegroundColor Yellow
    $dots++
    if ($dots % 40 -eq 0) { Write-Host '' -ForegroundColor Yellow }
    Start-Sleep 2
}
Write-Host '\nHealth check OK!' -ForegroundColor Green

$comFolder = Join-Path $projectPath 'comunication_system'
$bat2Path = Join-Path $comFolder 'Init_Com.bat'

Write-Host 'Executando Init_Com.bat...' -ForegroundColor Green
if (Test-Path $bat2Path) {
    $proc2 = Start-Process -FilePath $bat2Path -WorkingDirectory $comFolder -PassThru
} else {
    Write-Host 'AVISO: Init_Com.bat nao encontrado em ' $comFolder -ForegroundColor Red
    $proc2 = $null
}

Show-Status

do {
    $choice = Read-Host "\n--- MENU ---\n1. Pausar\n2. Logs/Status\n3. Sair\nEscolha (1-3): "
    switch ($choice) {
        '1' {
            Write-Host 'Pausado. Pressione qualquer tecla para continuar...' -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        '2' {
            Show-Status
        }
        '3' {
            break
        }
        default {
            Write-Host 'Opcao invalida! Tente 1, 2 ou 3.' -ForegroundColor Red
        }
    }
} while ($true)

Write-Host 'Saindo... Os processos continuam rodando.' -ForegroundColor Cyan