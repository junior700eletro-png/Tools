import sys
from pathlib import Path
from git import Repo


def ensure_gitignore(repo_dir: Path):
    """Garante que o .gitignore existe e tem regras básicas"""
    gitignore_path = repo_dir / ".gitignore"
    
    essential_rules = [
        ".tmp.driveupload/",
        "*.pyc",
        "__pycache__/",
        ".venv/",
        "venv/",
        "env/",
        "*.log",
        ".DS_Store",
        "Thumbs.db",
        "desktop.ini",
        "*.tmp",
        "*.temp",
        ".cache/",
        "node_modules/",
    ]
    
    if gitignore_path.exists():
        existing_rules = set(gitignore_path.read_text(encoding='utf-8').splitlines())
        new_rules = [rule for rule in essential_rules if rule not in existing_rules]
        
        if new_rules:
            print(f"Adicionando {len(new_rules)} regras ao .gitignore existente...")
            with gitignore_path.open('a', encoding='utf-8') as f:
                f.write('\n# Regras adicionadas automaticamente\n')
                f.write('\n'.join(new_rules) + '\n')
    else:
        print("Criando .gitignore com regras essenciais...")
        gitignore_path.write_text(
            '# Arquivos temporarios e caches\n' +
            '\n'.join(essential_rules) + '\n',
            encoding='utf-8'
        )


def main():
    print("Script Git iniciado")
    
    # Recebe o diretório base como argumento
    if len(sys.argv) < 2:
        print("Uso: python git_dir_quick.py <diretorio_repositorio>")
        sys.exit(1)
    
    repo_dir = Path(sys.argv[1])
    print(f"Diretorio do repositorio: {repo_dir}")
    
    try:
        repo = Repo(repo_dir)
        print(f"Repositorio Git encontrado em: {repo_dir}")
    except Exception as e:
        print(f"Erro ao abrir repositorio Git em {repo_dir}: {e}")
        print("Certifique-se de que este eh um repositorio Git (.git existe).")
        sys.exit(1)
    
    # Garantir gitignore
    ensure_gitignore(repo_dir)
    
    # Verificar arquivos
    print("\nVerificando arquivos a serem adicionados...")
    
    try:
        untracked = repo.untracked_files
        modified = [item.a_path for item in repo.index.diff(None)]
        
        all_files = untracked + modified
        
        if not all_files:
            print("Nenhum arquivo novo ou modificado.")
            print("Repositorio ja esta sincronizado.")
            input("\nPressione ENTER para sair...")
            sys.exit(0)
        
        print(f"\nArquivos a serem adicionados ({len(all_files)}):")
        for f in all_files[:20]:
            print(f"  - {f}")
        if len(all_files) > 20:
            print(f"  ... e mais {len(all_files) - 20} arquivos")
        
        resposta = input("\nConfirma adicionar esses arquivos? (S/n): ").strip().lower()
        if resposta == 'n':
            print("Abortado pelo usuario.")
            sys.exit(0)
        
    except Exception as e:
        print(f"Aviso ao verificar status: {e}")
    
    # Git add .
    try:
        print("\nExecutando git add ...")
        repo.git.add('.')
        print("git add . executado com sucesso")
    except Exception as e:
        print(f"Erro ao executar git add: {e}")
        sys.exit(1)
    
    # Commit
    default_msg = "Atualizar repositorio"
    print(f"\nMensagem de commit padrao: {default_msg}")
    msg = input("Mensagem de commit (ENTER para usar padrao): ").strip() or default_msg
    
    try:
        print(f"\nCriando commit: {msg}")
        repo.index.commit(msg)
        print("Commit criado com sucesso.")
    except Exception as e:
        print(f"Erro ao criar commit: {e}")
        sys.exit(1)
    
    # Push
    try:
        branch_name = repo.active_branch.name
        print(f"\nBranch atual: {branch_name}")
    except TypeError:
        print("Repositorio em estado detached HEAD. Nao vou fazer push automatico.")
        sys.exit(0)
    
    try:
        origin = repo.remote(name="origin")
        print(f"Fazendo push para origin/{branch_name}...")
        origin.push(branch_name)
        print("\n=== Push realizado com sucesso! ===")
    except Exception as e:
        print(f"Erro ao fazer push: {e}")
        print("Verifique suas credenciais Git.")
        sys.exit(1)
    
    print("\n=== Tudo pronto: git add/commit/push executado ===")
    input("\nPressione ENTER para sair...")


if __name__ == "__main__":
    main()
