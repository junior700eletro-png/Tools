# audit_logger.py path: modulo 3/0/src/persistence/audit_logger.py
import json
import os
from typing import Dict, Any

class AuditLogger:
    def __init__(self, log_dir: str = "logs"):
        os.makedirs(log_dir, exist_ok=True)
        self.log_file = os.path.join(log_dir, "audit.jsonl")

    def log_request(self, request: Dict[str, Any]) -> None:
        with open(self.log_file, 'a') as f:
            f.write(json.dumps({"type": "request", "data": request}) + "\n")

    def log_response(self, response: Dict[str, Any]) -> None:
        with open(self.log_file, 'a') as f:
            f.write(json.dumps({"type": "response", "data": response}) + "\n")