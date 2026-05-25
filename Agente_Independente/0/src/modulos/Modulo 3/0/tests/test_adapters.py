# test_adapters.py path: modulo 3/0/tests/test_adapters.py
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from adapters.cli_adapter import CLIAdapter
from adapters.rpa_adapter import RPAAdapter
from adapters.core_adapter import CoreAdapter
from adapters.expert_adapter import ExpertAdapter
from adapters.skill_adapter import SkillAdapter

def test_cli_adapter():
    result = CLIAdapter.handle({"data": {"command": "ls"}})
    assert result["success"]
    assert result["adapter"] == "cli"
    assert "ls" in result["result"]

def test_rpa_adapter():
    result = RPAAdapter.handle({"data": {"task": "extract"}})
    assert res