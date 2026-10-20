-- =============================================================
-- 00-rag-drop.sql
-- Drops everything created by 10-rag-schema.sql.
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- 1. Views
-- -------------------------------------------------------------
DROP VIEW IF EXISTS v_ask_ai_gaps   CASCADE;
DROP VIEW IF EXISTS active_settings CASCADE;

-- -------------------------------------------------------------
-- 2. Tables
-- -------------------------------------------------------------
DROP TABLE IF EXISTS ask_ai_log    CASCADE;
DROP TABLE IF EXISTS site_content  CASCADE;
DROP TABLE IF EXISTS settings      CASCADE;

-- -------------------------------------------------------------
-- 3. Leftover report (warnings only, never aborts)
-- -------------------------------------------------------------
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.relname AS name, c.relkind::text AS kind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r','p','v','m','f')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.objid = c.oid AND d.deptype = 'e')
    ORDER BY c.relname
  LOOP
    RAISE WARNING 'Left over (relation, kind %): public.%', r.kind, r.name;
  END LOOP;
END $$;

COMMIT;