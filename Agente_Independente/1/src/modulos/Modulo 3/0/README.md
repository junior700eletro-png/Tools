# README.md path: modulo 3/0/README.md
# Módulo 3 - Orquestrador Autônomo

Orquestrador inteligente com dispatcher, router, adapters, persistence JSON, utils e tests.

## Instalação

pip install -e .

## Uso
```python
from src.orchestrator.orchestrator_core import OrchestratorCore

orch = OrchestratorCore()
req = {"id": "test", "type": "core", "data": {"operation": "sum", "a": 5, "b": 3}}
resp = orch.execute(req)
print(resp)