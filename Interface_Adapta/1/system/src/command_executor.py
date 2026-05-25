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