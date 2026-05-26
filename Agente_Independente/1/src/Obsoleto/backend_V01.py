# backend.py
# Tools/Agente_Independente/0/src
import uuid
from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, validator
import asyncpg
from asyncpg import Pool

app = FastAPI(title="Tools Ecosystem API", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection pool
pool: Pool = None

async def get_pool() -> Pool:
    global pool
    if pool is None:
        pool = await asyncpg.create_pool(
            user="postgres",
            password="password",
            database="agent_ia_automate",
            host="localhost",
            port=5432,
            min_size=1,
            max_size=10
        )
    return pool

# Pydantic models
class ProjectCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: str = Field("active", regex="^(active|inactive|archived)$")

    @validator("name")
    def name_not_empty(cls, v):
        if not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    status: Optional[str] = Field(None, regex="^(active|inactive|archived)$")

    @validator("name")
    def name_not_empty(cls, v):
        if v is not None and not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip() if v else v

class ProjectResponse(BaseModel):
    id: uuid.UUID
    name: str
    description: Optional[str]
    status: str
    created_at: datetime
    updated_at: datetime

# Helper to fetch project by id
async def get_project_by_id(conn, project_id: uuid.UUID) -> Optional[dict]:
    row = await conn.fetchrow(
        "SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = $1",
        project_id
    )
    return row

# Endpoints
@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("SELECT id, name, description, status, created_at, updated_at FROM projects ORDER BY created_at DESC")
        return [dict(row) for row in rows]

@app.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        project_id = uuid.uuid4()
        now = datetime.utcnow()
        try:
            await conn.execute(
                """INSERT INTO projects (id, name, description, status, created_at, updated_at)
                   VALUES ($1, $2, $3, $4, $5, $6)""",
                project_id, project.name, project.description, project.status, now, now
            )
        except asyncpg.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Project with this id already exists")
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        return {
            "id": project_id,
            "name": project.name,
            "description": project.description,
            "status": project.status,
            "created_at": now,
            "updated_at": now
        }

@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: uuid.UUID):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await get_project_by_id(conn, project_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Project not found")
        return dict(row)

@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: uuid.UUID, project: ProjectUpdate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await get_project_by_id(conn, project_id)
        if existing is None:
            raise HTTPException(status_code=404, detail="Project not found")
        update_data = project.dict(exclude_unset=True)
        if not update_data:
            return dict(existing)
        update_data["updated_at"] = datetime.utcnow()
        set_clause = ", ".join([f"{key} = ${idx+1}" for idx, key in enumerate(update_data.keys())])
        values = list(update_data.values()) + [project_id]
        query = f"UPDATE projects SET {set_clause} WHERE id = ${len(values)}"
        try:
            await conn.execute(query, *values)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
        updated = await get_project_by_id(conn, project_id)
        return dict(updated)

# Startup and shutdown events
@app.on_event("startup")
async def startup():
    global pool
    pool = await asyncpg.create_pool(
        user="postgres",
        password="password",
        database="agent_ia_automate",
        host="localhost",
        port=5432,
        min_size=1,
        max_size=10
    )

@app.on_event("shutdown")
async def shutdown():
    global pool
    if pool:
        await pool.close()