class ContextValidator:
    def validar(self, contexto):
        if not contexto.get("problema"):
            return False, "Problema não informado"
        return True, "OK"