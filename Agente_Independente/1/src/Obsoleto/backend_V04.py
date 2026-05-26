# backend.py
# Tools/Agente_Independente/1/src/backend.py

import os
import uuid
from datetime import datetime
from typing import Optional, List
from contextlib import asynccontextmanager

import asyncpg
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

DB_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "user": "postgres",
    "database": "agent_ia_automate",
    "password": os.getenv("DB_PASSWORD", "@FABECA0000")
}

@asynccontextmanager
async def lifespan(app: FastAPI):
    pool = await asyncpg.create_pool(**DB_CONFIG)
    app.state.pool = pool
    yield
    await pool.close()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ProjectCreate(BaseModel):
    name: str
    description: Optional[str] = None
    status: Optional[str] = "active"

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

async def get_pool() -> asyncpg.Pool:
    return app.state.pool

@app.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        try:
            row = await conn.fetchrow(
                """
                INSERT INTO projects (name, description, status)
                VALUES ($1, $2, $3)
                RETURNING id, name, description, status, created_at, updated_at
                """,
                project.name,
                project.description,
                project.status
            )
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=409, detail="Project name already exists")
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    return dict(row)

@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects():
    pool = await get_pool()
    async with pool.acquire() as conn:
        try:
            rows = await conn.fetch(
                "SELECT id, name, description, status, created_at, updated_at FROM projects"
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    return [dict(row) for row in rows]

@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: uuid.UUID):
    pool = await get_pool()
    async with pool.acquire() as conn:
        try:
            row = await conn.fetchrow(
                "SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = $1",
                project_id
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    if not row:
        raise HTTPException(status_code=404, detail="Project not found")
    return dict(row)

@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: uuid.UUID, update: ProjectUpdate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Build SET clause dynamically
        fields = []
        values = []
        idx = 1
        if update.name is not None:
            fields.append(f"name = ${idx}")
            values.append(update.name)
            idx += 1
        if update.description is not None:
            fields.append(f"description = ${idx}")
            values.append(update.description)
            idx += 1
        if update.status is not None:
            fields.append(f"status = ${idx}")
            values.append(update.status)
            idx += 1
        if not fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        values.append(project_id)
        query = f"""
            UPDATE projects
            SET {', '.join(fields)}, updated_at = NOW()
            WHERE id = ${idx}
            RETURNING id, name, description, status, created_at, updated_at
        """
        try:
            row = await conn.fetchrow(query, *values)
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    if not row:
        raise HTTPException(status_code=404, detail="Project not found")
    return dict(row)
