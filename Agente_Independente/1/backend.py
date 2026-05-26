# backend.py
# Tools/Agente_Independente/1/src/backend.py

from contextlib import asynccontextmanager
from typing import List, Optional
from uuid import UUID, uuid4

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
import asyncpg
from datetime import datetime

# Database connection pool
db_pool = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    global db_pool
    db_pool = await asyncpg.create_pool(
        user='postgres',
        password='postgres',
        database='agent_ia_automate',
        host='localhost',
        port=5432,
        min_size=2,
        max_size=10
    )
    yield
    # Shutdown
    await db_pool.close()

app = FastAPI(lifespan=lifespan, title='Tools Backend', version='1.0.0')

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],  # Adjust in production
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

# Pydantic models
class ProjectBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    status: str = Field(default='active', pattern='^(active|inactive|archived)$')

class ProjectCreate(ProjectBase):
    pass

class ProjectUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    status: Optional[str] = Field(None, pattern='^(active|inactive|archived)$')

class Project(ProjectBase):
    id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Helper function to get project or raise 404
async def get_project_or_404(project_id: UUID) -> dict:
    async with db_pool.acquire() as conn:
        row = await conn.fetchrow(
            'SELECT id, name, description, status, created_at, updated_at FROM projects WHERE id = $1',
            project_id
        )
        if row is None:
            raise HTTPException(status_code=404, detail='Project not found')
        return dict(row)

# Endpoints
@app.post('/projects', response_model=Project, status_code=status.HTTP_201_CREATED)
async def create_project(project: ProjectCreate):
    async with db_pool.acquire() as conn:
        project_id = uuid4()
        now = datetime.utcnow()
        try:
            await conn.execute(
                'INSERT INTO projects (id, name, description, status, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6)',
                project_id, project.name, project.description, project.status, now, now
            )
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=409, detail='Project name already exists')
        except Exception as e:
            raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
    return Project(id=project_id, name=project.name, description=project.description, status=project.status, created_at=now, updated_at=now)

@app.get('/projects', response_model=List[Project])
async def list_projects():
    async with db_pool.acquire() as conn:
        rows = await conn.fetch('SELECT id, name, description, status, created_at, updated_at FROM projects ORDER BY created_at')
        return [dict(row) for row in rows]

@app.get('/projects/{project_id}', response_model=Project)
async def get_project(project_id: UUID):
    project_data = await get_project_or_404(project_id)
    return project_data

@app.patch('/projects/{project_id}', response_model=Project)
async def update_project(project_id: UUID, project_update: ProjectUpdate):
    # Fetch existing project
    existing = await get_project_or_404(project_id)
    # Build update fields
    update_fields = {}
    if project_update.name is not None:
        update_fields['name'] = project_update.name
    if project_update.description is not None:
        update_fields['description'] = project_update.description
    if project_update.status is not None:
        update_fields['status'] = project_update.status
    if not update_fields:
        raise HTTPException(status_code=400, detail='No fields to update')
    update_fields['updated_at'] = datetime.utcnow()
    
    # Build SET clause dynamically
    set_clause = ', '.join(f"{k} = ${i+1}" for i, k in enumerate(update_fields.keys()))
    values = list(update_fields.values()) + [project_id]
    query = f"UPDATE projects SET {set_clause} WHERE id = ${len(values)}"
    
    async with db_pool.acquire() as conn:
        try:
            await conn.execute(query, *values)
        except asyncpg.exceptions.UniqueViolationError:
            raise HTTPException(status_code=409, detail='Project name already exists')
        except Exception as e:
            raise HTTPException(status_code=500, detail=f'Database error: {str(e)}')
    # Return updated project
    updated = await get_project_or_404(project_id)
    return updated