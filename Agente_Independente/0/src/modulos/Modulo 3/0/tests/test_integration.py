# test_integration.py path: modulo 3/0/tests/test_integration.py
import sys
import os
import json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from dispatcher.request_dispatcher import RequestDispatcher
from router.routing_engine import RoutingEngine
from orchestrator.orchestrator_core import OrchestratorCore
from handlers.handler_registry import HandlerRegistry
from adapters.cli_adapter import CLIAdapter
from adapters.rpa_adapter import RPAAdapter
from adapters.core_adapter import CoreAdapter
from adapters.expert_adapter import ExpertAdapter
from adapters.skill_adapter import SkillAdapter
fr