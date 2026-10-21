SELECT 
    t.relname AS table_name,
    a.attname AS column_name
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
-- Unnest the array of column numbers stored in the constraint
CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS u(attnum, ord)
-- Look up the actual name of the column
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = u.attnum
WHERE n.nspname = 'public'
  AND t.relname IN (
      'clients',
      'client_messages',
      'client_users',
      'ad_confirmations',
      'ad_reopen_prompts',
      'ads',
      'faqs',
      'pricing_discounts',
      'qualification_score'
  )
  AND c.contype = 'p'
ORDER BY t.relname, u.ord;