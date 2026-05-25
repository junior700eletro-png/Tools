# feedback_sender.py
import pyautogui
import time
from datetime import datetime
import os

class FeedbackSender:
    def __init__(self, delay=0.05):
        self.delay = delay
        self.log_file = 'logs/feedback.log'
        os.makedirs('logs', exist_ok=True)
    
    def log(self, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f'[{timestamp}] {message}'
        print(log_msg)
        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(log_msg + '\\n')
    
    def send_text(self, text):
        try:
            self.log(f'Enviando {len(text)} caracteres...')
            for char in text:
                if char == '\\n':
                    pyautogui.press('enter')
                else:
                    pyautogui.typewrite(char, interval=self.delay)
                time.sleep(self.delay)
            self.log('Texto enviado')
            return True
        except Exception as e:
            self.log(f'ERRO: {str(e)}')
            return False

if __name__ == '__main__':
    sender = FeedbackSender()
    sender.log('FeedbackSender carregado')