# command_parser.py
import re
from datetime import datetime

class CommandParser:
    COMMANDS = {'@#$-copie-arquivo': {'desc': 'Copia arquivo'}, '@#$-execute-script': {'desc': 'Executa script'}, '@#$-criar-arquivo': {'desc': 'Cria arquivo'}, '@#$-capture-log': {'desc': 'Captura log'}, '@#$-capture-screenshot': {'desc': 'Screenshot'}, '@#$-status-sistema': {'desc': 'Status'}, '@#$-parar-sistema': {'desc': 'Para'}}
    
    @staticmethod
    def parse_commands(text):
        pattern = r'@#\$-([\w-]+)\(([^)]*)\)'
        matches = re.findall(pattern, text)
        return matches
    
    @staticmethod
    def validate_command(cmd_name):
        return cmd_name in CommandParser.COMMANDS

if __name__ == '__main__':
    parser = CommandParser()
    print('[PARSER] Modulo carregado')