# Arquivo: compatibility_validator.py
# Caminho: Agente_Independente / src / validator / compatibility_validator.py
# Propósito: Validador com 3 níveis + detecção de loops de correção

import ast
import hashlib
import os
import subprocess
import tempfile
from typing import Dict, Any, List


class CompatibilityValidator:
    def __init__(self) -> None:
        self.seen_count: Dict[str, int] = {}

    def hash_code(self, code: str) -> str:
        return hashlib.md5(code.encode('utf-8')).hexdigest()

    def _check_guardrails(self, code: str) -> bool:
        tree = ast.parse(code)

        class GuardrailVisitor(ast.NodeVisitor):
            def __init__(self):
                super().__init__()
                self.forbidden_calls: set[str] = set()

            def _get_func_name(self, node: ast.expr) -> str:
                if isinstance(node, ast.Name):
                    return node.id
                elif isinstance(node, ast.Attribute):
                    prefix = self._get_func_name(node.value)
                    if prefix:
                        return f"{prefix}.{node.attr}"
                return ""

            def visit_Call(self, node: ast.Call) -> None:
                func_name = self._get_func_name(node.func)
                if func_name:
                    self.forbidden_calls.add(func_name)
                self.generic_visit(node)

        visitor = GuardrailVisitor()
        visitor.visit(tree)

        forbidden = {
            'eval', 'exec', 'compile',
            'open', 'input',
            'os.system', 'os.popen',
            'subprocess.call', 'subprocess.Popen', 'subprocess.run',
            'sys.exit', 'exit', 'quit'
        }

        intersection = visitor.forbidden_calls & forbidden
        return len(intersection) == 0

    def _run_code(self, code: str, timeout_sec: float) -> Dict[str, Any]:
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False, encoding='utf-8') as f:
            f.write(code)
            f.flush()
            temp_file = f.name

        try:
            proc = subprocess.Popen(
                ['python', temp_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8'
            )
            stdout, stderr = proc.communicate(timeout=timeout_sec)
            return {
                'success': proc.returncode == 0,
                'output': stdout or '',
                'error': stderr or '',
                'returncode': proc.returncode
            }
        except subprocess.TimeoutExpired:
            proc.kill()
            return {
                'success': False,
                'output': '',
                'error': f'Timeout após {timeout_sec}s',
                'returncode': -1
            }
        except Exception as e:
            return {
                'success': False,
                'output': '',
                'error': str(e),
                'returncode': -1
            }
        finally:
            try:
                os.unlink(temp_file)
            except OSError:
                pass

    def validate(self, code: str, timeout: int = 10) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            'is_valid': False,
            'max_level_achieved': 0,
            'issues': [] as List[str],
            'execution_output': None,
            'loop_detected': False
        }

        # Detecção de loops de correção
        code_hash = self.hash_code(code)
        if code_hash in self.seen_count:
            self.seen_count[code_hash] += 1
            if self.seen_count[code_hash] > 3:
                result['loop_detected'] = True
                result['issues'].append('Loop de correção detectado: mesmo código submetido mais de 3 vezes.')
                return result
        else:
            self.seen_count[code_hash] = 1

        # Nível 1: Sintaxe
        try:
            compile(code, '<string>', 'exec')
            result['max_level_achieved'] = 1
        except SyntaxError as err:
            result['issues'].append(f'Erro de sintaxe: {err}')
            return result

        # Guardrails (bloqueia execução se violado)
        if not self._check_guardrails(code):
            result['issues'].append('Violação de guardrails: código contém chamadas perigosas.')
            return result

        # Nível 2: Testes básicos (execução curta)
        basic_result = self._run_code(code, 2.0)
        if not basic_result['success']:
            result['issues'].append(f'Testes básicos falharam: {basic_result["error"]}')
            return result
        result['max_level_achieved'] = 2

        # Nível 3: Execução completa com timeout
        full_result = self._run_code(code, timeout)
        if full_result['success']:
            result['is_valid'] = True
            result['max_level_achieved'] = 3
            result['execution_output'] = full_result['output']
        else:
            result['issues'].append(f'Execução completa falhou: {full_result["error"]}')

        return result

    def reset_history(self) -> None:
        """Reseta o histórico para detecção de loops."""
        self.seen_count.clear()
