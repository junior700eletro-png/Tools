# backend.py
# Tools/Agente_Independente/1/src/backend.py

import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import asyncpg
from contextlib import asynccontextmanager

# Database configuration
DB_CONFIG = {
    "user": "postgres",
    "password": "postgres",
    "database": "agent_ia_automate",
    "host": "localhost"
}

# Global connection pool
pool = None

# Pydantic models (V2)
class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str = Field(default="", max_length=1000)
    status: str = Field(default="active", max_length=50)

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = Field(None, max_length=50)

class ProjectResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: str
    status: str
    created_at: datetime
    updated_at: datetime

class ProjectInDB(ProjectResponse):
    pass

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    try:
        pool = await asyncpg.create_pool(**DB_CONFIG)
        yield
    finally:
        if pool:
            await pool.close()

# Create FastAPI app
app = FastAPI(lifespan=lifespan)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Helper to execute queries
async def execute(query: str, *args):
    async with pool.acquire() as conn:
        return await conn.execute(query, *args)

async def fetchrow(query: str, *args):
    async with pool.acquire() as conn:
        return await conn.fetchrow(query, *args)

async def fetchall(query: str):
    async with pool.acquire() as conn:
        return await conn.fetch(query)

# Endpoints
@app.post("/projects", response_model=ProjectResponse, status_code=201)
async def create_project(project: ProjectCreate):
    query = """
        INSERT INTO projects (id, name, description, status, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $5)
        RETURNING *
    """
    project_id = uuid.uuid4()
    now = datetime.utcnow()
    try:
        row = await fetchrow(query, project_id, project.name, project.description, project.status, now)
        if row is None:
            raise HTTPException(status_code=500, detail="Failed to create project")
        return ProjectResponse(**dict(row))
    except asyncpg.PostgresError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects():
    query = "SELECT * FROM projects ORDER BY created_at DESC"
    try:
        rows = await fetchall(query)
        return [ProjectResponse(**dict(row)) for row in rows]
    except asyncpg.PostgresError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: uuid.UUID):
    query = "SELECT * FROM projects WHERE id = $1"
    try:
        row = await fetchrow(query, project_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Project not found")
        return ProjectResponse(**dict(row))
    except asyncpg.PostgresError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: uuid.UUID, project_update: ProjectUpdate):
    # Build dynamic update query
    fields_to_update = []
    values = []
    idx = 1
    if project_update.name is not None:
        fields_to_update.append(f"name = ${idx}")
        values.append(project_update.name)
        idx += 1
    if project_update.description is not None:
        fields_to_update.append(f"description = ${idx}")
        values.append(project_update.description)
        idx += 1
    if project_update.status is not None:
        fields_to_update.append(f"status = ${idx}")
        values.append(project_update.status)
        idx += 1
    if not fields_to_update:
        raise HTTPException(status_code=400, detail="No fields to update")
    fields_to_update.append(f"updated_at = ${idx}")
    values.append(datetime.utcnow())
    values.append(project_id)
    
    query = f"""
        UPDATE projects
        SET {', '.join(fields_to_update)}
        WHERE id = ${idx+1}
        RETURNING *
    """
    try:
        row = await fetchrow(query, *values)
        if row is None:
            raise HTTPException(status_code=404, detail="Project not found")
        return ProjectResponse(**dict(row))
    except asyncpg.PostgresError as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# Health check
@app.get("/health")
async def health_check():
    return {"status": "ok"}