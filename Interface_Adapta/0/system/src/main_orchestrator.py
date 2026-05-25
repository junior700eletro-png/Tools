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