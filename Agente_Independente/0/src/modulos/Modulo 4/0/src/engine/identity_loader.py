import json

def carregar_identidade(caminho_manifesto):
    with open(caminho_manifesto, 'r', encoding='utf-8') as f:
        return json.load(f)