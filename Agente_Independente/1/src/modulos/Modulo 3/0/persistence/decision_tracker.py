# decision_tracker.py path: modulo 3/0/src/persistence/decision_tracker.py
import json
import os
from typing import Dict, Any

class DecisionTracker:
    def __init__(self, log_dir: str = "logs"):
        os.makedirs(log_dir, exist_ok=True)
        self.log_file = os.path.join(log_dir, "decisions.jsonl")

    def log_decision(self, request: Dict[str, Any], handler_type: str) -> None:
        with open(self.log_file, 'a') as f:
            f.write(json.dumps({
                "request_id": request.get("id"),
                "handler": handler_type,
                "type": "decision"
            }) + "\n")