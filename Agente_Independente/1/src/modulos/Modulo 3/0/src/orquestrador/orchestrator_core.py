# orchestrator_core.py path: modulo 3/0/src/orchestrator/orchestrator_core.py
from typing import Dict, Any
from ..dispatcher.request_dispatcher import RequestDispatcher
from ..dispatcher.handler_registry import HandlerRegistry
from ..router.routing_engine import RoutingEngine
from ..router.fallback_strategy import FallbackStrategy
from ..orchestrator.execution_context import ExecutionContext
from ..persistence.audit_logger import AuditLogger
from ..persistence.decision_tracker import DecisionTracker
from ..adapters.cli_adapter import CLIAdapter
from ..adapters.rpa_adapter import RPAAdapter
from ..adapters.core_adapter import CoreAdapter
from ..adapters.expert_adapter import ExpertAdapter
from ..adapters.skill_adapter import SkillAdapter
from ..utils.validators import validate_request
from ..utils.normalizers import normalize_request

class OrchestratorCore:
    def __init__(self, config_path="config/orchestrator_config.json", fallback_path="config/fallback_rules.json"):
        self.registry = HandlerRegistry()
        self.dispatcher = RequestDispatcher(self.registry)
        self.router = RoutingEngine(config_path)
        self.fallback = FallbackStrategy(fallback_path)
        self.context = ExecutionContext()
        self.logger = AuditLogger()
        self.tracker = DecisionTracker()
        self._register_adapters()

    def _register_adapters(self):
        self.registry.register("cli_adapter", CLIAdapter.handle)
        self.registry.register("rpa_adapter", RPAAdapter.handle)
        self.registry.register("core_adapter", CoreAdapter.handle)
        self.registry.register("expert_adapter", ExpertAdapter.handle)
        self.registry.register("skill_adapter", SkillAdapter.handle)

    def execute(self, request):
        self.tracker.log_decision(request, "start")
        request = normalize_request(request)
        if not validate_request(request):
            return {"success": False, "error": "Invalid request"}
        self.logger.log_request(request)
        handler_type = self.router.route(request)
        handler = self.registry.get_handler(handler_type)
        if not handler:
            handler_type = self.fallback.get_fallback(request, "No handler")
            handler = self.registry.get_handler(handler_type) if handler_type else None
        if handler:
            self.tracker.log_decision(request, handler_type)
            response = handler(request)
            self.logger.log_response(response)
            return response
        return {"success": False, "error": "Routing failed"}