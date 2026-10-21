SELECT 
    c.relname AS table_name,
    a.attnum AS pos,
    a.attname AS column_name,
    format_type(a.atttypid, a.atttypmod) AS data_type,
    a.attnotnull AS not_null,
    pg_get_expr(d.adbin, d.adrelid) AS default_value
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE c.relname IN (
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
  AND n.nspname = 'public'
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;