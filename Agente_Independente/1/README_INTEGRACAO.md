text
# README_INTEGRACAO.md

# Integração dos Módulos - Agente V2

## Estrutura de Integração
src/
├── agent_v2.py # Orquestrador principal
├── analyser/
│ ├── _init_.py
│ └── analyzer.py
├── fixer/
│ ├── _init_.py
│ ├── core_v2.py
│ └── core_v3_final.py
├── patches/
│ ├── _init_.py
│ └── executor.py
├── validador/
│ ├── _init_.py
│ └── validators.py
└── guardrails/
├── _init_.py
└── guardrails.py

main.py # Ponto de entrada
test_broken.py # Arquivo de teste

text

## Como Usar

### 1. Testar análise básica:
```bash
cd Agente_Independente/1
python main.py test_broken.py
```

### 2. Testar com arquivo próprio:
```bash
python main.py caminho/para/seu_arquivo.py
```

### 3. Usar agent_v2.py diretamente:
```bash
cd src
python agent_v2.py ../test_broken.py
```

## Fluxo de Execução

1. **Guardrails** → Valida segurança do caminho
2. **Analyzer** → Detecta erros (sintaxe, imports, variáveis)
3. **Validator** → Valida sintaxe inicial
4. **FixerCore** → Gera contexto para correção
5. **Backup** → Cria backup antes de modificar
6. **[TODO] LLM** → Gera correção inteligente
7. **Executor** → Aplica patch
8. **Validator** → Valida correção aplicada

## Próximos Passos

- [ ] Integrar LLM (OpenAI/LangChain) no step 6
- [ ] Implementar aplicação real de patches
- [ ] Adicionar retry inteligente
- [ ] Criar memória SQLite para aprendizado
- [ ] Sandbox de execução segura
