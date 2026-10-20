-- =============================================================
-- 10-rag-schema.sql
-- Ask AI / RAG Backend. Postgres 14+.
-- =============================================================

BEGIN;

-- =============================================================
-- 0. Extensions
-- =============================================================
CREATE EXTENSION IF NOT EXISTS vector;

-- =============================================================
-- 1. Settings (Required by ask_ai.py for rate limits)
-- =============================================================
CREATE TABLE settings (
    setting_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setting_key    TEXT NOT NULL UNIQUE,
    setting_value  NUMERIC(10,4) NOT NULL,
    setting_type   TEXT NOT NULL DEFAULT 'number'
                   CHECK (setting_type IN ('number','boolean','integer')),
    description    TEXT,
    start_date     DATE NOT NULL DEFAULT '1900-01-01',
    end_date       DATE NOT NULL DEFAULT '9999-12-31',
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (start_date <= end_date)
);

CREATE INDEX settings_active_idx ON settings (start_date, end_date);

CREATE VIEW active_settings AS
SELECT * FROM settings
WHERE start_date <= CURRENT_DATE AND CURRENT_DATE <= end_date;

-- =============================================================
-- 2. Ask AI — RAG CONTENT (VECTOR STORE)
-- =============================================================
CREATE TABLE site_content (
    id              BIGSERIAL PRIMARY KEY,
    locale          VARCHAR(15) NOT NULL,
    scope           VARCHAR(20) NOT NULL DEFAULT 'public' 
                    CHECK (scope IN ('public', 'internal')),
    section_path    TEXT,
    source          TEXT NOT NULL,
    chunk_text      TEXT NOT NULL,
    embedding       VECTOR(768),
    start_date      DATE NOT NULL DEFAULT '1900-01-01',
    end_date        DATE NOT NULL DEFAULT '9999-12-31',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- HNSW index for vector similarity search
CREATE INDEX ON site_content USING hnsw (embedding vector_cosine_ops);

-- B-Tree indexes for fast filtering
CREATE INDEX site_content_scope_idx ON site_content (scope);
CREATE INDEX site_content_section_idx ON site_content (section_path);
CREATE INDEX ON site_content (locale);

-- =============================================================
-- 3. Ask AI — RUNTIME LOG
-- =============================================================
CREATE TABLE ask_ai_log (
    ask_ai_log_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    submission_id   UUID NOT NULL UNIQUE,
    session_id      UUID,
    question        TEXT NOT NULL,
    answer          TEXT NOT NULL,
    locale          VARCHAR(5),
    ip_hash         TEXT,
    user_agent      TEXT,
    referer         TEXT,
    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT NOT NULL DEFAULT 'success'
                    CHECK (status IN ('success', 'db_error', 'embed_error', 'embed_error_quota', 'gen_error', 'unanswered', 'no_context', 'notified', 'resolved')),
    chunks_found    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX ask_ai_log_submitted_idx  ON ask_ai_log (submitted_at DESC);
CREATE INDEX ask_ai_log_locale_idx     ON ask_ai_log (locale, submitted_at DESC);
CREATE INDEX ask_ai_log_ip_hash_idx    ON ask_ai_log (ip_hash) WHERE ip_hash IS NOT NULL;
CREATE INDEX ask_ai_log_session_idx    ON ask_ai_log (session_id, submitted_at ASC);

-- =============================================================
-- 4. Ask AI Gap Analysis View
-- =============================================================
CREATE OR REPLACE VIEW v_ask_ai_gaps AS
SELECT 
    question,
    count(*) as times_asked,
    array_agg(DISTINCT status) as error_types,
    max(submitted_at) as last_asked
FROM ask_ai_log
WHERE status IN ('unanswered', 'no_context')
GROUP BY question
ORDER BY times_asked DESC;

COMMIT;