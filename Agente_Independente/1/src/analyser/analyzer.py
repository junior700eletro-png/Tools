# analyzer.py
from __future__ import annotations

import ast
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Optional


@dataclass
class Issue:
    file: str
    line: int
    column: int
    severity: str
    code: str
    message: str
    context: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class Analyzer:
    def __init__(self) -> None:
        self.issues: list[Issue] = []

    def analyze_file(self, file_path: str | Path) -> list[Issue]:
        path = Path(file_path)
        self.issues = []

        if not path.exists():
            self.issues.append(
                Issue(
                    file=str(path),
                    line=0,
                    column=0,
                    severity="error",
                    code="FILE_NOT_FOUND",
                    message="Arquivo 