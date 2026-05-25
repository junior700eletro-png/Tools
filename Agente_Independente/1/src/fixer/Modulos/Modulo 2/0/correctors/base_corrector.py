# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\modulos\modulo 2\0\correctors\base_corrector.py
# Arquivo: correctors/base_corrector.py

class BaseCorrector:
    def __init__(self):
        pass

    def correct(self, code, language):
        raise NotImplementedError(f"Correct method must be implemented for {{language}}")

    def validate(self, code):
        return len(code) > 0
