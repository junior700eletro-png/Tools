from database import Base, engine
import models  # garante que os models sejam importados

def init_db():
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    init_db()
    print("Banco inicializado com sucesso.")
