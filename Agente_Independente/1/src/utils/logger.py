# Arquivo: logger.py
# Caminho: Agente_Independente / src / utils / logger.py
# Propósito: Fornece logging centralizado para o agente autônomo

import logging
import os
from logging.handlers import RotatingFileHandler

def setup_logger(log_dir='logs', log_file='agent.log', level=logging.INFO, max_bytes=10*1024*1024, backup_count=5):
    """
    Configura o logger com RotatingFileHandler e handler de console.
    """
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, log_file)

    logger = logging.getLogger('agent')
    logger.setLevel(level)

    # File handler com rotação
    file_handler = RotatingFileHandler(log_path, maxBytes=max_bytes, backupCount=backup_count)
    file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    # Console handler
    console_handler = logging.StreamHandler()
    console_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    logger.propagate = False
    return logger

def get_logger(name='agent'):
    """
    Retorna o logger configurado.
    """
    return logging.getLogger(name)

def log_patch_execution(patch_name, success=True, details=""):
    """
    Registra a execução de um patch.
    """
    logger = get_logger()
    status = "sucesso" if success else "falha"
    logger.info(f"Execução de patch '{patch_name}': {status} - {details}")

def log_validation_result(validation_name, passed=True, details=""):
    """
    Registra o resultado de uma validação.
    """
    logger = get_logger()
    status = "aprovada" if passed else "reprovada"
    logger.info(f"Validação '{validation_name}': {status} - {details}")

