# routing_engine.py path: modulo 3/0/src/router/routing_engine.py
import json
from typing import Dict, Any

class RoutingEngine:
    def __init__(self, config_path: str = "config/orchestrator_config.json"):
        try:
            with open(config_path, 'r') as f:
                self.config = json.load(f)
        except:
            self.config = {"routes": {}}

    def route(self, request: Dict[str, Any]) -> str:
        req_type = request.get('type', '')
        return self.config.get('routes', {}).get(req_type, 'fallback')