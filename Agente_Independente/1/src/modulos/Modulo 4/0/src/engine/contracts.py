from pydantic import BaseModel

class ExpertContext(BaseModel):
    problema: str
    historico: list[str] = []
    preferencias: dict = {}