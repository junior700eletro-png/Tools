# -*- coding: utf-8 -*-
import pytest
from src.fixer.core import PythonFixer, FixRequest


def test_fix_code():
    """Testa correção de código."""
    fixer = PythonFixer({})
    request = FixRequest(code="print(1/0)", issue="ZeroDivisionError")
    result = fixer.fix_code(request)
    assert "Zero" in result