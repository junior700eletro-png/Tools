# Arquivo: models.py
# Caminho: Agente_Independente / src / patches / models.py
# Propósito: Definir estruturas de dados (dataclasses) para patches

from dataclasses import dataclass, asdict
from typing import List


@dataclass
class PatchBlock:
    block_id: str
    content: str
    start_line: int
    end_line: int
    language: str = "python"

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Patch:
    patch_id: str
    blocks: List[PatchBlock]
    description: str = ""

    def to_dict(self) -> dict:
        return {
            "patch_id": self.patch_id,
            "blocks": [block.to_dict() for block in self.blocks],
            "description": self.description
        }

