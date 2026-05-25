# Arquivo: core.py
# Caminho: Agente_Independente / src / fixer / core.py
# Propósito: Lógica principal de análise e geração de patches

import re
import os

class FixerCore:
    def analyze_error(self, script_path, error_message):
        """
        Analisa a mensagem de erro para extrair informações relevantes,
        como número da linha e tipo de erro.
        """
        line_match = re.search(r'line (\d+)', error_message)
        line = int(line_match.group(1)) if line_match else None
        
        error_type_match = re.search(r'([A-Za-z]+Error):', error_message)
        error_type = error_type_match.group(1) if error_type_match else 'Unknown'
        
        return {
            'line': line,
            'error_type': error_type,
            'message': error_message
        }

    def generate_patch(self, script_path, error_message):
        """
        Gera a estrutura de patch baseada na análise do erro.
        Esperado por PatchExecutor: chaves 'target_file' e 'patches'.
        """
        analysis = self.analyze_error(script_path, error_message)
        
        if not os.path.exists(script_path):
            return {'target_file': script_path, 'patches': []}
        
        with open(script_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        patches = []
        if analysis['line']:
            line_num = analysis['line'] - 1  # 0-based index
            if 0 <= line_num < len(lines):
                original_line = lines[line_num].rstrip('\n')
                
                # Heurística simples para SyntaxError em print sem aspas
                if (analysis['error_type'] == 'SyntaxError' and
                    'print(' in original_line and
                    not any(q in original_line for q in ['\"', "'"])):
                    
                    fixed_line = original_line.replace('print(', 'print(\"')
                    if not original_line.strip().endswith(')'):
                        fixed_line += '\")'
                    patches.append({
                        'start_line': line_num + 1,
                        'end_line': line_num + 1,
                        'replacement': fixed_line + '\n'
                    })
        
        return {
            'target_file': script_path,
            'patches': patches
        }
