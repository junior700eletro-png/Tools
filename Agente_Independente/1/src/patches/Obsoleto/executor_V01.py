# Arquivo: executor.py
# Caminho: Agente_Independente / src / patches / executor.py
# Propósito: Orquestrar execução de patches via Fix_File_v2.ps1

import os
import shutil
import json
import subprocess
import pyperclip
from datetime import datetime


class PatchExecutor:
    def validate_patch_structure(self, patch):
        required_keys = ["target_file", "new_content"]
        if not isinstance(patch, dict):
            raise ValueError("Patch must be a dictionary")
        if not all(key in patch for key in required_keys):
            raise ValueError(f"Patch missing required keys: {required_keys}")
        target_file = patch["target_file"]
        if not isinstance(target_file, str) or not os.path.isfile(target_file):
            raise ValueError("target_file must be a valid existing file path")
        if not isinstance(patch["new_content"], str):
            raise ValueError("new_content must be a string")

    def _copy_to_clipboard(self, content):
        pyperclip.copy(content)

    def create_backup(self, file_path, backup_dir):
        os.makedirs(backup_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_name = os.path.basename(file_path)
        backup_name = f"{os.path.splitext(base_name)[0]}.backup_{timestamp}{os.path.splitext(base_name)[1]}"
        backup_path = os.path.join(backup_dir, backup_name)
        shutil.copy2(file_path, backup_path)

    def apply_patch(self, patch, backup_dir):
        self.validate_patch_structure(patch)
        target_file = patch["target_file"]
        self.create_backup(target_file, backup_dir)
        patch_json = json.dumps(patch)
        self._copy_to_clipboard(patch_json)
        ps1_path = "Fix_File_v2.ps1"
        subprocess.run(
            ["powershell.exe", "-ExecutionPolicy", "Bypass", "-File", ps1_path],
            check=True,
            capture_output=True
        )

