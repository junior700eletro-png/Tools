# executor.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any
import difflib


@dataclass
class ExecutionResult:
    success: bool
    message: str
    file_path: str = ""
    backup_path: str = ""
    diff_text: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class PatchExecutor:
    def __init__(self, backup_suffix: str = ".bak") -> None:
        self.backup_suffix = backup_suffix

    def apply_text_replacement(self, file_path: str | Path, old_text: str, new_text: str) -> ExecutionResult:
        path = Path(file_path)

        if not path.exists():
            return ExecutionResult(False, "Arquivo nao encontrado.", str(path))

        original = path.read_text(encoding="utf-8")
        if old_text not in original:
            return ExecutionResult(False, "Trecho original nao encontrado no arquivo.", str(path))

        backup_path = path.with_suffix(path.suffix + self.backup_suffix)
        backup_path.write_text(original, encoding="utf-8")

        updated = original.replace(old_text, new_text, 1)
        path.write_text(updated, encoding="utf-8")

        diff = "\n".join(
            difflib.unified_diff(
                original.splitlines(),
                updated.splitlines(),
                fromfile=str(path),
                tofile=str(path),
                lineterm="",
            )
        )

        return ExecutionResult(
            success=True,
            message="Patch aplicado com sucesso.",
            file_path=str(path),
            backup_path=str(backup_path),
            diff_text=diff,
        )

    def restore_backup(self, file_path: str | Path, backup_path: str | Path) -> ExecutionResult:
        path = Path(file_path)
        backup = Path(backup_path)

        if not backup.exists():
            return ExecutionResult(False, "Backup nao encontrado.", str(path), str(backup))

        path.write_text(backup.read_text(encoding="utf-8"), encoding="utf-8")
        return ExecutionResult(True, "Backup restaurado com sucesso.", str(path), str(backup))