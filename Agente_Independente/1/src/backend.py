# backend.py
# Tools/Agente_Independente/1/src/backend.py

import uuid
from datetime import datetime
from typing import Optional

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator, ConfigDict, UUID4
import asyncpg

# Database configuration
DATABASE_URL = "postgresql://postgres:password@localhost:5432/agent_ia_automate"  # Update password as needed

app = FastAPI(title="Tools Agent API", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection pool
pool: asyncpg.Pool = None

async def get_pool() -> asyncpg.Pool:
    global pool
    if pool is None:
        pool = await asyncpg.create_pool(DATABASE_URL, min_size=2, max_size=10)
    return pool

@app.on_event("startup")
async def startup():
    await get_pool()

@app.on_event("shutdown")
async def shutdown():
    if pool:
        await pool.close()

# Pydantic models
class ProjectBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Project name")
    description: Optional[str] = Field(None, max_length=1000, description="Project description")
    status: Optional[str] = Field("active", description="Project status")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v):
        allowed = ["active", "inactive", "archived"]
        if v not in allowed:
            raise ValueError(f"Status must be one of {allowed}")
        return v

    model_config = ConfigDict(extra="forbid")

class ProjectCreate(ProjectBase):
    pass

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = Field(None)

    @field_validator("status")
    @classmethod
    def validate_status(cls, v):
        if v is not None:
            allowed = ["active", "inactive", "archived"]
            if v not in allowed:
                raise ValueError(f"Status must be one of {allowed}")
        return v

    model_config = ConfigDict(extra="forbid")

class ProjectResponse(ProjectBase):
    id: UUID4
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Helper to fetch project by id
async def get_project_by_id(conn, project_id):
    row = await conn.fetchrow(
        "SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = $1",
        project_id
    )
    return row

# Endpoints
@app.post("/projects", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            try:
                row = await conn.fetchrow(
                    """
                    INSERT INTO projects (id, name, description, status, created_at, updated_at)
                    VALUES ($1, $2, $3, $4, NOW(), NOW())
                    RETURNING id, name, description, status, created_at, updated_at
                    """,
                    uuid.uuid4(), project.name, project.description, project.status
                )
                return ProjectResponse(**dict(row))
            except asyncpg.exceptions.UniqueViolationError:
                raise HTTPException(status_code=409, detail="Project with this name already exists.")
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/projects/{project_id}", response_model=ProjectResponse)
async def get_project(project_id: UUID4):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await get_project_by_id(conn, project_id)
        if not row:
            raise HTTPException(status_code=404, detail="Project not found.")
        return ProjectResponse(**dict(row))

@app.patch("/projects/{project_id}", response_model=ProjectResponse)
async def update_project(project_id: UUID4, updates: ProjectUpdate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        async with conn.transaction():
            # Check existence
            existing = await get_project_by_id(conn, project_id)
            if not existing:
                raise HTTPException(status_code=404, detail="Project not found.")

            # Build dynamic update
            update_fields = {}
            for field in ["name", "description", "status"]:
                value = getattr(updates, field, None)
                if value is not None:
                    update_fields[field] = value

            if not update_fields:
                raise HTTPException(status_code=400, detail="No fields to update.")

            set_clause = ", ".join([f"{key} = ${i+1}" for i, key in enumerate(update_fields.keys())])
            values = list(update_fields.values())
            values.append(project_id)
            query = f"""
                UPDATE projects
                SET {set_clause}, updated_at = NOW()
                WHERE id = ${len(values)}
                RETURNING id, name, description, status, created_at, updated_at
            """
            try:
                row = await conn.fetchrow(query, *values)
                return ProjectResponse(**dict(row))
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
