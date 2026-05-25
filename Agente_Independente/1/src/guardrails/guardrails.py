# guardrails.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any
import json


@dataclass
class GuardrailResult:
    allowed: bool
    message: str
    details: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class Guardrails:
    def __init__(self, config_path: str | Path | None = None) -> None:
        self.config_path = Path(config_path) if config_path else None
        self.config = self._load_config()

    def _load_config(self) -> dict[str, Any]:
        default = {
            "blocked_paths": [
                "C:/Windows",
                "C:/Program Files",
                "C:/Program Files (x86)",
                "C:/Users/Public",
            ],
            "blocked_extensions": [".exe", ".dll", ".bat", ".cmd", ".ps1"],
            "max_file_size_mb": 5,
            "allow_network": False,
        }

        if not self.config_path or not self.config_path.exists():
            return default

        try:
            loaded = json.loads(self.config_path.read_text(encoding="utf-8"))
            default.update(loaded)
            return default
        except Exception:
            return default

    def check_path(self, target_path: str | Path) -> GuardrailResult:
        path = Path(target_path).resolve()
        path_str = str(path).replace("\\", "/").lower()

        for blocked in self.config["blocked_paths"]:
            if blocked.replace("\\", "/").lower() in path_str:
                return GuardrailResult(False, "Caminho bloqueado por seguranca.", {"path": str(path)})

        if path.suffix.lower() in self.config["blocked_extensions"]:
            return GuardrailResult(False, "Extensao bloqueada por seguranca.", {"path": str(path)})

        if path.exists() and path.is_file():
            size_mb = path.stat().st_size / (1024 * 1024)
            if size_mb > float(self.config["max_file_size_mb"]):
                return GuardrailResult(False, "Arquivo grande demais para operacao automatica.", {"path": str(path)})

        return GuardrailResult(True, "Caminho aprovado.", {"path": str(path)})

    def validate_operation(self, operation: str, target_path: str | Path) -> GuardrailResult:
        if operation.lower() in {"delete", "remove", "format", "rm"}:
            return GuardrailResult(False, "Operacao destrutiva bloqueada.", {"operation": operation})

        return self.check_path(target_path)