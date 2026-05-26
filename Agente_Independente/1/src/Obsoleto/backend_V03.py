# backend.py
# Tools/Agente_Independente/1/src/backend.py

import os
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, ConfigDict
import asyncpg

# Database configuration
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", 5432)),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "postgres"),
    "database": "agent_ia_automate",
}

# Pool instance
pool: Optional[asyncpg.Pool] = None

# Pydantic models (V2 style)
class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    status: Optional[str] = "pending"

class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

class ProjectResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Lifespan manager
async def lifespan(app: FastAPI):
    global pool
    try:
        pool = await asyncpg.create_pool(**DB_CONFIG, min_size=1, max_size=10)
        # Test connection
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        print("Database pool created successfully.")
    except Exception as e:
        print(f"Failed to create database pool: {e}")
        pool = None
    yield
    if pool:
        await pool.close()
        print("Database pool closed.")

app = FastAPI(title="Tools Backend", version="1.0.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Helper: get pool or raise 503
def get_pool() -> asyncpg.Pool:
    if pool is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection not available.",
        )
    return pool

# CREATE
@app.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    pool = get_pool()
    async with pool.acquire() as conn:
        project_id = uuid.uuid4()
        now = datetime.now(timezone.utc)
        try:
            row = await conn.fetchrow(
                """
                INSERT INTO projects (id, name, description, status, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $5)
                RETURNING id, name, description, status, created_at, updated_at
                """,
                project_id, project.name, project.description, project.status, now
            )
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Project with this ID already exists.")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    return ProjectResponse(**dict(row))

# READ ALL
@app.get("/projects", response_model=list[ProjectResponse])
async def read_projects():
    pool = get_pool()
    async with pool.acquire() as conn:
        try:
            rows = await conn.fetch("SELECT * FROM projects ORDER BY created_at DESC")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    return [ProjectResponse(**dict(row)) for row in rows]

# READ ONE
@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def read_project(project_id: uuid.UUID):
    pool = get_pool()
    async with pool.acquire() as conn:
        try:
            row = await conn.fetchrow("SELECT * FROM projects WHERE id = $1", project_id)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    if row is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    return ProjectResponse(**dict(row))

# UPDATE (PATCH)
@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: uuid.UUID, project: ProjectUpdate):
    pool = get_pool()
    # Build dynamic UPDATE query
    update_fields = {k: v for k, v in project.model_dump(exclude_none=True).items()}
    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update.")
    update_fields["updated_at"] = datetime.now(timezone.utc)
    set_clause = ", ".join(f"{key} = ${i+1}" for i, key in enumerate(update_fields))
    values = list(update_fields.values()) + [project_id]
    async with pool.acquire() as conn:
        try:
            row = await conn.fetchrow(
                f"UPDATE projects SET {set_clause} WHERE id = ${len(values)} RETURNING *",
                *values
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")
    if row is None:
        raise HTTPException(status_code=404, detail="Project not found.")
    return ProjectResponse(**dict(row))

# Health check
@app.get("/health")
async def health():
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available.")
    return {"status": "healthy"}
