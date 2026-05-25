import sys
from pathlib import Path
from git import Repo


def escolher_pasta():
    """Abre janela do Windows para escolher pasta"""
    try:
        import tkinter as tk
        from tkinter import filedialog
        
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        
        pasta = filedialog.askdirectory(title="Selecione a pasta")
        root.destroy()
        
        if not pasta:
            print("Nenhuma pasta selecionada.")
            sys.exit(1)
            
        return Path(pasta)
        
    except ImportError:
        print("ERRO: Tkinter não instalado. Reinstale o Python com Tcl/Tk.")
        sys.exit(1)


def main():
    print("=== Git Add/Commit/Push ===\n")
    
    # Janela 1: Escolher repositório
    print("Escolha o REPOSITÓRIO Git (pasta com .git)")
    repo_dir = escolher_pasta()
    
    try:
        repo = Repo(repo_dir)
        print(f"✓ Repositório: {repo_dir}\n")
    except:
        print(f"✗ ERRO: {repo_dir} não é um repositório Git")
        input("Pressione ENTER...")
        sys.exit(1)
    
    # Criar .gitignore se não existir
    gitignore = repo_dir / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text(
            ".tmp.driveupload/\n*.pyc\n__pycache__/\n.venv/\nvenv/\n"
            "*.log\n.DS_Store\nThumbs.db\ndesktop.ini\n"
        )
        print("✓ .gitignore criado\n")
    
    # Janela 2: Escolher pasta para gitar
    print("Escolha a PASTA para adicionar/commitar/pushar")
    pasta_alvo = escolher_pasta()
    
    try:
        rel_path = pasta_alvo.relative_to(repo_dir)
    except ValueError:
        print(f"✗ ERRO: {pasta_alvo} não está dentro do repositório")
        input("Pressione ENTER...")
        sys.exit(1)
    
    print(f"✓ Pasta: {rel_path}\n")
    
    # Mostrar arquivos
    print("Arquivos a adicionar:")
    try:
        repo.git.add(str(rel_path))
        status = repo.git.status("--short")
        print(status if status else "  (nenhum arquivo novo)")
    except Exception as e:
        print(f"✗ Erro: {e}")
        input("Pressione ENTER...")
        sys.exit(1)
    
    # Confirmar
    conf = input("\nContinuar? (S/n): ").strip().lower()
    if conf == 'n':
        print("Cancelado")
        sys.exit(0)
    
    # Commit
    msg = input("Mensagem de commit: ").strip() or f"Atualizar {rel_path}"
    
    try:
        repo.index.commit(msg)
        print(f"✓ Commit: {msg}")
    except Exception as e:
        print(f"✗ Erro no commit: {e}")
        input("Pressione ENTER...")
        sys.exit(1)
    
    # Push
    try:
        branch = repo.active_branch.name
        origin = repo.remote("origin")
        print(f"\nFazendo push para origin/{branch}...")
        origin.push(branch)
        print("\n✓✓✓ SUCESSO ✓✓✓")
    except Exception as e:
        print(f"✗ Erro no push: {e}")
    
    input("\nPressione ENTER para sair...")


if __name__ == "__main__":
    main()
