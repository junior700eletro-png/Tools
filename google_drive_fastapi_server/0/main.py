from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional
import io

from drive_service import get_drive_service

app = FastAPI(
    title="Google Drive API Server",
    description="Servidor que lê arquivos do Google Drive por ID e disponibiliza via HTTP",
    version="1.0.0"
)

class FileResponse(BaseModel):
    file_id: str
    name: str
    mime_type: str
    size: Optional[int] = None

@app.get("/")
def read_root():
    return {
        "message": "Servidor Google Drive API rodando!",
        "docs": "/docs",
        "endpoints": {
            "/files": "Listar arquivos recentes",
            "/files/{file_id}": "Obter metadados do arquivo",
            "/files/{file_id}/download": "Baixar conteúdo do arquivo"
        }
    }

@app.get("/files", response_model=list[FileResponse])
def list_files(page_size: int = 10):
    """Lista os arquivos recentes do Google Drive."""
    try:
        service = get_drive_service()
        results = (
            service.files()
            .list(pageSize=page_size, fields="files(id, name, mimeType, size)")
            .execute()
        )
        files = results.get("files", [])
        return files
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar arquivos: {str(e)}")

@app.get("/files/{file_id}", response_model=FileResponse)
def get_file_info(file_id: str):
    """Obtém metadados de um arquivo específico pelo ID."""
    try:
        service = get_drive_service()
        file_metadata = (
            service.files()
            .get(fileId=file_id, fields="id, name, mimeType, size")
            .execute()
        )
        return file_metadata
    except HttpException as e:
        raise HTTPException(status_code=404, detail=f"Arquivo não encontrado: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao obter arquivo: {str(e)}")

@app.get("/files/{file_id}/download")
def download_file(file_id: str):
    """Baixa o conteúdo de um arquivo do Google Drive."""
    try:
        service = get_drive_service()
        
        # Obtém metadados primeiro
        file_metadata = service.files().get(fileId=file_id).execute()
        file_name = file_metadata.get('name', 'arquivo')
        mime_type = file_metadata.get('mimeType', 'application/octet-stream')
        
        # Download do arquivo usando media_download
        from googleapiclient.http import MediaIoBaseDownload
        import io
        
        request = service.files().get_media(fileId=file_id)
        fh = io.BytesIO()
        downloader = MediaIoBaseDownload(fh, request)
        
        done = False
        while done is False:
            status, done = downloader.next_chunk()
        
        # Volta o ponteiro para o início
        fh.seek(0)
        
        return StreamingResponse(
            io.BytesIO(fh.read()),
            media_type=mime_type,
            headers={
                "Content-Disposition": f'attachment; filename="{file_name}"'
            }
        )
    except HttpException as e:
        raise HTTPException(status_code=404, detail=f"Arquivo não encontrado: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao baixar arquivo: {str(e)}")

@app.get("/files/{file_id}/text")
def get_text_content(file_id: str):
    """Obtém o conteúdo de texto de um arquivo (válido para txt, pdf, docs)."""
    try:
        service = get_drive_service()
        
        # Usa exports para documentos do Google Docs
        from googleapiclient.http import MediaIoBaseDownload
        import io
        
        # Tenta exportar como texto/plain para Google Docs
        try:
            request = service.files().export_media(fileId=file_id, mimeType='text/plain')
            fh = io.BytesIO()
            downloader = MediaIoBaseDownload(fh, request)
            done = False
            while done is False:
                status, done = downloader.next_chunk()
            fh.seek(0)
            return Response(content=fh.read().decode('utf-8'), media_type='text/plain')
        except:
            # Se não for Google Docs, tenta baixar normalmente
            request = service.files().get_media(fileId=file_id)
            fh = io.BytesIO()
            downloader = MediaIoBaseDownload(fh, request)
            done = False
            while done is False:
                status, done = downloader.next_chunk()
            fh.seek(0)
            return Response(content=fh.read().decode('utf-8'), media_type='text/plain')
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao obter conteúdo: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
