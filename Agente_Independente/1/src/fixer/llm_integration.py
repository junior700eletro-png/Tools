# llm_integration.py
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any, Optional
import os
import json
import requests


@dataclass
class LLMResponse:
    success: bool
    patch: str
    explanation: str
    confidence: float
    metadata: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class LLMFixer:
    """
    Interface para LLM (Perplexity API) gerar correções de código.
    """
    
    def __init__(self, api_key: str | None = None, model: str = "llama-3.1-sonar-large-128k-online"):
        self.api_key = api_key or os.getenv("PERPLEXITY_API_KEY")
        self.model = model
        self.api_url = "https://api.perplexity.ai/chat/completions"
        self.mock_mode = not self.api_key  # Modo simulado se não tiver API key
    
    def generate_fix(
        self,
        file_content: str,
        issue: dict[str, Any],
        context: dict[str, Any] | None = None
    ) -> LLMResponse:
        """
        Gera uma correção para o código baseado no issue detectado.
        
        Args:
            file_content: Código fonte original
            issue: Dicionário com detalhes do erro (linha, mensagem, etc)
            context: Contexto adicional (histórico, tentativas anteriores)
        
        Returns:
            LLMResponse com patch sugerido
        """
        
        if self.mock_mode:
            return self._mock_fix(file_content, issue)
        
        return self._perplexity_fix(file_content, issue, context)
    
    def _mock_fix(self, file_content: str, issue: dict[str, Any]) -> LLMResponse:
        """
        Simulação de correção (usado quando não há API key configurada).
        """
        
        # Detectar tipo de erro e gerar patch simples
        code = issue.get("code", "")
        message = issue.get("message", "")
        
        if code == "IMPORT_ERROR":
            # Remover import quebrado
            module = message.replace("Modulo nao encontrado: ", "")
            old_line = f"import {module}"
            new_line = f"# import {module}  # FIXME: Modulo nao encontrado"
            
            if old_line in file_content:
                patched = file_content.replace(old_line, new_line, 1)
                return LLMResponse(
                    success=True,
                    patch=patched,
                    explanation=f"Comentei o import quebrado: {module}",
                    confidence=0.8,
                    metadata={"fix_type": "comment_import", "mode": "mock"}
                )
        
        elif code == "UNDEFINED_NAME":
            # Adicionar definição básica
            var_name = message.replace("Possivel nome indefinido: ", "")
            line_num = issue.get("line", 0)
            
            lines = file_content.splitlines()
            if 0 < line_num <= len(lines):
                # Inserir definição antes da linha problemática
                lines.insert(line_num - 1, f"{var_name} = None  # FIXME: Variavel adicionada automaticamente")
                patched = "\n".join(lines)
                
                return LLMResponse(
                    success=True,
                    patch=patched,
                    explanation=f"Adicionei definicao para variavel: {var_name}",
                    confidence=0.6,
                    metadata={"fix_type": "add_variable", "mode": "mock"}
                )
        
        elif code == "SYNTAX_ERROR":
            return LLMResponse(
                success=False,
                patch="",
                explanation="Erros de sintaxe requerem analise via LLM real (Perplexity).",
                confidence=0.0,
                metadata={"fix_type": "manual_required", "mode": "mock"}
            )
        
        # Fallback
        return LLMResponse(
            success=False,
            patch="",
            explanation=f"Tipo de erro nao suportado no modo mock: {code}",
            confidence=0.0,
            metadata={"fix_type": "unsupported", "mode": "mock"}
        )
    
    def _perplexity_fix(
        self,
        file_content: str,
        issue: dict[str, Any],
        context: dict[str, Any] | None
    ) -> LLMResponse:
        """
        Usa Perplexity API para gerar correção real.
        """
        
        # Construir prompt
        prompt = self._build_prompt(file_content, issue, context)
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": "Voce e um assistente especializado em corrigir codigo Python. Retorne APENAS o codigo corrigido completo, sem explicacoes ou markdown."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.2,
            "max_tokens": 2000
        }
        
        try:
            response = requests.post(self.api_url, json=payload, headers=headers, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            answer = data["choices"][0]["message"]["content"]
            
            # Limpar markdown code blocks se presente
            cleaned_code = self._clean_code_response(answer)
            
            return LLMResponse(
                success=True,
                patch=cleaned_code,
                explanation="Correcao gerada por Perplexity AI",
                confidence=0.85,
                metadata={
                    "model": self.model,
                    "mode": "perplexity",
                    "usage": data.get("usage", {})
                }
            )
        
        except requests.exceptions.RequestException as e:
            return LLMResponse(
                success=False,
                patch="",
                explanation=f"Erro ao chamar Perplexity API: {e}",
                confidence=0.0,
                metadata={"mode": "perplexity", "error": str(e)}
            )
        except Exception as e:
            return LLMResponse(
                success=False,
                patch="",
                explanation=f"Erro inesperado: {e}",
                confidence=0.0,
                metadata={"mode": "perplexity", "error": str(e)}
            )
    
    def _build_prompt(
        self,
        file_content: str,
        issue: dict[str, Any],
        context: dict[str, Any] | None
    ) -> str:
        """Constrói prompt para o LLM"""
        
        prompt = f"""Corrija o seguinte codigo Python que tem este erro:

**Erro detectado:**
- Tipo: {issue.get('code', 'UNKNOWN')}
- Mensagem: {issue.get('message', '')}
- Linha: {issue.get('line', 0)}
- Coluna: {issue.get('column', 0)}

**Codigo original:**
```python
{file_content}
```

**Instrucoes:**
1. Corrija APENAS o erro indicado
2. Mantenha toda a estrutura e formatacao original
3. Retorne o codigo completo corrigido
4. NAO adicione explicacoes, comentarios ou markdown
5. Retorne APENAS o codigo Python puro
"""
        
        if context:
            prompt += f"\n**Contexto:**\n{json.dumps(context, indent=2, ensure_ascii=False)}\n"
        
        return prompt
    
    def _clean_code_response(self, response: str) -> str:
        """Remove markdown code blocks se presente"""
        
        # Remover ```python ... ```
        if "```python" in response:
            response = response.split("```python").split("```")[1]
        elif "```" in response:
            response = response.split("```")[1].split("```")[0]
        
        # Remover espaços extras
        return response.strip()