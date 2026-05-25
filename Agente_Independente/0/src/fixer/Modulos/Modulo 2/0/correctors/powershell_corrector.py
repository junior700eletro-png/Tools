# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\modulos\modulo 2\0\correctors\powershell_corrector.py
# Arquivo: correctors/powershell_corrector.py

from .base_corrector import BaseCorrector

class PowerShellCorrector(BaseCorrector):
    def correct(self, code, language):
        if language != 'powershell':
            return code
        if code.strip() == '':
            return 'Write-Output "Hello from PowerShell Corrector"'
        return code
