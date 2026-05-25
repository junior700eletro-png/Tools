# Path: C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer\test_interface_adapta_communication.py
# Nome do script: test_interface_adapta_communication.py

import sys
import logging
from datetime import datetime
from pathlib import Path

# Adiciona o diretório base ao sys.path para imports locais
base_path = Path(r'C:\Users\user\Desktop\Tools\Agente_Independente\0\src\fixer')
sys.path.insert(0, str(base_path))

# Configuração de logging estruturado
log_dir = base_path / 'test_logs'
log_dir.mkdir(exist_ok=True)
log_filename = f'test_communication_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'
log_file = log_dir / log_filename

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

logger.info('Iniciando testes de comunicação entre core_v2.py e Interface_Adapta')

results = {}

# Teste 1: Importar core_v2
try:
    import core_v2
    results['import_core_v2'] = {'status': 'PASS'}
    logger.info('✅ PASS: Importar core_v2')
except Exception as e:
    results['import_core_v2'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Importar core_v2 - {e}')

# Teste 2: Importar MainOrchestrator de Interface_Adapta
try:
    from Interface_Adapta import MainOrchestrator
    results['import_main_orchestrator'] = {'status': 'PASS'}
    logger.info('✅ PASS: Importar MainOrchestrator')
except Exception as e:
    results['import_main_orchestrator'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Importar MainOrchestrator - {e}')

core_instance = None
orch = None

# Teste 3: Inicializar core_v2 (assumindo classe CoreV2)
try:
    core_instance = core_v2.CoreV2()
    results['init_core_v2'] = {'status': 'PASS', 'details': 'CoreV2 inicializado com sucesso'}
    logger.info('✅ PASS: Inicializar core_v2')
except Exception as e:
    results['init_core_v2'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Inicializar core_v2 - {e}')

# Teste 4: Inicializar MainOrchestrator
try:
    orch = MainOrchestrator()
    results['init_orchestrator'] = {'status': 'PASS', 'details': 'MainOrchestrator inicializado'}
    logger.info('✅ PASS: Inicializar MainOrchestrator')
except Exception as e:
    results['init_orchestrator'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Inicializar MainOrchestrator - {e}')

# Teste 5: Validar formatação de prompt (assumindo orch.format_prompt(code: str) -> str)
test_code = '''def buggy_function():
    print('Erro sem return')'''
try:
    if orch is None:
        raise ValueError('MainOrchestrator não inicializado')
    formatted_prompt = orch.format_prompt(test_code)
    if isinstance(formatted_prompt, str) and len(formatted_prompt) > 50:
        results['prompt_formatting'] = {'status': 'PASS', 'formatted_preview': formatted_prompt[:100] + '...'}
        logger.info('✅ PASS: Validar formatação de prompt')
    else:
        raise ValueError('Prompt formatado inválido (não é str ou muito curto)')
except Exception as e:
    results['prompt_formatting'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Validar formatação de prompt - {e}')

# Teste 6: Testar envio ao Expert (com mock)
class MockExpert:
    def __call__(self, prompt):
        logger.info(f'MockExpert processando prompt de {len(prompt)} chars')
        return f'Resposta mock do Expert: código corrigido para o problema identificado em "{prompt[:30]}..."'

response = None
try:
    if orch is None:
        raise ValueError('MainOrchestrator não inicializado')
    orch.expert = MockExpert()  # Mocka o expert (assumindo uso de self.expert(prompt))
    response = orch.send_to_expert(formatted_prompt)  # Assumindo método send_to_expert(prompt)
    if isinstance(response, str) and len(response) > 20:
        results['send_to_expert'] = {'status': 'PASS', 'response_preview': response[:100] + '...'}
        logger.info('✅ PASS: Envio ao Expert (mock)')
    else:
        raise ValueError('Resposta do Expert inválida')
except Exception as e:
    results['send_to_expert'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Envio ao Expert - {e}')

# Teste 7: Validar integração com PatchGenerator (assumindo orch.generate_patch(response) -> str)
try:
    if orch is None or response is None:
        raise ValueError('Orchestrator ou response não disponíveis')
    patch = orch.generate_patch(response)  # Assumindo método de integração
    if isinstance(patch, str) and ('patch' in patch.lower() or len(patch) > 50):
        results['patch_generator_integration'] = {'status': 'PASS', 'patch_preview': patch[:100] + '...'}
        logger.info('✅ PASS: Integração com PatchGenerator')
    else:
        raise ValueError('Patch gerado inválido')
except Exception as e:
    results['patch_generator_integration'] = {'status': 'FAIL', 'error': str(e)}
    logger.error(f'❌ FAIL: Integração com PatchGenerator - {e}')

# Função para gerar relatório estruturado
def print_report(results):
    print('\n' + '='*80)
    print('RELATÓRIO ESTRUTURADO DE TESTES')
    print('COMUNICAÇÃO CORE_V2.PY x INTERFACE_ADAPTA')
    print('='*80)
    total = len(results)
    passed = sum(1 for v in results.values() if v['status'] == 'PASS')
    print(f'📊 RESUMO:')
    print(f'   Testes passados: {passed}/{total}')
    print(f'   Taxa de sucesso: {(passed/total)*100:.1f}%')
    print(f'   Arquivo de log: {log_file}')
    print('\n📋 DETALHES:')
    for test_name, res in results.items():
        status = '✅ PASS' if res['status'] == 'PASS' else '❌ FAIL'
        print(f'   {test_name}: {status}')
        if 'error' in res:
            print(f'      Erro: {res["error"]}')
        if 'details' in res:
            print(f'      Detalhes: {res["details"]}')
        if 'formatted_preview' in res:
            print(f'      Preview: {res["formatted_preview"]}')
        if 'response_preview' in res:
            print(f'      Preview: {res["response_preview"]}')
        if 'patch_preview' in res:
            print(f'      Preview: {res["patch_preview"]}')
    print('='*80)
    logger.info(f'Testes concluídos. Passados: {passed}/{total}')

print_report(results)

