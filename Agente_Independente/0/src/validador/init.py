"""
Módulo de validação para o agente.

init.py

Este módulo exporta as principais classes de validação,
permitindo imports limpos como:

    from src.validator import CompatibilityValidator, ValidationResult

Classes:
- CompatibilityValidator: Responsável por validar compatibilidade.
- ValidationResult: Representa o resultado de uma validação.
"""

from .compatibility_validator import CompatibilityValidator
from .validation_result import ValidationResult

__all__ = [
    'CompatibilityValidator',
    'ValidationResult',
]
