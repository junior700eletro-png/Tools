# execution_context.py path: modulo 3/0/src/orchestrator/execution_context.py
from typing import Dict, Any, Optional

class ExecutionContext:
    def __init__(self):
        self.variables: Dict[str, Any] = {}

    def get(self, key: str) -> Optional[Any]:
        return self.variables.get(key)

    def set(self, key: str, value: Any) -> None:
        self.variables[key] = value