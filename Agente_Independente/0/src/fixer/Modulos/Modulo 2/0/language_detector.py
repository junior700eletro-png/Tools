# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\modulos\modulo 2\0\language_detector.py
# Arquivo: language_detector.py

def detect_language(code):
    python_patterns = ['def ', 'class ', 'import ']
    js_patterns = ['function ', 'let ', 'const ', '=>']
    ps_patterns = ['$','Write-Host','Get-']

    if any(p in code for p in python_patterns):
        return 'python'
    elif any(p in code for p in js_patterns):
        return 'javascript'
    elif any(p in code for p in ps_patterns):
        return 'powershell'
    return 'unknown'
