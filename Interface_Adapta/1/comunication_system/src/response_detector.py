# response_detector.py
import time
from datetime import datetime
from screen_reader import ScreenReader

class ResponseDetector:
    def __init__(self, check_interval=10):
        self.reader = ScreenReader()
        self.check_interval = check_interval
        self.last_response = None
    
    def detect_response(self):
        try:
            text, filename = self.reader.capture_and_read()
            if text and '@#$-' in text:
                print(f'[DETECTOR] Resposta detectada!')
                self.last_response = {'timestamp': datetime.now().isoformat(), 'text': text, 'screenshot': filename}
                return self.last_response
            return None
        except Exception as e:
            print(f'[ERRO] ResponseDetector: {str(e)}')
            return None

if __name__ == '__main__':
    detector = ResponseDetector()
    print('[DETECTOR] Modulo carregado')