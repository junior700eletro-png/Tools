# rpa_adapter.py path: modulo 3/0/src/adapters/rpa_adapter.py
from typing import Dict, Any
from .base_adapter import BaseAdapter

class RPAAdapter(BaseAdapter):
    @staticmethod
    def handle(request: Dict[str, Any]) -> Dict[str, Any]:
        data = request.get('data', {})
        return {
            "success": True,
            "adapter": "rpa",
            "result": f"RPA task executed: {data.get('task', 'unknown')}"
        }