# normalizers.py path: modulo 3/0/src/utils/normalizers.py
from typing import Dict, Any

def normalize_request(request: Dict[str, Any]) -> Dict[str, Any]:
    if 'context' not in request:
        request['context'] = {}
    if 'data' in request and isinstance(request['data'], dict):
        request['data'] = {k.lower(): v for k, v in request['data'].items()}
    return request