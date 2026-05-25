# restore_direto.py — Restaura arquivos direto do bootstrap original
import json, os, sys
from tkinter import Tk, filedialog, messagebox

Tk().withdraw()

pasta = os.environ.get('LOCALAPPDATA', '') + '\estruturas_JSON'

arquivo = filedialog.askopenfilename(
    title='Selecione o bootstrap original (.txt ou .json)',
    initialdir=pasta,
    filetypes=[('Bootstrap', '*.json *.txt')]
)
if not arquivo:
    sys.exit()

print('Lendo JSON original...')
with open(arquivo, 'r', encoding='utf-8-sig') as f:
    raw = f.read()

# Remove linhas de comentario # no inicio
lines = raw.splitlines()
clean = [l for l in lines if not l.strip().startswith('#')]
raw = '\n'.join(clean)

# Parse com strict=False (aceita caracteres de controle)
data = json.loads(raw, strict=False)

# Pega os arrays de arquivos e pastas
files = data.get('files', [])
if not files and 'structure' in data:
    files = data['structure'].get('files', [])
folders = data.get('folders', [])
if not folders and 'structure' in data:
    folders = data['structure'].get('folders', [])

destino = pasta
print(f'=== RESTAURANDO DIRETAMENTE ===')
print(f'Destino: {destino}')
print(f'Arquivos no JSON: {len(files)}')
print(f'Pastas no JSON: {len(folders)}')
print()

# Cria pastas
for folder in folders:
    path = os.path.join(destino, folder)
    os.makedirs(path, exist_ok=True)

# Cria arquivos
ok = 0
erro = 0
for item in files:
    rel = item.get('path', '')
    conteudo = item.get('content', '')
    rel = rel.lstrip('\/')

    full = os.path.join(destino, rel)
    parent = os.path.dirname(full)
    if parent:
        os.makedirs(parent, exist_ok=True)

    try:
        if item.get('encoding') == 'base64':
            import base64
            with open(full, 'wb') as f:
                f.write(base64.b64decode(conteudo))
        else:
            with open(full, 'w', encoding='utf-8') as f:
                f.write(conteudo)
        print(f'  [OK] {rel}')
        ok += 1
    except Exception as e:
        print(f'  [FALHA] {rel}: {e}')
        erro += 1

print()
print(f'=== RESUMO ===')
print(f'Criados: {ok}')
if erro:
    print(f'Falhas: {erro}')
print(f'Pasta: {destino}')

messagebox.showinfo(
    'Sucesso' if erro == 0 else 'Atencao',
    f'{ok} arquivos restaurados em:\n{destino}'
)

input('Enter para sair: ')