-- =============================================================
-- 20-master-seed.sql
-- Seeds LeadWise AI as the first client and its instances.
-- =============================================================

BEGIN;

-- 1. Insert the Client (LeadWise AI)
INSERT INTO clients (
    client_id, 
    client_name, 
    admin_email, 
    allowed_origins,
    status
)
VALUES (
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'LeadWise AI', 
    'irfaan.sulaiman786.biz@gmail.com',
    'https://lead-wise-ai.com,https://www.lead-wise-ai.com',
    'active'
)
ON CONFLICT (client_id) DO NOTHING;

-- 2. Insert the Public Instance (Ask AI)
INSERT INTO instances (
    instance_id, 
    client_id, 
    instance_type
)
VALUES (
    'fa85f874-57b5-571e-8141-a62de8d70d46', 
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'public' 
)
ON CONFLICT (instance_id) DO NOTHING;

-- 3. Insert the Internal Instance (Staff Assistant)
INSERT INTO instances (
    instance_id, 
    client_id, 
    instance_type
)
VALUES (
    '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d', 
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'internal'
)
ON CONFLICT (instance_id) DO NOTHING;

COMMIT;