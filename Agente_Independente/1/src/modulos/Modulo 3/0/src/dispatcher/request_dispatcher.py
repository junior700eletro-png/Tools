# request_dispatcher.py path: modulo 3/0/src/dispatcher/request_dispatcher.py
from typing import Dict, Any, Callable, Optional
from .handler_registry import HandlerRegistry

Request = Dict[str, Any]
Response = Dict[str, Any]
Handler = Callable[[Request], Response]

class RequestDispatcher:
    def __init__(self, registry: HandlerRegistry):
        self.registry = registry

    def dispatch(self, request: Request) -> Response:
        handler: Optional[Handler] = self.registry.get_handler(request["type"])
        if handler:
            return handler(request)
        return {"success": False, "error": f"No handler for type {request['type']}"}