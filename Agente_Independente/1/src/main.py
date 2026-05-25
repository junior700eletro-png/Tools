
import argparse
import json
import os
from datetime import datetime
from analyzer import ProjectAnalyzer


def main():
    """
    Função principal do CLI para testar o agente-python-fixer.
    Recebe o caminho do projeto via argumento ou input do usuário,
    executa a análise, salva o relatório JSON e exibe resumo.
    """
    parser = argparse.ArgumentParser(
        description="Analisador de Projetos Python para agente-python-fixer"
    )
    parser.add_argument(
        "path",
        nargs='?',
        help="Caminho do projeto Python (ex: C:\\path\\to\\projeto)"
    )
    args = parser.parse_args()

    project_path = args.path
    if project_path is None:
        project_path = input("Digite o caminho do projeto: ").strip()

    if not project_path:
        print("Erro: Caminho do projeto é obrigatório.")
        return

    if not os.path.exists(project_path):
        print(f"Erro: Caminho '{project_path}' não existe.")
        return

    try:
        print(f"Analisando projeto em: {project_path}")
        analyzer = ProjectAnalyzer(project_path)
        result = analyzer.analyze()

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"report_{timestamp}.json"

        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

        print(f"Relatório salvo em: {report_file}")

        print("\n" + "="*50)
        print("RESUMO DA ANÁLISE")
        print("="*50)
        print(f"Testes passados: {result.get('tests_passed', 0)}")
        print(f"Testes falhados: {result.get('tests_failed', 0)}")
        print(f"Problemas de lint: {result.get('lint_problems', 0)}")
        print("="*50)

    except Exception as e:
        print(f"Erro durante a análise: {str(e)}")
        print("Verifique se o projeto é válido e contém arquivos Python.")


if __name__ == "__main__":
    main()
