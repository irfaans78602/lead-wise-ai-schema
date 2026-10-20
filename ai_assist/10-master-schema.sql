-- =============================================================
-- 10-master-schema.sql
-- Master DB schema for multi-tenant routing.
-- =============================================================

BEGIN;

-- Enable UUID extension just in case we want Postgres to generate IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -------------------------------------------------------------
-- 1. Clients Table (The Account)
-- -------------------------------------------------------------
CREATE TABLE clients (
    client_id           UUID PRIMARY KEY,
    client_name         TEXT NOT NULL,
    admin_email         TEXT NOT NULL,
    
    -- Shared Configuration (Inherited by ALL instances if they are NULL)
    db_connect_string   TEXT NOT NULL,
    gemini_api_key      TEXT NOT NULL,
    allowed_origins     TEXT, 
    brand_color         TEXT DEFAULT '#2BB673',
    
    -- Account Status
    status              TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial')),
    start_date          DATE NOT NULL DEFAULT '1900-01-01',
    end_date            DATE NOT NULL DEFAULT '9999-12-31',
    
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    CHECK (start_date <= end_date)
);

-- -------------------------------------------------------------
-- 2. Instances Table (The Deployments)
-- -------------------------------------------------------------
CREATE TABLE instances (
    instance_id         UUID PRIMARY KEY, 
    client_id           UUID NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    
    instance_type       TEXT NOT NULL CHECK (instance_type IN ('public', 'internal')),
    
    -- Optional Overrides: If NULL, they inherit from the clients table
    db_connect_string   TEXT,
    gemini_api_key      TEXT,
    brand_color         TEXT,
    
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX instances_client_id_idx ON instances (client_id);

-- -------------------------------------------------------------
-- 3. Tenant Usage Log (Global Analytics)
-- -------------------------------------------------------------
CREATE TABLE tenant_usage_log (
    log_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    instance_id     UUID NOT NULL REFERENCES instances(instance_id) ON DELETE CASCADE,
    question_length INT NOT NULL,
    status          TEXT NOT NULL,
    chunks_found    INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX tenant_usage_date_idx ON tenant_usage_log (created_at DESC);

-- -------------------------------------------------------------
-- 4. Triggers (Auto-update changed_at)
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_changed_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.changed_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clients_changed_at
    BEFORE UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION set_changed_at();

CREATE TRIGGER instances_changed_at
    BEFORE UPDATE ON instances
    FOR EACH ROW EXECUTE FUNCTION set_changed_at();

-- -------------------------------------------------------------
-- 5. View (Flattens the JOIN and handles inheritance)
-- -------------------------------------------------------------
CREATE VIEW v_tenant_config AS
SELECT 
    i.instance_id,
    i.instance_type,
    c.client_id,
    c.client_name,
    -- Inherit DB String: Use instance DB if it exists, otherwise use client DB
    COALESCE(i.db_connect_string, c.db_connect_string) AS db_connect_string,
    -- Inherit API key: Use instance key if it exists, otherwise use client key
    COALESCE(i.gemini_api_key, c.gemini_api_key) AS gemini_api_key,
    -- Inherit Brand Color: Use instance color if it exists, otherwise use client color
    COALESCE(i.brand_color, c.brand_color) AS brand_color,
    c.allowed_origins,
    c.status
FROM instances i
JOIN clients c ON c.client_id = i.client_id
WHERE c.status IN ('active', 'trial')
  AND CURRENT_DATE BETWEEN c.start_date AND c.end_date;

COMMIT;