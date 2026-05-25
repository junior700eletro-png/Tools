from .contracts import ExpertContext
from .decision_engine import DecisionEngine

class ExpertEngine:
    def __init__(self):
        self.decision_engine = DecisionEngine()

    def processar(self, contexto: ExpertContext):
        decisoes = self.decision_engine.avaliar(contexto)
        return decisoes