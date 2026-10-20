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
    gemini_api_key, 
    allowed_origins,
    status
)
VALUES (
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'LeadWise AI', 
    'irfaan.sulaiman786.biz@gmail.com',
    'AQ.Ab8RN6Jea7hE41litk_C7yPFd4Z29YBS1hkENxliHT8YDHejbA', 
    'https://lead-wise-ai.com,https://www.lead-wise-ai.com',
    'active'
)
ON CONFLICT (client_id) DO NOTHING;

-- 2. Insert the Public Instance (Website Chat)
-- Using the leaf_ad_id from your 60-instance.json as the instance_id
INSERT INTO instances (
    instance_id, 
    client_id, 
    instance_type, 
    db_connect_string
)
VALUES (
    'fa85f874-57b5-571e-8141-a62de8d70d46', 
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'public', 
    'postgresql://neondb_owner:password@ep-xyz-pooler.us-east-2.aws.neon.tech/lead_wise_ai_public?sslmode=require'
)
ON CONFLICT (instance_id) DO NOTHING;

-- 3. Insert the Internal Instance (Staff Assistant)
-- Using a new dummy UUID for the internal bot
INSERT INTO instances (
    instance_id, 
    client_id, 
    instance_type, 
    db_connect_string
)
VALUES (
    '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d', 
    '35d69a44-9649-5556-81a0-251ab6dc537b', 
    'internal', 
    'postgresql://neondb_owner:password@ep-xyz-pooler.us-east-2.aws.neon.tech/lead_wise_ai_internal?sslmode=require'
)
ON CONFLICT (instance_id) DO NOTHING;

COMMIT;