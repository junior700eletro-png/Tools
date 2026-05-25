# cli_adapter.py path: modulo 3/0/src/adapters/cli_adapter.py
from typing import Dict, Any
from .base_adapter import BaseAdapter

class CLIAdapter(BaseAdapter):
    @staticmethod
    def handle(request: Dict[str, Any]) -> Dict[str, Any]:
        data = request.get('data', {})
        return {
            "success": True,
            "adapter": "cli",
            "result": f"CLI command executed: {data.get('command', 'unknown')}"
        }