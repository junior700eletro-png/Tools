import unittest

from main import get_hello

class TestProjeto4Completo(unittest.TestCase):
    def test_get_hello(self):
        self.assertEqual(get_hello(), "Olá, Projeto 4 Completo!")

if __name__ == "__main__":
    unittest.main()