# screen_reader.py
import pyautogui
import pytesseract
from PIL import Image
from datetime import datetime
import os

class ScreenReader:
    def __init__(self):
        self.output_dir = 'output'
        os.makedirs(self.output_dir, exist_ok=True)
    
    def capture_and_read(self, filename=None):
        try:
            if filename is None:
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                filename = f'{self.output_dir}/screen_{timestamp}.png'
            
            screenshot = pyautogui.screenshot()
            screenshot.save(filename)
            text = pytesseract.image_to_string(screenshot, lang='por')
            print(f'[READER] Tela capturada: {filename}')
            return text, filename
        except Exception as e:
            print(f'[ERRO] ScreenReader: {str(e)}')
            return None, None

if __name__ == '__main__':
    reader = ScreenReader()
    print('[READER] Modulo carregado')