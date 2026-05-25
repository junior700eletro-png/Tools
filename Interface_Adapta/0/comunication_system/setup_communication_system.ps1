Add-Type -AssemblyName System.Windows.Forms

Write-Host "================================" -ForegroundColor Cyan
Write-Host "SETUP - Communication System" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Cyan

$pastas = @("src", "config", "logs", "output")

Write-Host "`nCriando estrutura de pastas..." -ForegroundColor Yellow
foreach ($pasta in $pastas) {
    if (-not (Test-Path $pasta)) {
        New-Item -Path $pasta -ItemType Directory -Force | Out-Null
        Write-Host "  OK - $pasta" -ForegroundColor Green
    }
}

Write-Host "`nCriando arquivos Python..." -ForegroundColor Yellow

$arquivo1 = "src/screen_reader.py"
$conteudo1 = "# screen_reader.py`nimport pyautogui`nimport pytesseract`nfrom PIL import Image`nfrom datetime import datetime`nimport os`n`nclass ScreenReader:`n    def __init__(self):`n        self.output_dir = 'output'`n        os.makedirs(self.output_dir, exist_ok=True)`n    `n    def capture_and_read(self, filename=None):`n        try:`n            if filename is None:`n                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')`n                filename = f'{self.output_dir}/screen_{timestamp}.png'`n            `n            screenshot = pyautogui.screenshot()`n            screenshot.save(filename)`n            text = pytesseract.image_to_string(screenshot, lang='por')`n            print(f'[READER] Tela capturada: {filename}')`n            return text, filename`n        except Exception as e:`n            print(f'[ERRO] ScreenReader: {str(e)}')`n            return None, None`n`nif __name__ == '__main__':`n    reader = ScreenReader()`n    print('[READER] Modulo carregado')"
[System.IO.File]::WriteAllText($arquivo1, $conteudo1, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo1" -ForegroundColor Green

$arquivo2 = "src/response_detector.py"
$conteudo2 = "# response_detector.py`nimport time`nfrom datetime import datetime`nfrom screen_reader import ScreenReader`n`nclass ResponseDetector:`n    def __init__(self, check_interval=10):`n        self.reader = ScreenReader()`n        self.check_interval = check_interval`n        self.last_response = None`n    `n    def detect_response(self):`n        try:`n            text, filename = self.reader.capture_and_read()`n            if text and '@#$-' in text:`n                print(f'[DETECTOR] Resposta detectada!')`n                self.last_response = {'timestamp': datetime.now().isoformat(), 'text': text, 'screenshot': filename}`n                return self.last_response`n            return None`n        except Exception as e:`n            print(f'[ERRO] ResponseDetector: {str(e)}')`n            return None`n`nif __name__ == '__main__':`n    detector = ResponseDetector()`n    print('[DETECTOR] Modulo carregado')"
[System.IO.File]::WriteAllText($arquivo2, $conteudo2, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo2" -ForegroundColor Green

$arquivo3 = "src/command_parser.py"
$conteudo3 = "# command_parser.py`nimport re`nfrom datetime import datetime`n`nclass CommandParser:`n    COMMANDS = {'@#$-copie-arquivo': {'desc': 'Copia arquivo'}, '@#$-execute-script': {'desc': 'Executa script'}, '@#$-criar-arquivo': {'desc': 'Cria arquivo'}, '@#$-capture-log': {'desc': 'Captura log'}, '@#$-capture-screenshot': {'desc': 'Screenshot'}, '@#$-status-sistema': {'desc': 'Status'}, '@#$-parar-sistema': {'desc': 'Para'}}`n    `n    @staticmethod`n    def parse_commands(text):`n        pattern = r'@#\$-([\w-]+)\(([^)]*)\)'`n        matches = re.findall(pattern, text)`n        return matches`n    `n    @staticmethod`n    def validate_command(cmd_name):`n        return cmd_name in CommandParser.COMMANDS`n`nif __name__ == '__main__':`n    parser = CommandParser()`n    print('[PARSER] Modulo carregado')"
[System.IO.File]::WriteAllText($arquivo3, $conteudo3, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo3" -ForegroundColor Green

$arquivo4 = "src/feedback_sender.py"
$conteudo4 = "# feedback_sender.py`nimport pyautogui`nimport time`nfrom datetime import datetime`nimport os`n`nclass FeedbackSender:`n    def __init__(self, delay=0.05):`n        self.delay = delay`n        self.log_file = 'logs/feedback.log'`n        os.makedirs('logs', exist_ok=True)`n    `n    def log(self, message):`n        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')`n        log_msg = f'[{timestamp}] {message}'`n        print(log_msg)`n        with open(self.log_file, 'a', encoding='utf-8') as f:`n            f.write(log_msg + '\\n')`n    `n    def send_text(self, text):`n        try:`n            self.log(f'Enviando {len(text)} caracteres...')`n            for char in text:`n                if char == '\\n':`n                    pyautogui.press('enter')`n                else:`n                    pyautogui.typewrite(char, interval=self.delay)`n                time.sleep(self.delay)`n            self.log('Texto enviado')`n            return True`n        except Exception as e:`n            self.log(f'ERRO: {str(e)}')`n            return False`n`nif __name__ == '__main__':`n    sender = FeedbackSender()`n    sender.log('FeedbackSender carregado')"
[System.IO.File]::WriteAllText($arquivo4, $conteudo4, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo4" -ForegroundColor Green

$arquivo5 = "src/main_orchestrator.py"
$conteudo5 = "# main_orchestrator.py`nimport time`nimport os`nfrom datetime import datetime`nfrom response_detector import ResponseDetector`nfrom command_parser import CommandParser`nfrom feedback_sender import FeedbackSender`n`nclass MainOrchestrator:`n    def __init__(self):`n        self.detector = ResponseDetector(check_interval=10)`n        self.parser = CommandParser()`n        self.sender = FeedbackSender(delay=0.05)`n        self.running = False`n        self.log_file = 'logs/orchestrator.log'`n        os.makedirs('logs', exist_ok=True)`n    `n    def log(self, message):`n        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')`n        log_msg = f'[{timestamp}] {message}'`n        print(log_msg)`n        with open(self.log_file, 'a', encoding='utf-8') as f:`n            f.write(log_msg + '\\n')`n    `n    def start(self):`n        self.running = True`n        self.log('=== ORQUESTRADOR INICIADO ===')`n        self.log('Aguardando resposta da IA...')`n        try:`n            while self.running:`n                self.log('Ciclo de monitoramento ativo')`n                time.sleep(10)`n        except KeyboardInterrupt:`n            self.log('Interrupção do usuário')`n            self.stop()`n        except Exception as e:`n            self.log(f'ERRO: {str(e)}')`n    `n    def stop(self):`n        self.running = False`n        self.log('=== ORQUESTRADOR PARADO ===')`n`nif __name__ == '__main__':`n    orchestrator = MainOrchestrator()`n    orchestrator.start()"
[System.IO.File]::WriteAllText($arquivo5, $conteudo5, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo5" -ForegroundColor Green

$arquivo6 = "config/settings.json"
$conteudo6 = "{`n  `"sistema`": {`n    `"nome`": `"Communication System`",`n    `"versao`": `"1.0.0`",`n    `"modo`": `"desenvolvimento`"`n  },`n  `"monitoramento`": {`n    `"intervalo_segundos`": 10,`n    `"ativar_ocr`": true,`n    `"idioma_ocr`": `"pt`"`n  }`n}"
[System.IO.File]::WriteAllText($arquivo6, $conteudo6, [System.Text.Encoding]::UTF8)
Write-Host "  OK - $arquivo6" -ForegroundColor Green

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "OK - Communication System pronto!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan
Write-Host "`nProximos passos:" -ForegroundColor Yellow
Write-Host "1. Execute: iniciar_communication_system.bat" -ForegroundColor Cyan
Write-Host "2. Sistema iniciara monitoramento" -ForegroundColor Cyan
Write-Host "3. Aguarde resposta da IA" -ForegroundColor Cyan