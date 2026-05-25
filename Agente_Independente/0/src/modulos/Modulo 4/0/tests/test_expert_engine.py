import unittest
from src.engine.expert_engine import ExpertEngine
from src.engine.contracts import ExpertContext

class TestExpertEngine(unittest.TestCase):
    def test_processar(self):
        engine = ExpertEngine()
        ctx = ExpertContext(problema="Teste")
        resultado = engine.processar(ctx)
        self.assertIn("acao", resultado)