# main_orchestrator.py
import time
import os
from datetime import datetime
from response_detector import ResponseDetector
from command_parser import CommandParser
from feedback_sender import FeedbackSender

class MainOrchestrator:
    def __init__(self):
        self.detector = ResponseDetector(check_interval=10)
        self.parser = CommandParser()
        self.sender = FeedbackSender(delay=0.05)
        self.running = False
        self.log_file = 'logs/orchestrator.log'
        os.makedirs('logs', exist_ok=True)
    
    def log(self, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f'[{timestamp}] {message}'
        print(log_msg)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_msg + '\\n')
    
    def start(self):
        self.running = True
        self.log('=== ORQUESTRADOR INICIADO ===')
        self.log('Aguardando resposta da IA...')
        try:
            while self.running:
                self.log('Ciclo de monitoramento ativo')
                time.sleep(10)
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