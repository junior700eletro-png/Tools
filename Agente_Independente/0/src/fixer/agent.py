# Arquivo: agent.py
# Caminho: Agente_Independente / src / fixer / agent.py
# Propósito: Orquestrar fluxo de análise, geração de patch, aplicação e validação

from .core.fixer_core import FixerCore
from .executor import PatchExecutor
from .validators import CompatibilityValidator


class FixerAgent:
    """
    Agente principal para orquestrar o processo de correção de scripts.
    """

    def fix_script(self, script_path: str) -> dict:
        """
        Executa o fluxo completo: análise, geração de patch, aplicação e validação.

        :param script_path: Caminho para o script a ser corrigido.
        :return: Dicionário com status final e resultados.
        """
        # Análise e geração do patch via FixerCore
        fixer_core = FixerCore()
        analysis = fixer_core.analyze(script_path)
        patch = fixer_core.generate_patch(analysis)

        # Aplicação do patch via PatchExecutor
        patch_executor = PatchExecutor()
        apply_result = patch_executor.apply_patch(script_path, patch)

        # Validação do resultado via CompatibilityValidator
        validator = CompatibilityValidator()
        validation = validator.validate(script_path)

        # Determina status final
        status = "success" if validation.get("valid", False) else "failed"

        return {
            "status": status,
            "analysis": analysis,
            "patch": patch,
            "apply_result": apply_result,
            "validation": validation
        }

