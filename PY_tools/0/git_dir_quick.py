import sys
from pathlib import Path

from git import Repo


def check_tkinter():
    try:
        import tkinter  # noqa: F401
        return True
    except ImportError:
        print(
            "AVISO: Tkinter nao esta disponivel.\n"
            "A selecao de diretorio por janela nao estara disponivel.\n"
            "Reinstale o Python com Tcl/Tk se quiser GUI."
        )
        return False


def escolher_diretorio_gui(titulo: str, initial: Path | None = None) -> Path:
    import tkinter as tk
    from tkinter import filedialog

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)

    dir_path = filedialog.askdirectory(
        title=titulo,
        initialdir=str(initial) if initial else None,
    )
    root.destroy()

    if not dir_path:
        print("Nenhum diretorio selecionado. Abortando.")
        sys.exit(1)

    return Path(dir_path)


def main():
    # 0) Verificar Tkinter
    if not check_tkinter():
        sys.exit(1)

    # 1) Escolher o repositorio Git (pasta raiz do clone)
    print("Selecione o DIRETORIO do repositorio Git (onde existe a pasta .git).")
    repo_dir = escolher_diretorio_gui("Selecione o repositorio Git")

    try:
        repo = Repo(repo_dir)
    except Exception as e:
        print(f"Erro ao abrir repositorio Git em {repo_dir}: {e}")
        print("Certifique-se de escolher a pasta raiz de um clone (que contenha .git).")
        sys.exit(1)

    print(f"Repositorio selecionado: {repo_dir}")

    # 2) Escolher a subpasta dentro desse repositorio a ser 'gitada'
    print("\nAgora selecione o DIRETORIO interno a ser git add/commit/push (ex.: tools).")
    target_dir = escolher_diretorio_gui(
        "Selecione o diretorio a ser git add/commit/push",
        initial=repo_dir
    )

    # Garantir que target_dir está dentro do repo_dir
    try:
        rel_dir = target_dir.relative_to(repo_dir)
    except ValueError:
        print(f"O diretorio alvo {target_dir} nao esta dentro de {repo_dir}.")
        sys.exit(1)

    print(f"Diretorio alvo: {rel_dir}")

    if not target_dir.exists() or not target_dir.is_dir():
        print(f"Diretorio alvo invalido: {target_dir}")
        sys.exit(1)

    # 3) git add desse diretorio
    try:
        repo.git.add(str(rel_dir))
        print(f"git add {rel_dir}")
    except Exception as e:
        print(f"Erro ao executar git add: {e}")
        sys.exit(1)

    # 4) Mensagem de commit
    default_msg = f"Atualizar conteudo em {rel_dir}"
    print(f"\nMensagem de commit padrao: {default_msg}")
    msg = input("Mensagem de commit (ENTER para usar padrao): ").strip() or default_msg

    try:
        repo.index.commit(msg)
        print("Commit criado.")
    except Exception as e:
        print(f"Erro ao criar commit: {e}")
        sys.exit(1)

    # 5) Descobrir branch atual e fazer push
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

    print("\nTudo pronto: git add/commit/push executado para o diretorio selecionado.")


if __name__ == "__main__":
    main()
