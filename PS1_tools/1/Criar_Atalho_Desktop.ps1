# VALIDAÇÃO RIGOROSA - Script PowerShell MINIMALISTA
# Arquivo: Criar_Atalho_Desktop.ps1
# Propósito: Criar atalho do Orquestrador_Central.ps1 na área de trabalho

# REGRAS ABSOLUTAS:
# 1. Sem variáveis complexas - apenas strings simples
# 2. Sem quebras de linha em strings
# 3. Sem caracteres especiais ou acentos
# 4. Cada atribuição em uma linha
# 5. Sem backticks ou escaping complexo
# 6. Try-catch minimalista

$sp = "$env:USERPROFILE\Desktop\Tools\PS1 tools\Orquestrador_Central.ps1"
$sc = "$env:USERPROFILE\Desktop\Orquestrador_Central.lnk"
$wd = "$env:USERPROFILE\Desktop\Tools\PS1 tools"
$pe = "$env:SystemRoot\system32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path $sp)) {
    Write-Host "Arquivo nao encontrado" -ForegroundColor Red
    exit 1
}

if (Test-Path $sc) {
    Remove-Item $sc -Force
}

try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($sc)
    $shortcut.TargetPath = $pe
    $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File " + '"' + $sp + '"'
    $shortcut.WorkingDirectory = $wd
    $shortcut.IconLocation = $pe + ",0"
    $shortcut.Description = "IDE Centralizado"
    $shortcut.WindowStyle = 1
    $shortcut.Save()
    Write-Host "Sucesso!" -ForegroundColor Green
} catch {
    Write-Host "Erro" -ForegroundColor Red
    exit 1
}
