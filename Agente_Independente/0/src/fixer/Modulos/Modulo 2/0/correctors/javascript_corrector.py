# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\modulos\modulo 2\0\correctors\javascript_corrector.py
# Arquivo: correctors/javascript_corrector.py

from .base_corrector import BaseCorrector

class JavaScriptCorrector(BaseCorrector):
    def correct(self, code, language):
        if language != 'javascript':
            return code
        if ';' not in code:
            return code + ';'
        return code
