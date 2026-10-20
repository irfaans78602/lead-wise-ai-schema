INSERT INTO site_content (
    id,
    locale,
    source,
    chunk_text,
    embedding,
    start_date,
    end_date,
    created_at
)
OVERRIDING SYSTEM VALUE
SELECT
    id,
    locale,
    source,
    chunk_text,
    embedding,
    start_date,
    end_date,
    created_at
FROM site_content_bck;