# Arquivo: Orquestrador_Central.ps1
# Caminho: PS1 tools / Orquestrador_Central.ps1
# Propósito: IDE centralizado que orquestra bootstrap, restore, agente e interface_adapta - VERSÃO ADAPTADA

# Configurações de caminhos
$username = $env:USERNAME
$scriptDir = "$env:USERPROFILE\Desktop\Tools\PS1 tools\" # Ajustado dinamicamente
$bootstrapPath = "C:\Users\$username\Desktop\Tools\Copiar_recriar_projetos\bootstrap_v1.ps1"
$restorePath = "C:\Users\$username\Desktop\Tools\Copiar_recriar_projetos\restore_bootstrap_v1.ps1"
$agentDir = "C:\Users\$username\Desktop\Tools\Agente_Independente"
$agentPath = "$agentDir\src\main.py"
$interfacePath = "C:\Users\$username\Desktop\Tools\Interface_Adapta"
$structuresDir = "C:\Users\$username\AppData\Local\estruturas_JSON"
$logsDir = "$structuresDir\logs"

# Criar diretórios se não existirem
New-Item -Path $structuresDir -ItemType Directory -Force | Out-Null
New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

$logOrquestrador = "$logsDir\orquestrador.log"
$logCaptura = "$logsDir\captura.log"
$logRestore = "$logsDir\restore.log"
$logAgente = "$logsDir\agente.log"

# Variáveis de jobs
$script:jobCaptura = $null
$script:jobRestore = $null
$script:jobAgente = $null

# Função de log
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    $logLine | Out-File -FilePath $logOrquestrador -Append -Encoding UTF8
}

# Carregar assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Criar form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Orquestrador Central"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"

# TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = "Fill"
$form.Controls.Add($tabControl)

# Aba CAPTURAR
$tabCapturar = New-Object System.Windows.Forms.TabPage
$tabCapturar.Text = "CAPTURAR"
$tabControl.Controls.Add($tabCapturar)

$btnIniciarCaptura = New-Object System.Windows.Forms.Button
$btnIniciarCaptura.Text = "Iniciar Captura"
$btnIniciarCaptura.Dock = "Top"
$btnIniciarCaptura.Height = 40
$btnIniciarCaptura.BackColor = [System.Drawing.Color]::LightGreen
$tabCapturar.Controls.Add($btnIniciarCaptura)

$btnPararCaptura = New-Object System.Windows.Forms.Button
$btnPararCaptura.Text = "Parar Captura"
$btnPararCaptura.Dock = "Top"
$btnPararCaptura.Height = 40
$btnPararCaptura.BackColor = [System.Drawing.Color]::LightCoral
$tabCapturar.Controls.Add($btnPararCaptura)

$lblStatusCaptura = New-Object System.Windows.Forms.Label
$lblStatusCaptura.Text = "Aguardando..."
$lblStatusCaptura.Dock = "Top"
$lblStatusCaptura.Height = 30
$lblStatusCaptura.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$tabCapturar.Controls.Add($lblStatusCaptura)

# Aba RESTAURAR
$tabRestaurar = New-Object System.Windows.Forms.TabPage
$tabRestaurar.Text = "RESTAURAR"
$tabControl.Controls.Add($tabRestaurar)

$btnIniciarRestore = New-Object System.Windows.Forms.Button
$btnIniciarRestore.Text = "Iniciar Restauração"
$btnIniciarRestore.Dock = "Top"
$btnIniciarRestore.Height = 40
$btnIniciarRestore.BackColor = [System.Drawing.Color]::LightGreen
$tabRestaurar.Controls.Add($btnIniciarRestore)

$btnPararRestore = New-Object System.Windows.Forms.Button
$btnPararRestore.Text = "Parar Restauração"
$btnPararRestore.Dock = "Top"
$btnPararRestore.Height = 40
$btnPararRestore.BackColor = [System.Drawing.Color]::LightCoral
$tabRestaurar.Controls.Add($btnPararRestore)

$lblStatusRestore = New-Object System.Windows.Forms.Label
$lblStatusRestore.Text = "Aguardando..."
$lblStatusRestore.Dock = "Top"
$lblStatusRestore.Height = 30
$lblStatusRestore.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$tabRestaurar.Controls.Add($lblStatusRestore)

# Aba AGENTE
$tabAgente = New-Object System.Windows.Forms.TabPage
$tabAgente.Text = "AGENTE"
$tabControl.Controls.Add($tabAgente)

$btnIniciarAgente = New-Object System.Windows.Forms.Button
$btnIniciarAgente.Text = "Iniciar Agente"
$btnIniciarAgente.Dock = "Top"
$btnIniciarAgente.Height = 40
$btnIniciarAgente.BackColor = [System.Drawing.Color]::LightGreen
$tabAgente.Controls.Add($btnIniciarAgente)

$btnPararAgente = New-Object System.Windows.Forms.Button
$btnPararAgente.Text = "Parar Agente"
$btnPararAgente.Dock = "Top"
$btnPararAgente.Height = 40
$btnPararAgente.BackColor = [System.Drawing.Color]::LightCoral
$tabAgente.Controls.Add($btnPararAgente)

$lblStatusAgente = New-Object System.Windows.Forms.Label
$lblStatusAgente.Text = "Aguardando..."
$lblStatusAgente.Dock = "Top"
$lblStatusAgente.Height = 30
$lblStatusAgente.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$tabAgente.Controls.Add($lblStatusAgente)

# Aba CONFIGURAÇÃO
$tabConfig = New-Object System.Windows.Forms.TabPage
$tabConfig.Text = "CONFIGURAÇÃO"
$tabControl.Controls.Add($tabConfig)

# Painel de status
$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Dock = "Top"
$pnlStatus.Height = 250
$pnlStatus.BackColor = [System.Drawing.Color]::LightGray
$tabConfig.Controls.Add($pnlStatus)

$yPos = 10
$lblBootstrapStatus = New-Object System.Windows.Forms.Label
$lblBootstrapStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblBootstrapStatus.Size = New-Object System.Drawing.Size(400, 25)
$lblBootstrapStatus.Text = "Bootstrap: Verificando..."
$lblBootstrapStatus.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$pnlStatus.Controls.Add($lblBootstrapStatus)
$yPos += 35

$lblRestoreStatus = New-Object System.Windows.Forms.Label
$lblRestoreStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblRestoreStatus.Size = New-Object System.Drawing.Size(400, 25)
$lblRestoreStatus.Text = "Restore: Verificando..."
$lblRestoreStatus.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$pnlStatus.Controls.Add($lblRestoreStatus)
$yPos += 35

$lblAgenteStatus = New-Object System.Windows.Forms.Label
$lblAgenteStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblAgenteStatus.Size = New-Object System.Drawing.Size(400, 25)
$lblAgenteStatus.Text = "Agente: Verificando..."
$lblAgenteStatus.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$pnlStatus.Controls.Add($lblAgenteStatus)
$yPos += 35

$lblInterfaceStatus = New-Object System.Windows.Forms.Label
$lblInterfaceStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblInterfaceStatus.Size = New-Object System.Drawing.Size(400, 25)
$lblInterfaceStatus.Text = "Interface Adapta: Verificando..."
$lblInterfaceStatus.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$pnlStatus.Controls.Add($lblInterfaceStatus)
$yPos += 35

$lblStructuresStatus = New-Object System.Windows.Forms.Label
$lblStructuresStatus.Location = New-Object System.Drawing.Point(10, $yPos)
$lblStructuresStatus.Size = New-Object System.Drawing.Size(400, 25)
$lblStructuresStatus.Text = "Estruturas JSON: Verificando..."
$lblStructuresStatus.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$pnlStatus.Controls.Add($lblStructuresStatus)

# Botões em config
$yBtn = 10
$btnAbrirInterface = New-Object System.Windows.Forms.Button
$btnAbrirInterface.Text = "Abrir Interface Adapta"
$btnAbrirInterface.Location = New-Object System.Drawing.Point(450, $yBtn)
$btnAbrirInterface.Size = New-Object System.Drawing.Size(150, 30)
$pnlStatus.Controls.Add($btnAbrirInterface)
$yBtn += 40

$btnLimparLogs = New-Object System.Windows.Forms.Button
$btnLimparLogs.Text = "Limpar Logs"
$btnLimparLogs.Location = New-Object System.Drawing.Point(450, $yBtn)
$btnLimparLogs.Size = New-Object System.Drawing.Size(150, 30)
$pnlStatus.Controls.Add($btnLimparLogs)

# RichTextBox para logs coloridos
$rtbLogs = New-Object System.Windows.Forms.RichTextBox
$rtbLogs.Dock = "Bottom"
$rtbLogs.Height = 400
$rtbLogs.BackColor = [System.Drawing.Color]::Black
$rtbLogs.ForeColor = [System.Drawing.Color]::Lime
$rtbLogs.Font = New-Object System.Drawing.Font("Consolas", 9)
$tabConfig.Controls.Add($rtbLogs)

# Funções
function Validate-Components {
    $bootstrapExists = Test-Path $bootstrapPath
    $lblBootstrapStatus.Text = if ($bootstrapExists) { "Bootstrap: ✅ OK" } else { "Bootstrap: ❌ FALTA" }
    $lblBootstrapStatus.ForeColor = if ($bootstrapExists) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }

    $restoreExists = Test-Path $restorePath
    $lblRestoreStatus.Text = if ($restoreExists) { "Restore: ✅ OK" } else { "Restore: ❌ FALTA" }
    $lblRestoreStatus.ForeColor = if ($restoreExists) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }

    $agenteExists = Test-Path $agentDir
    $lblAgenteStatus.Text = if ($agenteExists) { "Agente: ✅ OK" } else { "Agente: ❌ FALTA" }
    $lblAgenteStatus.ForeColor = if ($agenteExists) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }

    $interfaceExists = Test-Path $interfacePath
    $lblInterfaceStatus.Text = if ($interfaceExists) { "Interface: ✅ OK" } else { "Interface: ❌ FALTA" }
    $lblInterfaceStatus.ForeColor = if ($interfaceExists) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }

    $structuresExists = Test-Path $structuresDir
    $lblStructuresStatus.Text = if ($structuresExists) { "Estruturas: ✅ OK" } else { "Estruturas: ❌ CRIADO" }
    $lblStructuresStatus.ForeColor = [System.Drawing.Color]::Green

    Write-Log "Validação de componentes concluída."
}

function Update-Logs {
    if (-not (Test-Path $logOrquestrador)) { return }
    $lines = Get-Content $logOrquestrador -Tail 50 -ErrorAction SilentlyContinue
    if ($lines) {
        $rtbLogs.Clear()
        foreach ($line in $lines) {
            if ($line -match '\[ERROR\]') {
                $rtbLogs.SelectionColor = [System.Drawing.Color]::Red
            } elseif ($line -match '\[WARN\]') {
                $rtbLogs.SelectionColor = [System.Drawing.Color]::Orange
            } else {
                $rtbLogs.SelectionColor = [System.Drawing.Color]::Lime
            }
            $rtbLogs.AppendText("$line`r`n")
        }
        $rtbLogs.ScrollToCaret()
    }
}

function Update-Statuses {
    if ($script:jobCaptura) {
        $state = $script:jobCaptura.State
        $lblStatusCaptura.Text = "Status: $state"
        $lblStatusCaptura.ForeColor = switch ($state) {
            'Running' { [System.Drawing.Color]::Blue }
            'Completed' { [System.Drawing.Color]::Green }
            'Failed' { [System.Drawing.Color]::Red }
            default { [System.Drawing.Color]::Black }
        }
        if ($state -in @('Completed', 'Failed', 'Stopped')) {
            if ($state -eq 'Failed') {
                $output = Receive-Job $script:jobCaptura -ErrorAction SilentlyContinue
                Write-Log "Captura falhou: $output" "ERROR"
            } else {
                Write-Log "Captura concluída."
            }
            Remove-Job $script:jobCaptura -Force
            $script:jobCaptura = $null
        }
    }

    if ($script:jobRestore) {
        $state = $script:jobRestore.State
        $lblStatusRestore.Text = "Status: $state"
        $lblStatusRestore.ForeColor = switch ($state) {
            'Running' { [System.Drawing.Color]::Blue }
            'Completed' { [System.Drawing.Color]::Green }
            'Failed' { [System.Drawing.Color]::Red }
            default { [System.Drawing.Color]::Black }
        }
        if ($state -in @('Completed', 'Failed', 'Stopped')) {
            if ($state -eq 'Failed') {
                $output = Receive-Job $script:jobRestore -ErrorAction SilentlyContinue
                Write-Log "Restauração falhou: $output" "ERROR"
            } else {
                Write-Log "Restauração concluída."
            }
            Remove-Job $script:jobRestore -Force
            $script:jobRestore = $null
        }
    }

    if ($script:jobAgente) {
        $state = $script:jobAgente.State
        $lblStatusAgente.Text = "Status: $state"
        $lblStatusAgente.ForeColor = switch ($state) {
            'Running' { [System.Drawing.Color]::Blue }
            'Completed' { [System.Drawing.Color]::Green }
            'Failed' { [System.Drawing.Color]::Red }
            default { [System.Drawing.Color]::Black }
        }
        if ($state -in @('Completed', 'Failed', 'Stopped')) {
            if ($state -eq 'Failed') {
                $output = Receive-Job $script:jobAgente -ErrorAction SilentlyContinue
                Write-Log "Agente falhou: $output" "ERROR"
            } else {
                Write-Log "Agente concluído."
            }
            Remove-Job $script:jobAgente -Force
            $script:jobAgente = $null
        }
    }

    Update-Logs
}

# Eventos dos botões
$btnIniciarCaptura.Add_Click({
    if ($script:jobCaptura -and $script:jobCaptura.State -eq 'Running') {
        Write-Log "Captura já em execução." "WARN"
        return
    }
    if (-not (Test-Path $bootstrapPath)) {
        Write-Log "Arquivo bootstrap_v1.ps1 não encontrado." "ERROR"
        return
    }
    Write-Log "Iniciando captura via bootstrap_v1.ps1"
    $script:jobCaptura = Start-Job -ScriptBlock {
        param($path, $logfile)
        & $path 2>&1 | Out-File -FilePath $logfile -Append -Encoding UTF8
    } -ArgumentList $bootstrapPath, $logCaptura
})

$btnPararCaptura.Add_Click({
    if ($script:jobCaptura) {
        Stop-Job $script:jobCaptura -ErrorAction SilentlyContinue
        Write-Log "Captura interrompida."
    }
})

$btnIniciarRestore.Add_Click({
    if ($script:jobRestore -and $script:jobRestore.State -eq 'Running') {
        Write-Log "Restauração já em execução." "WARN"
        return
    }
    if (-not (Test-Path $restorePath)) {
        Write-Log "Arquivo restore_bootstrap_v1.ps1 não encontrado." "ERROR"
        return
    }
    Write-Log "Iniciando restauração via restore_bootstrap_v1.ps1"
    $script:jobRestore = Start-Job -ScriptBlock {
        param($path, $logfile)
        & $path 2>&1 | Out-File -FilePath $logfile -Append -Encoding UTF8
    } -ArgumentList $restorePath, $logRestore
})

$btnPararRestore.Add_Click({
    if ($script:jobRestore) {
        Stop-Job $script:jobRestore -ErrorAction SilentlyContinue
        Write-Log "Restauração interrompida."
    }
})

$btnIniciarAgente.Add_Click({
    if ($script:jobAgente -and $script:jobAgente.State -eq 'Running') {
        Write-Log "Agente já em execução." "WARN"
        return
    }
    if (-not (Test-Path $agentPath)) {
        Write-Log "Arquivo main.py não encontrado." "ERROR"
        return
    }
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $pythonPath) {
        Write-Log "Python não encontrado no PATH." "ERROR"
        return
    }
    Write-Log "Iniciando agente via python main.py"
    $script:jobAgente = Start-Job -ScriptBlock {
        param($python, $path, $logfile)
        & $python $path 2>&1 | Out-File -FilePath $logfile -Append -Encoding UTF8
    } -ArgumentList $pythonPath, $agentPath, $logAgente
})

$btnPararAgente.Add_Click({
    if ($script:jobAgente) {
        Stop-Job $script:jobAgente -ErrorAction SilentlyContinue
        Write-Log "Agente interrompido."
    }
})

$btnAbrirInterface.Add_Click({
    if (Test-Path $interfacePath) {
        Invoke-Item $interfacePath
        Write-Log "Interface Adapta aberta."
    } else {
        Write-Log "Interface Adapta não encontrada." "ERROR"
    }
})

$btnLimparLogs.Add_Click({
    $rtbLogs.Clear()
    if (Test-Path $logOrquestrador) { Clear-Content $logOrquestrador }
    Write-Log "Logs limpos."
})

# Timer para polling
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.Add_Tick({ Update-Statuses })

# Eventos do form
$form.Add_Shown({
    Validate-Components
    $timer.Start()
    Update-Logs
})

$form.Add_Closing({
    $timer.Stop()
    if ($script:jobCaptura) { Stop-Job $script:jobCaptura -ErrorAction SilentlyContinue; Remove-Job $script:jobCaptura -Force }
    if ($script:jobRestore) { Stop-Job $script:jobRestore -ErrorAction SilentlyContinue; Remove-Job $script:jobRestore -Force }
    if ($script:jobAgente) { Stop-Job $script:jobAgente -ErrorAction SilentlyContinue; Remove-Job $script:jobAgente -Force }
})

# Mostrar form
[System.Windows.Forms.Application]::Run($form)

