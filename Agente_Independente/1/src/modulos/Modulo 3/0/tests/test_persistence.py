# test_persistence.py path: modulo 3/0/tests/test_persistence.py
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from persistence.audit_logger import AuditLogger
from persistence.decision_tracker import DecisionTracker

def test_audit_logger():
    logger = AuditLogger(log_dir="/tmp/test_logs")
    logger.log_request({"id": "1", "type": "test", "data": {"key": "value"}})
    logger.log_response({"success": True, "data": {"result": "ok"}})
    assert os.path.exists(logger.log_file)

def test_decision_tracker():
    tracker = DecisionTracker(log_dir="/tmp/test_logs")
    tracker.log_decision({"id": "1"}, "core_adapter")
    assert os.path.exists(tracker.log_file)