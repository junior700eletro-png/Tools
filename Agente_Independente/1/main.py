# main.py
"""
Ponto de entrada principal do Agente Autônomo de Depuração.
"""

import sys
from pathlib import Path

# Adicionar src ao path para imports funcionarem
sys.path.insert(0, str(Path(__file__).parent / "src"))

from agent_v2 import AutonomousAgent


def main():
    print("=== AGENTE AUTONOMO DE DEPURACAO V2 ===\n")
    
    if len(sys.argv) < 2:
        print("Uso: python main.py <arquivo.py>")
        print("\nExemplo:")
        print("  python main.py test_broken.py")
        sys.exit(1)
    
    file_path = Path(sys.argv[1])
    
    if not file_path.exists():
        print(f"ERRO: Arquivo nao encontrado: {file_path}")
        sys.exit(1)
    
    workspace = file_path.parent
    
    # Criar agente
    agent = AutonomousAgent(workspace_dir=workspace)
    
    print(f"Analisando arquivo: {file_path}")
    print(f"Workspace: {workspace}\n")
    
    # Executar análise e tentativa de correção
    result = agent.analyze_and_fix(file_path)
    
    # Exibir resultado
    print("\n" + "="*50)
    print("RESULTADO DA ANALISE")
    print("="*50)
    print(f"Arquivo: {result['file']}")
    print(f"Status: {'✅ Sucesso' if result['success'] else '❌ Necessita atencao'}")
    print(f"Mensagem: {result['final_message']}")
    print(f"\nPassos executados: {len(result['steps'])}")
    
    for i, step in enumerate(result["steps"], 1):
        print(f"  {i}. {step['step']}")
    
    # Exibir relatório completo
    print("\n" + agent.report())
    
    # Retornar código de saída
    sys.exit(0 if result['success'] else 1)


if __name__ == "__main__":
    main()