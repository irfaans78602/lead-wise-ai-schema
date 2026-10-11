-- =============================================================
-- 70-lead-wise-ai-seed-post.sql
-- Post-seed adjustments for LeadWise AI.
-- Run after 60-lead-wise-ai-seed.sql.
--
-- Purpose: replace the placeholder WhatsApp identifiers created
-- in the 60-seed with the real values from Meta Business Suite.
--
-- This file is a template. Replace the two placeholder strings
-- below before running:
--   <real phone_number_id>       e.g. 123456789012345
--   <+27749397862>               e.g. +27821234567
--
-- Safe to re-run: all steps are idempotent.
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- 1. Add the real phone_number_id as a new entry, carrying
--    the same client_id as the placeholder.
-- -------------------------------------------------------------
INSERT INTO client_whatsapps (phone_number_id, client_id, display_phone_number)
SELECT
    '+27749397862',
    cw.client_id,
    '+27749397862'
FROM client_whatsapps cw
WHERE cw.phone_number_id = 'LEADWISE_PHONE_NUMBER_ID'
ON CONFLICT (phone_number_id) DO NOTHING;

-- -------------------------------------------------------------
-- 2. Repoint any ads that referenced the placeholder at the
--    new entry. Must happen BEFORE the placeholder is deleted,
--    otherwise the FK would cascade to NULL.
-- -------------------------------------------------------------
UPDATE ads
SET whatsapp_number_id = '+27749397862'
WHERE whatsapp_number_id = 'LEADWISE_PHONE_NUMBER_ID';

-- -------------------------------------------------------------
-- 3. Remove the placeholder.
-- -------------------------------------------------------------
DELETE FROM client_whatsapps
WHERE phone_number_id = 'LEADWISE_PHONE_NUMBER_ID';

COMMIT;