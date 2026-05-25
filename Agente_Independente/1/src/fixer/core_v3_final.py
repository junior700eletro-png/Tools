# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\core_v3_final.py
# Nome: core_v3_final.py

# Versão final integrada pronta para produção.
# Validação com skill #Validar Sintaxe Python integrada via AST.

import logging
import time
import json
import ast
import hashlib
import uuid
from typing import Optional, Tuple, Dict, Any

# Assume import do parent (disponível no projeto)
from fixer.core_v2 import FixerCoreV2


class FixerCoreV3Final(FixerCoreV2):
    CACHE_TTL = 3600  # 1 hora
    CLEANUP_INTERVAL = 86400  # 1 dia
    MAX_RETRIES = 3
    BACKOFF_FACTOR = 2
    QUALITY_THRESHOLD = 0.7

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.metrics: Dict[str, float] = {'total': 0.0, 'success': 0.0, 'total_time': 0.0}
        self.last_cleanup = time.time()
        self.logger = logging.getLogger(self.__class__.__name__)
        if not self.logger.handlers:
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
            )

    def validate_before_expert(self, code: str, error: str) -> Tuple[bool, str]:
        """Validações finais antes de chamar Expert, incluindo sintaxe Python."""
        self.logger.info("Iniciando validação antes do expert", extra={'code_len': len(code)})
        try:
            ast.parse(code)
            return True, "Sintaxe Python válida."
        except SyntaxError as se:
            msg = f"Erro de sintaxe: {str(se)[:200]}"
            self.logger.warning(msg)
            return False, msg
        # Validações adicionais podem ser adicionadas aqui
        return True, "OK"

    def _generate_cache_key(self, code: str, error: str) -> str:
        data = code + error
        return hashlib.md5(data.encode()).hexdigest()

    def get_cached_response(self, key: str) -> Optional[str]:
        if key in self.cache:
            cached = self.cache[key]
            if time.time() - cached['timestamp'] < self.CACHE_TTL:
                self.logger.debug(f"Cache hit: {key[:8]}...")
                return cached['response']
            else:
                del self.cache[key]
        return None

    def cache_response(self, key: str, response: str) -> None:
        self.cache[key] = {'response': response, 'timestamp': time.time()}
        self.logger.debug(f"Cache set: {key[:8]}...")

    def cleanup_old_cache(self) -> None:
        now = time.time()
        if now - self.last_cleanup > 3600:  # Limpa a cada hora
            cleaned = 0
            for k in list(self.cache.keys()):
                if now - self.cache[k]['timestamp'] > self.CLEANUP_INTERVAL:
                    del self.cache[k]
                    cleaned += 1
            self.last_cleanup = now
            self.logger.info(f"Limpeza de cache: {cleaned} entradas antigas removidas")

    def analyze_patch_quality(self, original: str, patched: str, original_error: str) -> float:
        """Análise de qualidade do patch gerado (heurísticas)."""
        score = 0.0
        max_score = 3.0

        # 1. Verifica sintaxe do patch
        try:
            compile(patched, '<string>', 'exec')
            score += 1.0
        except:
            pass

        # 2. Melhoria de tamanho (não muito maior)
        if len(patched) <= len(original) * 1.5:
            score += 1.0

        # 3. Comprimento razoável (heurística simples)
        if 10 < len(patched) < 10000:
            score += 1.0

        score /= max_score
        self.logger.info(f"Qualidade do patch: {score:.2f}", extra={'len_original': len(original), 'len_patch': len(patched)})
        return score

    def _call_expert_with_retry(self, code: str, error: str, trace_id: str) -> str:
        """Chamada ao Expert com retries e backoff exponencial."""
        for attempt in range(self.MAX_RETRIES):
            try:
                # Assume self.expert do parent
                patch = self.expert.generate_patch(code, error)
                self.logger.info(f"Expert sucesso (tentativa {attempt+1})", extra={'trace_id': trace_id})
                return patch
            except Exception as e:
                self.logger.warning(f"Expert falhou (tentativa {attempt+1}): {e}", extra={'trace_id': trace_id})
                if attempt < self.MAX_RETRIES - 1:
                    time.sleep(self.BACKOFF_FACTOR ** attempt)
        raise RuntimeError(f"Expert falhou após {self.MAX_RETRIES} tentativas")

    def execute_with_fallback(self, code: str, error: str, trace_id: str) -> Optional[str]:
        """Executa Interface_Adapta com fallback automático."""
        try:
            # Assume self.interface_adapta do parent
            patch = self.interface_adapta(code, error)
            self.logger.info("Interface_Adapta sucesso", extra={'trace_id': trace_id})
            return patch
        except Exception as e:
            self.logger.error(f"Interface_Adapta falhou ({e}), fallback ativado", extra={'trace_id': trace_id})
            return None

    def log_metrics(self) -> None:
        if self.metrics['total'] > 0:
            success_rate = self.metrics['success'] / self.metrics['total']
            avg_time = self.metrics['total_time'] / self.metrics['total']
            self.logger.info("Métricas de performance", extra={
                'total': int(self.metrics['total']),
                'sucessos': int(self.metrics['success']),
                'taxa_sucesso': f"{success_rate:.2%}",
                'tempo_medio': f"{avg_time:.2f}s"
            })

    def fix_code(self, buggy_code: str, error_msg: str) -> str:
        """Método principal: fluxo completo com cache, validações, fallback, etc."""
        trace_id = str(uuid.uuid4())
        start_time = time.time()
        self.metrics['total'] += 1

        self.logger.info("Início do fix", extra={'trace_id': trace_id, 'code_len': len(buggy_code)})

        key = self._generate_cache_key(buggy_code, error_msg)
        cached = self.get_cached_response(key)
        if cached:
            end_time = time.time()
            self.metrics['total_time'] += end_time - start_time
            self.metrics['success'] += 1
            self.log_metrics()
            self.cleanup_old_cache()
            return cached

        # Validação
        valid, msg = self.validate_before_expert(buggy_code, error_msg)
        if not valid:
            end_time = time.time()
            self.metrics['total_time'] += end_time - start_time
            raise ValueError(f"Validação falhou: {msg}")

        patch = None
        is_success = False
        try:
            adapta_patch = self.execute_with_fallback(buggy_code, error_msg, trace_id)
            if adapta_patch:
                quality = self.analyze_patch_quality(buggy_code, adapta_patch, error_msg)
                if quality >= self.QUALITY_THRESHOLD:
                    patch = adapta_patch
                    is_success = True
                else:
                    self.logger.info("Qualidade adapta baixa, usando expert", extra={'trace_id': trace_id})

            if not patch:
                patch = self._call_expert_with_retry(buggy_code, error_msg, trace_id)
                is_success = True

        except Exception as e:
            self.logger.error(f"Erro no fix: {e}", extra={'trace_id': trace_id})
            raise
        finally:
            end_time = time.time()
            self.metrics['total_time'] += end_time - start_time
            if is_success:
                self.metrics['success'] += 1
                self.cache_response(key, patch)
            self.log_metrics()
            self.cleanup_old_cache()
            self.logger.info("Fix concluído", extra={'trace_id': trace_id, 'success': is_success})

        return patch

