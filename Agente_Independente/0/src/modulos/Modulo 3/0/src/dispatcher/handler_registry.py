# handler_registry.py path: modulo 3/0/src/dispatcher/handler_registry.py
from typing import Dict, Any, Callable, Optional

Request = Dict[str, Any]
Response = Dict[str, Any]
Handler = Callable[[Request], Response]

class HandlerRegistry:
    def __init__(self):
        self._handlers: Dict[str, Handler] = {}

    def register(self, type_: str, handler: Handler) -> None:
        self._handlers[type_] = handler

    def get_handler(self, type_: str) -> Optional[Handler]:
        return self._handlers.get(type_)