# -*- coding: utf-8 -*-
"""
Agente de IA para correção usando OpenAI/Langchain.
"""

from langchain_openai import ChatOpenAI

class FixerAgent:
    """
    Inicializa o agente de IA.

    Args:
        api_key: Chave da OpenAI.
    """
    def __init__(self, api_key: str):
        self.llm = ChatOpenAI(openai_api_key=api_key, model="gpt-4o-mini")

    def suggest_fix(self, code: str, error: str) -> str:
        """Sugere correção."""
        # Prompt stub para Sprint 1
        prompt = f"Corrija este código Python com erro '{error}': {code}"
        # response = self.llm.invoke(prompt)
        return "Sugestão de fix: adicione try-except."  # Stub