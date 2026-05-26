# backend.py
# Tools/Agente_Independente/1/src/backend.py

import os
from uuid import UUID
from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict
import asyncpg
from contextlib import asynccontextmanager

# Database configuration
DB_CONFIG = {
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "@FABECA0000"),
    "database": os.getenv("DB_NAME", "agent_ia_automate"),
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432))
}

# Global connection pool variable
pool: Optional[asyncpg.Pool] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    try:
        pool = await asyncpg.create_pool(**DB_CONFIG)
    except Exception as e:
        print(f"Failed to create connection pool: {e}")
        pool = None
    yield
    if pool:
        await pool.close()

app = FastAPI(title="Tools Backend", version="1.0.0", lifespan=lifespan)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class ProjectCreate(BaseModel):
    name: str
    description: Optional[str] = None
    status: Optional[str] = "active"

class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

class ProjectResponse(BaseModel):
    id: UUID
    name: str
    description: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

# Helper to get pool
async def get_pool() -> asyncpg.Pool:
    if pool is None:
        raise HTTPException(status_code=503, detail="Database connection pool not available")
    return pool

# Endpoints
@app.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    try:
        db = await get_pool()
        async with db.acquire() as conn:
            row = await conn.fetchrow(
                """INSERT INTO projects (name, description, status)
                   VALUES ($1, $2, $3)
                   RETURNING id, name, description, status, created_at, updated_at""",
                project.name, project.description, project.status
            )
            if not row:
                raise HTTPException(status_code=500, detail="Failed to create project")
            return ProjectResponse(**dict(row))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects():
    try:
        db = await get_pool()
        async with db.acquire() as conn:
            rows = await conn.fetch("SELECT id, name, description, status, created_at, updated_at FROM projects ORDER BY created_at DESC")
            return [ProjectResponse(**dict(row)) for row in rows]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: UUID):
    try:
        db = await get_pool()
        async with db.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = $1",
                project_id
            )
            if not row:
                raise HTTPException(status_code=404, detail="Project not found")
            return ProjectResponse(**dict(row))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: UUID, project: ProjectUpdate):
    try:
        db = await get_pool()
        async with db.acquire() as conn:
            # Build dynamic SET clause
            fields = []
            values = []
            idx = 1
            if project.name is not None:
                fields.append(f"name = ${idx}")
                values.append(project.name)
                idx += 1
            if project.description is not None:
                fields.append(f"description = ${idx}")
                values.append(project.description)
                idx += 1
            if project.status is not None:
                fields.append(f"status = ${idx}")
                values.append(project.status)
                idx += 1
            if not fields:
                raise HTTPException(status_code=400, detail="No fields to update")
            values.append(project_id)
            query = f"UPDATE projects SET {', '.join(fields)}, updated_at = NOW() WHERE id = ${idx} RETURNING id, name, description, status, created_at, updated_at"
            row = await conn.fetchrow(query, *values)
            if not row:
                raise HTTPException(status_code=404, detail="Project not found")
            return ProjectResponse(**dict(row))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)