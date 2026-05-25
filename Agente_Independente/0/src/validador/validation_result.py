# Arquivo: validation_result.py
# Caminho: Agente_Independente / src / validator / validation_result.py
# Propósito: Definir dataclass com resultado de validação em 3 níveis

from dataclasses import dataclass, asdict
from typing import List


@dataclass
class ValidationResult:
    status: str
    level_passed: int
    language: str
    errors: List[str]
    warnings: List[str]
    execution_output: str
    execution_time_ms: float
    timestamp: str
    attempt_count: int

    def is_success(self) -> bool:
        return self.status.lower() == 'success'

    def has_errors(self) -> bool:
        return bool(self.errors)

    def to_dict(self) -> dict:
        return asdict(self)

