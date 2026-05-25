# core.py
from Interface_Adapta.system.main_orchestrator import MainOrchestrator

class FixerCore:
    def __init__(self):
        self.orchestrator = MainOrchestrator()
        self.patch_generator = PatchGenerator()
    
    def call_expert_corretor(self, erro: str, codigo: str) -> str:
        # Formata prompt
        prompt = f"[ERRO]\n{erro}\n\n[CÓDIGO ORIGINAL]\n{codigo}"
        
        # Chama Expert via Interface_Adapta
        resposta = self.orchestrator.send_message_to_adapta(prompt)
        
        # Retorna código corrigido
        return resposta