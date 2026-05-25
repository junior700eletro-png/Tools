# __init__.py path: modulo 3/0/src/dispatcher/__init__.py
from typing import Dict, Any, Callable, Optional
from .request_dispatcher import RequestDispatcher
from .handler_registry import HandlerRegistry

Request = Dict[str, Any]
Response = Dict[str, Any]
Handler = Callable[[Request], Response]