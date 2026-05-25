# agent_v2.py
from __future__ import annotations

from pathlib import Path
from typing import Any
import sys

# Imports dos módulos críticos
from analyser.analyzer import Analyzer
from fixer.core_v2 import FixerCoreV2, FixResult
from patches.executor import PatchExecutor, ExecutionResult
from validador.validators import CodeValidator, ValidationResult
from guardrails.guardrails import Guardrails


class AutonomousAgent:
    """
    Agente autônomo de depuração de código Python.
    
    Fluxo:
    1. Analisa código (Analyzer)
    2. Valida segurança (Guardrails)
    3. Gera correções (FixerCoreV2)
    4. Aplica patches (PatchExecutor)
    5. Valida resultado (CodeValidator)
    """
    
    def __init__(self, workspace_dir: str | Path, config_path: str | Path | None = None):
        self.workspace_dir = Path(workspace_dir)
        
        # Inicializar módulos
        self.analyzer = Analyzer()
        self.fixer_core = FixerCoreV2(workspace_dir=self.workspace_dir)
        self.executor = PatchExecutor(backup_suffix=".bak")
        self.validator = CodeValidator()
        self.guardrails = Guardrails(config_path=config_path)
        
        self.execution_log: list[dict[str, Any]] = []
    
    def analyze_and_fix(self, file_path: str | Path) -> dict[str, Any]:
        """
        Analisa um arquivo Python e tenta corrigir automaticamente.
        
        Returns:
            Dict com resultado da operação completa
        """
        path = Path(file_path)
        
        # Log de início
        result = {
            "file": str(path),
            "success": False,
            "steps": [],
            "final_message": "",
        }
        
        # STEP 1: Validar segurança
        guardrail_check = self.guardrails.check_path(path)
        result["steps"].append({"step": "guardrails", "result": guardrail_check.to_dict()})
        
        if not guardrail_check.allowed:
            result["final_message"] = f"Bloqueado por guardrails: {guardrail_check.message}"
            self.execution_log.append(result)
            return result
        
        # STEP 2: Análise de código
        issues = self.analyzer.analyze_file(path)
        result["steps"].append({
            "step": "analysis",
            "issues_found": len(issues),
            "issues": [issue.to_dict() for issue in issues]
        })
        
        if not issues:
            result["success"] = True
            result["final_message"] = "Nenhum problema encontrado."
            self.execution_log.append(result)
            return result
        
        # STEP 3: Validação inicial
        initial_validation = self.validator.validate_syntax(path)
        result["steps"].append({"step": "initial_validation", "result": initial_validation.to_dict()})
        
        if not initial_validation.success:
            result["final_message"] = f"Arquivo com erro de sintaxe: {initial_validation.message}"
            self.execution_log.append(result)
            return result
        
        # STEP 4: Gerar contexto para correção
        fix_context = self.fixer_core.build_fix_context(path, issues[0].to_dict() if issues else None)
        result["steps"].append({"step": "build_context", "context_keys": list(fix_context.keys())})
        
        # STEP 5: Criar backup
        backup_path = self.fixer_core.create_backup(path)
        result["steps"].append({"step": "backup", "backup_path": str(backup_path)})
        
        # STEP 6: Aplicar correção (simulado por enquanto, sem LLM ainda)
        # TODO: Integrar LLM aqui para gerar patch real
        result["steps"].append({
            "step": "fix_generation",
            "status": "skipped",
            "reason": "LLM integration pending"
        })
        
        # STEP 7: Validação final
        final_validation = self.validator.validate_against_issue(path, issues[0].to_dict() if issues else {})
        result["steps"].append({"step": "final_validation", "result": final_validation.to_dict()})
        
        result["success"] = final_validation.success
        result["final_message"] = "Analise completa. Correcao automatica ainda nao implementada (aguardando LLM)."
        
        self.execution_log.append(result)
        return result
    
    def get_execution_log(self) -> list[dict[str, Any]]:
        """Retorna histórico de execuções"""
        return self.execution_log
    
    def report(self) -> str:
        """Gera relatório textual das execuções"""
        if not self.execution_log:
            return "Nenhuma execucao registrada."
        
        lines = ["=== RELATORIO DE EXECUCOES ===\n"]
        for i, log in enumerate(self.execution_log, 1):
            lines.append(f"\n[{i}] Arquivo: {log['file']}")
            lines.append(f"    Status: {'✅ Sucesso' if log['success'] else '❌ Falha'}")
            lines.append(f"    Mensagem: {log['final_message']}")
            lines.append(f"    Passos executados: {len(log['steps'])}")
        
        return "\n".join(lines)


def main():
    """Ponto de entrada CLI simples"""
    if len(sys.argv) < 2:
        print("Uso: python agent_v2.py <arquivo.py>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    workspace = Path(file_path).parent
    
    agent = AutonomousAgent(workspace_dir=workspace)
    result = agent.analyze_and_fix(file_path)
    
    print("\n=== RESULTADO ===")
    print(f"Arquivo: {result['file']}")
    print(f"Sucesso: {result['success']}")
    print(f"Mensagem: {result['final_message']}")
    print(f"\nPassos executados: {len(result['steps'])}")
    
    for step in result["steps"]:
        print(f"  - {step['step']}")
    
    print("\n" + agent.report())


if __name__ == "__main__":
    main()