# Em modulo2/0/expert_core.py
import sys
from pathlib import Path

# Resolve o caminho do __init__.py centralizador
fixer_path = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(fixer_path))

# Importa tudo do centralizador
from fixer import CacheManager, MetricsLogger, fallback_correct
