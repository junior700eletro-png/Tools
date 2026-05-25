# Arquivo: test_validator.py
# Caminho: Agente_Independente / tests / test_validator.py
# Propósito: Testes unitários para o validador de compatibilidade

import unittest
import tempfile
import os
from ..validator import validate_compatibility


class TestValidator(unittest.TestCase):

    def test_script_valido(self):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as tmp:
            tmp.write('print("Hello, world!")
')
            tmp_path = tmp.name
        try:
            resultado = validate_compatibility(tmp_path)
            self.assertTrue(resultado)
        finally:
            os.unlink(tmp_path)

    def test_script_invalido(self):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as tmp:
            tmp.write('print(')
            tmp_path = tmp.name
        try:
            resultado = validate_compatibility(tmp_path)
            self.assertFalse(resultado)
        finally:
            os.unlink(tmp_path)

    def test_arquivo_inexistente(self):
        dir_temp = tempfile.gettempdir()
        caminho_inexistente = os.path.join(dir_temp, 'arquivo_inexistente.py')
        with self.assertRaises(FileNotFoundError):
            validate_compatibility(caminho_inexistente)


if __name__ == '__main__':
    unittest.main()

