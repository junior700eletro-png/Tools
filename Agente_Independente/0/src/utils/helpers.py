# -*- coding: utf-8 -*-
"""
Funções auxiliares para o projeto.
"""

from pathlib import Path
from pydantic_settings import BaseSettings
from typing import Dict

class Settings(BaseSettings):
    debug: bool = False
    openai_api_key: str

    class Config:
        env_file = ".env"

def load_config() -> Dict:
    """Carrega configurações do .env."""
    settings = Settings()
    return settings.model_dump()

def read_file(file_path: Path) -> str:
    """Lê conteúdo de arquivo."""
    return file_path.read_text(encoding="utf-8")