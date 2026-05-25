# Cria a pasta Logs se não existir
$logsPath = 'C:\Users\user\Logs'
if (!(Test-Path $logsPath)) {
    New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
}

# Define caminhos
$desktopPath = 'C:\Users\user\Desktop\IA_Automate.lnk'
$scriptPath = Join-Path $PWD 'Master-Launcher-IA-Automate-Simples.ps1'

# Cria o atalho
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($desktopPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `\`$scriptPath`""
$shortcut.WorkingDirectory = $PWD
$shortcut.IconLocation = 'shell32.dll, 2'
$shortcut.Description = 'Inicia o sistema IA_Automate'
$shortcut.Save()

Write-Host 'Atalho IA_Automate.lnk criado com sucesso na área de trabalho!'