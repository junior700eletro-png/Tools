import sys
from pathlib import Path

import pyperclip
from git import Repo


def check_tkinter():
    try:
        import tkinter  # noqa: F401
        return True
    except ImportError:
        print(
            "ERRO: Tkinter nao esta disponivel na sua instalacao do Python.\n"
            "- No Windows, isso geralmente significa que o Python foi instalado sem o componente Tcl/Tk.\n"
            "- Solucao: reinstale o Python pelo instalador oficial (python.org)\n"
            "  certificando-se de marcar a opcao de instalar Tcl/Tk (Tkinter)."
        )
        return False


def escolher_arquivo_gui(base_dir: Path) -> Path:
    import tkinter as tk
    from tkinter import filedialog

    root = tk.Tk()
    root.withdraw()
    # Manter o dialog em primeiro plano (ajuda no Windows) [web:49]
    root.attributes("-topmost", True)

    file_path = filedialog.askopenfilename(
        title="Selecione o arquivo a substituir",
        initialdir=str(base_dir),
        filetypes=[("Todos os arquivos", "*.*")]
    )
    root.destroy()

    if not file_path:
        print("Nenhum arquivo selecionado. Abortando.")
        sys.exit(1)

    return Path(file_path)


def main():
    # 1) Diretório base do repositório (arg 1 ou diretório atual)
    base_dir = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()

    if not base_dir.is_dir():
        print(f"Diretorio invalido: {base_dir}")
        sys.exit(1)

    print(f"Diretorio base (repo): {base_dir}")

    # 2) Checar Tkinter se vamos usar GUI
    # (se o arquivo nao for passado via argv 2, usaremos a janela)
    usar_gui = len(sys.argv) <= 2
    if usar_gui and not check_tkinter():
        sys.exit(1)

    # 3) Ler conteudo do clipboard
    clip_text = pyperclip.paste()
    if not clip_text:
        print("Clipboard vazio. Copie algum texto antes de rodar o script.")
        sys.exit(1)

    print("Conteudo do clipboard lido com sucesso.")

    # 4) Definir arquivo alvo
    if len(sys.argv) > 2:
        # Caminho relativo ao base_dir vindo por argumento
        target_path = (base_dir / sys.argv[2]).resolve()
    else:
        # Usar janela do Windows para escolher arquivo
        target_path = escolher_arquivo_gui(base_dir)

    # 5) Verificar se arquivo existe; se nao, opcionalmente criar
    if not target_path.exists():
        print(f"Arquivo nao encontrado: {target_path}")
        resp = input("Arquivo nao existe. Deseja criar? [s/N]: ").strip().lower()
        if resp != "s":
            sys.exit(1)

    # 6) Backup opcional
    if target_path.exists():
        backup_path = target_path.with_suffix(target_path.suffix + ".bak")
        try:
            backup_path.write_text(target_path.read_text(encoding="utf-8"), encoding="utf-8")
            print(f"Backup criado: {backup_path}")
        except Exception as e:
            print(f"Erro ao criar backup: {e}")

    # 7) Escrever novo conteudo
    try:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(clip_text, encoding="utf-8")
        print(f"Arquivo substituido com sucesso: {target_path}")
    except Exception as e:
        print(f"Erro ao escrever arquivo: {e}")
        sys.exit(1)

    # 8) Abrir repositorio Git
    try:
        repo = Repo(base_dir)
    except Exception as e:
        print(f"Erro ao abrir repositorio Git em {base_dir}: {e}")
        sys.exit(1)

    # 9) git add apenas no arquivo alterado
    rel_path = target_path.relative_to(base_dir)
    repo.git.add(str(rel_path))
    print(f"git add {rel_path}")

    # 10) Mensagem de commit
    default_msg = f"Atualizar {rel_path} via script (clipboard)"
    print(f"\nMensagem de commit padrao: {default_msg}")
    msg = input("Mensagem de commit (ENTER para usar padrao): ").strip() or default_msg

    try:
        repo.index.commit(msg)
        print("Commit criado.")
    except Exception as e:
        print(f"Erro ao criar commit: {e}")
        sys.exit(1)

    # 11) Descobrir branch atual e fazer push
    try:
        branch_name = repo.active_branch.name
    except TypeError:
        print("Repositorio em estado detached HEAD. Nao vou fazer push automatico.")
        sys.exit(0)

    try:
        origin = repo.remote(name="origin")
        print(f"Fazendo push para origin/{branch_name}...")
        origin.push(branch_name)
        print("Push realizado com sucesso.")
    except Exception as e:
        print(f"Erro ao fazer push: {e}")
        print("Verifique se suas credenciais do Git estao configuradas nesta maquina.")
        sys.exit(1)

    print("\nTudo pronto: arquivo atualizado, commit criado e push feito.")


if __name__ == "__main__":
    main()
