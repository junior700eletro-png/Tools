# fallback_strategy.py path: modulo 3/0/src/router/fallback_strategy.py
import json
from typing import Dict, Any, Optional

class FallbackStrategy:
    def __init__(self, rules_path: str = "config/fallback_rules.json"):
        try:
            with open(rules_path, 'r') as f:
                self.rules = json.load(f)
        except:
            self.rules = {"rules": []}

    def get_fallback(self, request: Dict[str, Any], error: str) -> Optional[str]:
        for rule in self.rules.get('rules', []):
            if 'match_error' in rule and rule['match_error'] in error:
                return rule['fallback_to']
            if 'match_type' in rule and rule['match_type'] == request.get('type'):
                return rule['fallback_to']
        return None