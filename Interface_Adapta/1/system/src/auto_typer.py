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