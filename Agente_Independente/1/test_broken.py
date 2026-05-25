# test_broken.py
"""
Arquivo de teste com erros intencionais para validar o agente.
"""

# Erro 1: Import quebrado
import modulo_inexistente

# Erro 2: Variável indefinida
def calcular():
    resultado = x + y  # x e y não foram definidos
    return resultado

# Erro 3: Sintaxe incorreta (comentado para não quebrar o parser inicial)
# def funcao_quebrada(
#     print("falta fechar parênteses"

# Função válida para teste
def funcao_valida():
    a = 10
    b = 20
    return a + b

if __name__ == "__main__":
    print("Testando agente...")
    calcular()