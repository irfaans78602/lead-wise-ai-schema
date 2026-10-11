-- =============================================================
-- 90-lead-wise-ai-clean-up.sql
-- Purge demo customers idle for more than 72 hours.
--
-- RUN AGAINST THE DEMO DATABASE ONLY.
-- The demo runs against a separate Neon database (Decision 18),
-- branched from production. This script deletes every customer
-- idle past the window, with no flag distinguishing demo rows
-- from live rows. It must never be connected to the production
-- database. The separation is the guard.
--
-- Cascades automatically to:
--   conversations     (ON DELETE CASCADE via customer_id)
--   answers           (ON DELETE CASCADE via conversation_id)
--   qualifications    (ON DELETE CASCADE via customer_id)
--   customer_statuses (ON DELETE CASCADE via customer_id)
--
-- Uses customers.updated_at (maintained by the set_updated_at trigger)
-- and customers.created_at, whichever is later.
--
-- Safe to re-run. Idempotent. No hard-coded IDs.
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- 1. Preview: how many rows will be affected
-- -------------------------------------------------------------
SELECT
    'before' AS phase,
    COUNT(*) FILTER (WHERE GREATEST(c.created_at, c.updated_at)
                       < NOW() - INTERVAL '72 hours') AS customers_to_delete,
    (SELECT COUNT(*) FROM conversations conv
       JOIN customers c2 ON c2.customer_id = conv.customer_id
      WHERE GREATEST(c2.created_at, c2.updated_at) < NOW() - INTERVAL '72 hours') AS conversations_to_delete,
    (SELECT COUNT(*) FROM answers a
       JOIN conversations conv ON conv.conversation_id = a.conversation_id
       JOIN customers c3 ON c3.customer_id = conv.customer_id
      WHERE GREATEST(c3.created_at, c3.updated_at) < NOW() - INTERVAL '72 hours') AS answers_to_delete,
    (SELECT COUNT(*) FROM qualifications q
       JOIN customers c4 ON c4.customer_id = q.customer_id
      WHERE GREATEST(c4.created_at, c4.updated_at) < NOW() - INTERVAL '72 hours') AS qualifications_to_delete,
    (SELECT COUNT(*) FROM customer_statuses cs
       JOIN customers c5 ON c5.customer_id = cs.customer_id
      WHERE GREATEST(c5.created_at, c5.updated_at) < NOW() - INTERVAL '72 hours') AS customer_statuses_to_delete
FROM customers c;

-- -------------------------------------------------------------
-- 2. The delete (cascades handle every dependent table)
-- -------------------------------------------------------------
WITH deleted AS (
    DELETE FROM customers
    WHERE GREATEST(created_at, updated_at) < NOW() - INTERVAL '72 hours'
    RETURNING customer_id
)
SELECT COUNT(*) AS customers_deleted FROM deleted;

-- -------------------------------------------------------------
-- 3. Post-check: confirm the cascades actually happened
--    All four counts must be zero on a clean run.
-- -------------------------------------------------------------
SELECT
    'after' AS phase,
    (SELECT COUNT(*) FROM customers
      WHERE GREATEST(created_at, updated_at) < NOW() - INTERVAL '72 hours') AS customers_remaining,
    (SELECT COUNT(*) FROM conversations conv
       LEFT JOIN customers c ON c.customer_id = conv.customer_id
      WHERE c.customer_id IS NULL) AS orphaned_conversations,
    (SELECT COUNT(*) FROM answers a
       LEFT JOIN conversations conv ON conv.conversation_id = a.conversation_id
      WHERE conv.conversation_id IS NULL) AS orphaned_answers,
    (SELECT COUNT(*) FROM qualifications q
       LEFT JOIN customers c ON c.customer_id = q.customer_id
      WHERE c.customer_id IS NULL) AS orphaned_qualifications,
    (SELECT COUNT(*) FROM customer_statuses cs
       LEFT JOIN customers c ON c.customer_id = cs.customer_id
      WHERE c.customer_id IS NULL) AS orphaned_customer_statuses;

COMMIT;