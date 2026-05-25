#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Módulo principal do Agente Python Fixer.

Executa o agente de correção de código.
"""

from fixer.core import PythonFixer
from utils.helpers import load_config


def main() -> None:
    """Função principal."""
    config = load_config()
    fixer = PythonFixer(config)
    print("Agente Python Fixer iniciado!")

if __name__ == "__main__":
    main()