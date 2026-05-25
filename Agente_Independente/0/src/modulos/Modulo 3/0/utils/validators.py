# validators.py path: modulo 3/0/src/utils/validators.py
from typing import Dict, Any

def validate_request(request: Dict[str, Any]) -> bool:
    required = ["id", "type", "data"]
    return all(k in request for k in required)