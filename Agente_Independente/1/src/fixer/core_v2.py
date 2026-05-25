# core_v2.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Optional
import json
import time


@dataclass
class FixResult:
    success: bool
    message: str
    file_path: str = ""
    backup_path: str = ""
    patch_text: str = ""
    metadata: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class FixerCoreV2:
    def __init__(self, workspace_dir: str | Path, cache_dir: str | Path | None = None) -> None:
        self.workspace_dir = Path(workspace_dir)
        self.cache_dir = Path(cache_dir) if cache_dir else self.workspace_dir / ".cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def build_fix_context(self, file_path: str | Path, issue: dict[str, Any] | None = None) -> dict[str, Any]:
        path = Path(file_path)
        content = path.read_text(encoding="utf-8")
        return {
            "file_path": str(path),
            "content": content,
            "issue": issue or {},
            "timestamp": time.time(),
        }

    def load_cache(self, key: str) -> dict[str, Any] | None:
        cache_file = self.cache_dir / f"{key}.json"
        if not cache_file.exists():
            return None
        try:
            return json.loads(cache_file.read_text(encoding="utf-8"))
        except Exception:
            return None

    def save_cache(self, key: str, data: dict[str, Any]) -> None:
        cache_file = self.cache_dir / f"{key}.json"
        cache_file.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")

    def validate_python_syntax(self, source: str, filename: str = "<string>") -> tuple[bool, str]:
        try:
            compile(source, filename, "exec")
            return True, "ok"
        except SyntaxError as exc:
            return False, f"{exc.msg} at line {exc.lineno}"

    def create_backup(self, file_path: str | Path) -> Path:
        path = Path(file_path)
        backup_path = path.with_suffix(path.suffix + ".bak")
        backup_path.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
        return backup_path

    def rollback(self, file_path: str | Path, backup_path: str | Path) -> None:
        path = Path(file_path)
        backup = Path(backup_path)
        path.write_text(backup.read_text(encoding="utf-8"), encoding="utf-8")