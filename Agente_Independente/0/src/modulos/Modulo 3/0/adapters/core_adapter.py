# core_adapter.py path: modulo 3/0/src/adapters/core_adapter.py
from typing import Dict, Any
from .base_adapter import BaseAdapter

class CoreAdapter(BaseAdapter):
    @staticmethod
    def handle(request: Dict[str, Any]) -> Dict[str, Any]:
        data = request.get('data', {})
        op = data.get('operation', '')
        if op == 'sum':
            result = data.get('a', 0) + data.get('b', 0)
            return {"success": True, "adapter": "core", "result": result}
        return {"success": True, "adapter": "core", "result": f"Core operation: {op}"}