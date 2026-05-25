import sqlite3
from pathlib import Path

# Cria o diretório data se não existir
Path("data").mkdir(exist_ok=True)

# Conecta ao banco de dados (cria se não existir)
conn = sqlite3.connect("data/database.db")
cursor = conn.cursor()

# Cria a tabela de usuários (exemplo comum)
cursor.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
""")

# Cria tabela de logs (opcional, mas comum)
cursor.execute("""
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
""")

conn.commit()
conn.close()

print("Banco de dados criado com sucesso!")
