import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "main:app",           # módulo:variável da app FastAPI
        host="0.0.0.0",
        port=8000,
        reload=False          # pode pôr True se quiser auto-reload em dev
    )
