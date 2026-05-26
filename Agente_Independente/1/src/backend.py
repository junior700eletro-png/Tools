# backend.py
# Tools/Agente_Independente/1/src/backend.py

import asyncio
from contextlib import asynccontextmanager
from typing import Optional
from uuid import UUID, uuid4
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict
import asyncpg

# Database configuration
DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "postgres",
    "password": "@FABECA0000",
    "database": "agent_ia_automate",
}

# Pool global
pool: Optional[asyncpg.Pool] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pool
    try:
        pool = await asyncpg.create_pool(
            **DB_CONFIG,
            ssl=False,
            timeout=10,
            min_size=2,
            max_size=10
        )
        print("Connection pool created successfully.")
    except Exception as e:
        print(f"Failed to create connection pool: {e}")
        pool = None
    yield
    if pool:
        await pool.close()
        print("Connection pool closed.")


app = FastAPI(title="Tools Backend", version="1.0.0", lifespan=lifespan)

# CORS
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
        raise HTTPException(status_code=500, detail="Database connection pool not available")
    return pool


# Endpoints
@app.get("/projects", response_model=list[ProjectResponse])
async def list_projects():
    conn_pool = await get_pool()
    async with conn_pool.acquire() as conn:
        rows = await conn.fetch("SELECT * FROM projects ORDER BY created_at DESC")
        return [ProjectResponse(**dict(row)) for row in rows]


@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: UUID):
    conn_pool = await get_pool()
    async with conn_pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM projects WHERE id = $1", project_id)
        if not row:
            raise HTTPException(status_code=404, detail="Project not found")
        return ProjectResponse(**dict(row))


@app.post("/projects", response_model=ProjectResponse, status_code=201)
async def create_project(project: ProjectCreate):
    conn_pool = await get_pool()
    async with conn_pool.acquire() as conn:
        project_id = uuid4()
        now = datetime.now(timezone.utc)
        try:
            await conn.execute(
                """
                INSERT INTO projects (id, name, description, status, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $5)
                """,
                project_id, project.name, project.description, project.status, now
            )
        except asyncpg.IntegrityConstraintViolationError as e:
            raise HTTPException(status_code=409, detail=f"Integrity error: {e}")
        row = await conn.fetchrow("SELECT * FROM projects WHERE id = $1", project_id)
        return ProjectResponse(**dict(row))


@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: UUID, project: ProjectUpdate):
    conn_pool = await get_pool()
    async with conn_pool.acquire() as conn:
        # Check existence
        existing = await conn.fetchrow("SELECT * FROM projects WHERE id = $1", project_id)
        if not existing:
            raise HTTPException(status_code=404, detail="Project not found")
        # Build update fields
        update_data = {k: v for k, v in project.model_dump(exclude_unset=True).items() if v is not None}
        if not update_data:
            return ProjectResponse(**dict(existing))
        update_data["updated_at"] = datetime.now(timezone.utc)
        set_clause = ", ".join([f"{key} = ${i+1}" for i, key in enumerate(update_data.keys())])
        values = list(update_data.values())
        values.append(project_id)
        query = f"UPDATE projects SET {set_clause} WHERE id = ${len(values)}"
        await conn.execute(query, *values)
        row = await conn.fetchrow("SELECT * FROM projects WHERE id = $1", project_id)
        return ProjectResponse(**dict(row))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
