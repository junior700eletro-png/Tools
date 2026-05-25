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