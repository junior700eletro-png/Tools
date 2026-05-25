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
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f'{self.output_dir}/screenshot_{timestamp}.png'
            
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