# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\modulos\modulo 2\0\patch_formatter.py
# Arquivo: patch_formatter.py

def format_patch(patch):
    lines = [line.strip() for line in patch.split('\n') if line.strip()]
    return '\n'.join(lines)

def apply_patch(code, patch):
    return code + '\n\n# Formatted patch applied:' + format_patch(patch)
