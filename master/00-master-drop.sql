-- =============================================================
-- 00-master-drop.sql
-- Drops the Master DB routing tables, views, and triggers.
-- =============================================================

BEGIN;

-- 1. Drop Views
DROP VIEW IF EXISTS v_tenant_config CASCADE;

-- 2. Drop Triggers
DROP TRIGGER IF EXISTS clients_changed_at ON clients CASCADE;
DROP TRIGGER IF EXISTS instances_changed_at ON instances CASCADE;

-- 3. Drop Functions
DROP FUNCTION IF EXISTS set_changed_at() CASCADE;

-- 4. Drop Tables (Order matters due to Foreign Keys)
DROP TABLE IF EXISTS tenant_usage_log CASCADE;
DROP TABLE IF EXISTS instances CASCADE;
DROP TABLE IF EXISTS clients CASCADE;

COMMIT;