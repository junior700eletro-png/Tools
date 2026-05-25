# base_adapter.py path: modulo 3/0/src/adapters/base_adapter.py
from typing import Dict, Any

class BaseAdapter:
    @staticmethod
    def validate(request: Dict[str, Any]) -> bool:
        return bool(request.get('data'))

    @staticmethod
    def handle(request: Dict[str, Any]) -> Dict[str, Any]:
        raise NotImplementedError("Subclasses must implement handle")