import os.path
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Scopes para leitura apenas do Drive
SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]

def get_drive_service():
    """Cria e retorna o serviço do Google Drive autenticado."""
    creds = None
    
    # Carrega credenciais salvas do token.json
    if os.path.exists("token.json"):
        creds = Credentials.from_authorized_user_file("token.json", SCOPES)
    
    # Se não houver credenciais válidas, faz o login
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                "credentials.json", SCOPES
            )
            creds = flow.run_local_server(port=8080)
        
        # Salva as credenciais para o próximo uso
        with open("token.json", "w") as token:
            token.write(creds.to_json())
    
    return build("drive", "v3", credentials=creds)
