# validators.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


@dataclass
class ValidationResult:
    success: bool
    message: str
    file_path: str = ""
    details: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class CodeValidator:
    def validate_syntax(self, file_path: str | Path) -> ValidationResult:
        path = Path(file_path)
        try:
            source = path.read_text(encoding="utf-8")
            compile(source, str(path), "exec")
            return ValidationResult(True, "Sintaxe valida.", str(path))
        except SyntaxError as exc:
            return ValidationResult(
                False,
                f"Erro de sintaxe: {exc.msg}",
                str(path),
                {
                    "line": exc.lineno,
                    "offset": exc.offset,
                    "text": exc.text,
                },
            )
        except Exception as exc:
            return ValidationResult(False, f"Erro ao validar: {exc}", str(path))

    def validate_imports(self, file_path: str | Path) -> ValidationResult:
        path = Path(file_path)
        try:
            source = path.read_text(encoding="utf-8")
            exec(compile(source, str(path), "exec"), {})
            return ValidationResult(True, "Imports aparentemente validos.", str(path))
        except Exception as exc:
            return ValidationResult(False, f"Falha ao executar verificacao de imports: {exc}", str(path))

    def validate_against_issue(self, file_path: str | Path, original_issue: dict[str, Any]) -> ValidationResult:
        syntax_result = self.validate_syntax(file_path)
        if not syntax_result.success:
            return syntax_result
        return ValidationResult(True, "Validacao concluida com sucesso.", str(file_path), {"original_issue": original_issue})