Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "================================" -ForegroundColor Cyan
Write-Host "BOOTSTRAPPER - Desempacotando Projeto" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Cyan

$baseDir = "system"
if (-not (Test-Path $baseDir)) {
    New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
    Write-Host "Pasta $baseDir criada" -ForegroundColor Green
}

$projectData = @{
    "pastas" = @("$baseDir/src", "$baseDir/config", "$baseDir/logs", "$baseDir/output")
    "arquivos" = @(
        @{
            "caminho" = "$baseDir/src/communication_protocol.py"
            "conteudo" = @"
import re
import json
from datetime import datetime

class CommandProtocol:
    COMMANDS = {
        '@#$-copie-arquivo': {'desc': 'Copia arquivo para clipboard', 'params': ['caminho']},
        '@#$-copie-pasta': {'desc': 'Copia estrutura de pasta', 'params': ['caminho']},
        '@#$-execute-script': {'desc': 'Executa script Python', 'params': ['nome']},
        '@#$-capture-log': {'desc': 'Captura log e envia', 'params': ['nome']},
        '@#$-capture-screenshot': {'desc': 'Tira screenshot', 'params': []},
        '@#$-criar-arquivo': {'desc': 'Cria novo arquivo', 'params': ['caminho']},
        '@#$-status-sistema': {'desc': 'Retorna status', 'params': []},
        '@#$-parar-sistema': {'desc': 'Para o loop', 'params': []}
    }
    
    @staticmethod
    def parse_command(text):
        pattern = r'@#\$-([\w-]+)\(([^)]*)\)'
        matches = re.findall(pattern, text)
        return matches
    
    @staticmethod
    def validate_command(cmd_name):
        return cmd_name in CommandProtocol.COMMANDS
    
    @staticmethod
    def get_command_info(cmd_name):
        return CommandProtocol.COMMANDS.get(cmd_name, None)

if __name__ == '__main__':
    print('[PROTOCOLO] Comunicação carregada')
    for cmd, info in CommandProtocol.COMMANDS.items():
        print(f'  {cmd}: {info["desc"]}')
"@
        }
        @{
            "caminho" = "$baseDir/config/settings.json"
            "conteudo" = @"
{
  "sistema": {
    "nome": "Adapta Communication System",
    "versao": "1.0.0",
    "modo": "desenvolvimento"
  },
  "monitoramento": {
    "intervalo_segundos": 10,
    "ativar_ocr": true,
    "idioma_ocr": "pt"
  },
  "caminhos": {
    "base": "system",
    "logs": "system/logs",
    "output": "system/output"
  }
}
"@
        }
        @{
            "caminho" = "$baseDir/src/screen_monitor.py"
            "conteudo" = @"
import time
import pyautogui
from datetime import datetime
import json
import os

class ScreenMonitor:
    def __init__(self, interval=10):
        self.interval = interval
        self.running = False
        self.last_screenshot = None
        self.output_dir = 'system/output'
    
    def capture_screenshot(self, filename=None):
        try:
            os.makedirs(self.output_dir, exist_ok=True)
            if filename is None:
                filename = f'{self.output_dir}/screenshot_{datetime.now().strftime(\"%Y%m%d_%H%M%S\")}.png'
            
            screenshot = pyautogui.screenshot()
            screenshot.save(filename)
            print(f'[SCREENSHOT] Capturada: {filename}')
            return filename
        except Exception as e:
            print(f'[ERRO] Screenshot: {str(e)}')
            return None
    
    def start_monitoring(self):
        self.running = True
        print(f'[MONITOR] Iniciado - intervalo: {self.interval}s')
        
        while self.running:
            try:
                self.capture_screenshot()
                time.sleep(self.interval)
            except Exception as e:
                print(f'[ERRO] Monitor: {str(e)}')
                break
    
    def stop_monitoring(self):
        self.running = False
        print('[MONITOR] Parado')

if __name__ == '__main__':
    monitor = ScreenMonitor(interval=10)
    monitor.start_monitoring()
"@
        }
        @{
            "caminho" = "$baseDir/src/auto_typer.py"
            "conteudo" = @"
import pyautogui
import time
from datetime import datetime

class AutoTyper:
    def __init__(self, delay=0.05):
        self.delay = delay
    
    def type_text(self, text, target_window=None):
        print(f'[TYPER] Digitando {len(text)} caracteres...')
        
        for char in text:
            if char == '\\n':
                pyautogui.press('enter')
            elif char == '\t':
                pyautogui.press('tab')
            else:
                try:
                    pyautogui.typewrite(char, interval=self.delay)
                except:
                    pyautogui.write(char)
            time.sleep(self.delay)
        
        print(f'[TYPER] Concluído')
    
    def click_and_type(self, x, y, text):
        print(f'[TYPER] Clicando em ({x}, {y}) e digitando...')
        pyautogui.click(x, y)
        time.sleep(0.5)
        self.type_text(text)

if __name__ == '__main__':
    typer = AutoTyper()
    print('[TYPER] Módulo carregado')
"@
        }
        @{
            "caminho" = "$baseDir/src/command_executor.py"
            "conteudo" = @"
import os
import subprocess
import shutil
import pyautogui
from datetime import datetime
from communication_protocol import CommandProtocol

class CommandExecutor:
    def __init__(self):
        self.log_file = 'system/logs/executor.log'
        os.makedirs('system/logs', exist_ok=True)
    
    def log(self, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f'[{timestamp}] {message}'
        print(log_msg)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_msg + '\\n')
    
    def copie_arquivo(self, caminho):
        try:
            with open(caminho, 'r', encoding='utf-8') as f:
                conteudo = f.read()
            pyautogui.typewrite(conteudo)
            self.log(f'Arquivo copiado: {caminho}')
            return True
        except Exception as e:
            self.log(f'ERRO ao copiar arquivo: {str(e)}')
            return False
    
    def execute_script(self, nome):
        try:
            result = subprocess.run(['python', nome], capture_output=True, text=True)
            self.log(f'Script executado: {nome}')
            self.log(f'Output: {result.stdout}')
            if result.stderr:
                self.log(f'Erro: {result.stderr}')
            return result.stdout
        except Exception as e:
            self.log(f'ERRO ao executar script: {str(e)}')
            return None
    
    def criar_arquivo(self, caminho, conteudo=''):
        try:
            os.makedirs(os.path.dirname(caminho), exist_ok=True)
            with open(caminho, 'w', encoding='utf-8') as f:
                f.write(conteudo)
            self.log(f'Arquivo criado: {caminho}')
            return True
        except Exception as e:
            self.log(f'ERRO ao criar arquivo: {str(e)}')
            return False
    
    def capture_log(self, nome):
        try:
            with open(nome, 'r', encoding='utf-8') as f:
                conteudo = f.read()
            pyautogui.typewrite(conteudo)
            self.log(f'Log capturado: {nome}')
            return True
        except Exception as e:
            self.log(f'ERRO ao capturar log: {str(e)}')
            return False
    
    def execute_command(self, cmd_text):
        commands = CommandProtocol.parse_command(cmd_text)
        for cmd_name, params in commands:
            if CommandProtocol.validate_command(f'@#$-{cmd_name}'):
                self.log(f'Executando: @#$-{cmd_name}({params})')
                if cmd_name == 'copie-arquivo':
                    self.copie_arquivo(params)
                elif cmd_name == 'execute-script':
                    self.execute_script(params)
                elif cmd_name == 'criar-arquivo':
                    self.criar_arquivo(params)
                elif cmd_name == 'capture-log':
                    self.capture_log(params)

if __name__ == '__main__':
    executor = CommandExecutor()
    executor.log('Executor carregado')
"@
        }
        @{
            "caminho" = "$baseDir/src/main_orchestrator.py"
            "conteudo" = @"
import time
import threading
import os
from datetime import datetime
from screen_monitor import ScreenMonitor
from auto_typer import AutoTyper
from command_executor import CommandExecutor
from communication_protocol import CommandProtocol

class MainOrchestrator:
    def __init__(self):
        self.monitor = ScreenMonitor(interval=10)
        self.typer = AutoTyper(delay=0.05)
        self.executor = CommandExecutor()
        self.running = False
        self.log_file = 'system/logs/orchestrator.log'
        os.makedirs('system/logs', exist_ok=True)
    
    def log(self, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f'[{timestamp}] {message}'
        print(log_msg)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_msg + '\\n')
    
    def start(self):
        self.running = True
        self.log('=== ORQUESTRADOR INICIADO ===')
        self.log('Aguardando entrada...')
        
        while self.running:
            try:
                time.sleep(10)
                self.log('Ciclo de monitoramento ativo')
            except KeyboardInterrupt:
                self.log('Interrupção do usuário')
                self.stop()
            except Exception as e:
                self.log(f'ERRO: {str(e)}')
    
    def stop(self):
        self.running = False
        self.log('=== ORQUESTRADOR PARADO ===')

if __name__ == '__main__':
    orchestrator = MainOrchestrator()
    orchestrator.start()
"@
        }
    )
}

Write-Host "`nCriando estrutura de pastas..." -ForegroundColor Yellow
foreach ($pasta in $projectData.pastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -Path $pasta -ItemType Directory -Force | Out-Null
        Write-Host "  ✓ $pasta" -ForegroundColor Green
    }
}

Write-Host "`nCriando arquivos..." -ForegroundColor Yellow
foreach ($arquivo in $projectData.arquivos) {
    $caminho = $arquivo.caminho
    $conteudo = $arquivo.conteudo
    
    $dir = Split-Path $caminho
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    
    [System.IO.File]::WriteAllText($caminho, $conteudo, [System.Text.Encoding]::UTF8)
    Write-Host "  ✓ $caminho" -ForegroundColor Green
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "✓ Projeto desempacotado com sucesso!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host "`nEstrutura criada em: system/" -ForegroundColor Yellow
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Execute: iniciar_communication_system.bat" -ForegroundColor Cyan
Write-Host "2. Sistema iniciará monitoramento" -ForegroundColor Cyan
Write-Host "3. Aguarde comunicação da IA" -ForegroundColor Cyan