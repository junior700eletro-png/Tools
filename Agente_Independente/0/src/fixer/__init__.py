"""Módulo fixer: lógica de correção de código Python."""

from .core import PythonFixer
from .agent import FixerAgent

# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\__init__.py
# Name: __init__.py - Centralizador de exports

from core_v3_final import (
    CacheManager,
    MetricsLogger,
    fallback_correct,
    FixerCoreV3Final,
    # ... adicione todas as classes/funções que core_v3_final exporta
)

__all__ = [
    'CacheManager',
    'MetricsLogger',
    'fallback_correct',
    'FixerCoreV3Final',
]