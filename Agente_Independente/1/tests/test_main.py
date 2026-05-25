# -*- coding: utf-8 -*-
import pytest
from src.main import main


def test_main(capsys):
    """Testa função main."""
    main()
    captured = capsys.readouterr()
    assert "Agente" in captured.out