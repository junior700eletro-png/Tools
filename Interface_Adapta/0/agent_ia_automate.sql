
-- This script creates the complete database for the AI agent project.
-- Run it in psql connected to the 'postgres' database (or equivalent superuser DB).

DROP DATABASE IF EXISTS agent_ia_automate;

CREATE DATABASE agent_ia_automate;

\connect agent_ia_automate

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create ENUM types
CREATE TYPE project_status AS ENUM ('ativo', 'arquivado');
CREATE TYPE tipo_mudanca AS ENUM ('criacao', 'atualizacao', 'validacao', 'execucao');
CREATE TYPE status_versao AS ENUM ('ativa', 'descartada', 'em_validacao');
CREATE TYPE resultado_tipo AS ENUM ('sucesso', 'falha', 'parcial');
CREATE TYPE validacao_status AS ENUM ('passou', 'falhou');

-- Create tables
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_projeto VARCHAR(255) NOT NULL,
    descricao TEXT,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status project_status NOT NULL DEFAULT 'ativo'
);

CREATE TABLE project_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    numero_versao INTEGER NOT NULL,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    criado_por VARCHAR(255),
    tipo_mudanca tipo_mudanca,
    resumo_mudancas TEXT,
    status_versao status_versao NOT NULL DEFAULT 'em_validacao'
);

CREATE TABLE project_json_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id UUID UNIQUE NOT NULL REFERENCES project_versions(id) ON DELETE CASCADE,
    json_completo JSONB NOT NULL,
    tamanho_bytes INTEGER,
    hash_sha256 VARCHAR(64),
    data_armazenamento TIMESTAMP
);

CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    version_id UUID REFERENCES project_versions(id),
    acao VARCHAR(255) NOT NULL,
    ator VARCHAR(255) NOT NULL,
    detalhes JSONB,
    resultado resultado_tipo,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE validation_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_id UUID NOT NULL REFERENCES project_versions(id) ON DELETE CASCADE,
    camada_validacao INTEGER CHECK (camada_validacao BETWEEN 1 AND 3),
    regra_validada VARCHAR(255) NOT NULL,
    status validacao_status NOT NULL,
    mensagem TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Unique constraint for version numbers per project
ALTER TABLE project_versions
ADD CONSTRAINT unique_project_version UNIQUE (project_id, numero_versao);

-- Trigger functions

-- Auto-increment version number per project
CREATE OR REPLACE FUNCTION set_next_version_number()
RETURNS TRIGGER AS $$
BEGIN
    SELECT COALESCE(MAX(numero_versao), 0) + 1 INTO NEW.numero_versao
    FROM project_versions
    WHERE project_id = NEW.project_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_next_version_number
    BEFORE INSERT ON project_versions
    FOR EACH ROW EXECUTE FUNCTION set_next_version_number();

-- Enforce retention: keep only last 5 active versions per project
CREATE OR REPLACE FUNCTION enforce_active_versions_retention()
RETURNS TRIGGER AS $$
DECLARE
    active_count INTEGER;
    oldest_version INTEGER;
BEGIN
    IF COALESCE(NEW.status_versao, '') = 'ativa' THEN
        SELECT COUNT(*) INTO active_count
        FROM project_versions
        WHERE project_id = NEW.project_id AND status_versao = 'ativa';
        
        IF active_count > 5 THEN
            SELECT MIN(numero_versao) INTO oldest_version
            FROM project_versions
            WHERE project_id = NEW.project_id AND status_versao = 'ativa';
            
            UPDATE project_versions
            SET status_versao = 'descartada'
            WHERE project_id = NEW.project_id
              AND numero_versao = oldest_version
              AND status_versao = 'ativa';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_active_versions_retention
    AFTER INSERT OR UPDATE OF status_versao ON project_versions
    FOR EACH ROW EXECUTE FUNCTION enforce_active_versions_retention();

-- Update data_atualizacao for projects
CREATE OR REPLACE FUNCTION update_projects_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_projects_updated_at();

-- Compute tamanho_bytes, hash_sha256, and data_armazenamento for JSON data
CREATE OR REPLACE FUNCTION compute_json_data()
RETURNS TRIGGER AS $$
BEGIN
    NEW.tamanho_bytes := octet_length(NEW.json_completo::text);
    NEW.hash_sha256 := encode(sha256(NEW.json_completo::bytea), 'hex');
    NEW.data_armazenamento := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_compute_json_data
    BEFORE INSERT ON project_json_data
    FOR EACH ROW EXECUTE FUNCTION compute_json_data();

-- Indexes
CREATE INDEX idx_project_versions_project_id ON project_versions (project_id);
CREATE INDEX idx_audit_log_project_id ON audit_log (project_id);
CREATE INDEX idx_validation_log_version_id ON validation_log (version_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log (timestamp);
CREATE INDEX idx_project_json_data_hash_sha256 ON project_json_data (hash_sha256);
