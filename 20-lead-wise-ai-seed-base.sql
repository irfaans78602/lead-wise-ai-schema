-- =============================================================
-- 20-lead-wise-ai-seed-base.sql
-- Base reference data for the LeadWise AI platform.
-- Run after 10-lead-wise-ai-schema.sql.
-- Run BEFORE 30/40/50 (pricing) and 60-lead-wise-ai-seed.sql.
-- Safe to re-run: all inserts and updates are idempotent.
--
-- Contents:
--   1.  languages
--   2.  currencies
--   3.  countries
--   4.  segments
--   5.  qualification_levels        (en, ar, es, fr, zh)
--   6.  messages                    (customer_status_labels, en/ar/es/fr/zh)
--   7.  messages                    (system prompts)
--   8.  settings                    (platform-wide constants)
--   9.  pricing_tiers               (4 industry tiers)
--  10.  pricing_segment_tiers       (23 segments mapped to a tier)
--
-- Languages carried: en, ar, es, fr, zh.
-- Currencies carried: ZAR, GBP, USD.
-- Countries carried:  ZA, GB, US.
--
-- Pricing model notes (rate values themselves live in 30/40/50):
--   - Per (tier, country) the pricing page shows a range for the
--     monthly base fee and for the per-lead fee. The rate card
--     confirms the exact figure within the range.
--   - Website setup is a one-time fee with four standard pages
--     included; additional pages are priced per page.
--   - Pilot pricing: 50% off website setup and 50% off the monthly
--     base fee for the first 6 months. Per-lead fees are not
--     discounted during pilot. Carried on clients.is_pilot and
--     clients.pilot_ends_on; percentages live in settings.
--
-- Global volume discount tiers live in 60-lead-wise-ai-seed.sql.
--
-- Placeholder syntax for outbound text: {N} resolves to the answer
-- of the question with question_id N, {N.M} to option M of question N
-- when chosen. {part} is the offending fragment supplied by validation.
-- =============================================================

BEGIN;

-- =============================================================
-- 1. Languages
--    The five languages the platform ships with.
-- =============================================================
INSERT INTO languages (code, name, native_name) VALUES
    ('en', 'English', 'English'),
    ('ar', 'Arabic',  'العربية'),
    ('es', 'Spanish', 'Español'),
    ('fr', 'French',  'Français'),
    ('zh', 'Chinese', '中文')
ON CONFLICT (code) DO NOTHING;

-- =============================================================
-- 2. Currencies
--    Only the three currencies billed today: ZAR, GBP, USD.
-- =============================================================
INSERT INTO currencies (code, name, symbol, minor_unit) VALUES
    ('ZAR', 'South African Rand', 'R', 2),
    ('USD', 'US Dollar',          '$', 2),
    ('GBP', 'British Pound',      '£', 2)
ON CONFLICT (code) DO NOTHING;

-- =============================================================
-- 3. Countries
--    ISO alpha-2 code, name, default_language_id, default_currency_id.
--    Country drives the rate card. Language drives content render.
--    Only the three countries we bill in today: ZA, GB, US.
-- =============================================================
INSERT INTO countries (code, name, default_language_id, default_currency_id)
SELECT v.code, v.name, l.language_id, c.currency_id
FROM (VALUES
    ('ZA', 'South Africa',   'en', 'ZAR'),
    ('GB', 'United Kingdom', 'en', 'GBP'),
    ('US', 'United States',  'en', 'USD')
) AS v(code, name, lang_code, curr_code)
JOIN languages  l ON l.code = v.lang_code
JOIN currencies c ON c.code = v.curr_code
ON CONFLICT (code) DO NOTHING;

-- =============================================================
-- 4. Segments
--    The 23 business-type segments. Platform-wide vocabulary,
--    identical across every country.
-- =============================================================
INSERT INTO segments (code, name) VALUES
    ('trades_home_services',    'Trades & Home Services'),
    ('beauty_personal_care',    'Beauty & Personal Care'),
    ('pet_services',            'Pet Services'),
    ('hospitality_bookings',    'Hospitality & Bookings'),
    ('fitness_coaching',        'Fitness & Coaching'),
    ('education_training',      'Education & Training'),
    ('professional_services',   'Professional Services'),
    ('automotive',              'Automotive'),
    ('retail_ecommerce',        'Retail & E-commerce'),
    ('health_wellness',         'Health & Wellness'),
    ('high_ticket_services',    'High-Ticket Services'),
    ('real_estate',             'Real Estate'),
    ('b2b_enterprise',          'B2B / Enterprise'),
    ('financial_services',      'Financial Services'),
    ('legal_services',          'Legal Services'),
    ('travel_tourism',          'Travel & Tourism'),
    ('logistics_transport',     'Logistics & Transport'),
    ('agriculture_farming',     'Agriculture & Farming'),
    ('events_entertainment',    'Events & Entertainment'),
    ('non_profit_ngo',          'Non-Profit / NGO'),
    ('franchise_groups',        'Franchise Groups'),
    ('saas_it',                 'SaaS, IT & Technology'),
    ('other_bespoke',           'Other / Bespoke')
ON CONFLICT (code) DO NOTHING;

-- =============================================================
-- 5. Qualification Levels
--    Four codes. One row per (level_code, language_id).
--    Languages carried: en, ar, es, fr, zh.
-- =============================================================
INSERT INTO qualification_levels (level_code, language_id, label)
SELECT v.level_code, l.language_id, v.label
FROM (VALUES
    -- English
    ('low',       'en', 'Low'),
    ('medium',    'en', 'Medium'),
    ('high',      'en', 'High'),
    ('very_high', 'en', 'Very High'),
    -- Arabic
    ('low',       'ar', 'منخفض'),
    ('medium',    'ar', 'متوسط'),
    ('high',      'ar', 'مرتفع'),
    ('very_high', 'ar', 'مرتفع جداً'),
    -- Spanish
    ('low',       'es', 'Bajo'),
    ('medium',    'es', 'Medio'),
    ('high',      'es', 'Alto'),
    ('very_high', 'es', 'Muy alto'),
    -- French
    ('low',       'fr', 'Faible'),
    ('medium',    'fr', 'Moyen'),
    ('high',      'fr', 'Élevé'),
    ('very_high', 'fr', 'Très élevé'),
    -- Chinese
    ('low',       'zh', '低'),
    ('medium',    'zh', '中'),
    ('high',      'zh', '高'),
    ('very_high', 'zh', '非常高')
) AS v(level_code, lang_code, label)
JOIN languages l ON l.code = v.lang_code
ON CONFLICT (level_code, language_id, start_date) DO NOTHING;

-- =============================================================
-- 6. Messages — customer_status_labels
--    Dashboard labels for customers.status and customer_statuses.status.
--    Outer JSONB key = language code (matches languages.code)
--    Inner JSONB key = status code (matches the CHECK on customers.status)
--    Languages carried: en, ar, es, fr, zh.
--
--    On conflict, the existing message_text is merged with the new
--    one, so re-running this seed is a no-op on an already-populated
--    row (the || operator keeps existing keys and overwrites matching
--    ones with identical values).
-- =============================================================
INSERT INTO messages (message_code, message_text, description)
VALUES (
    'customer_status_labels',
    '{
        "en": {
            "Pending":            "Pending",
            "Contacted":          "Contacted",
            "Qualified":          "Qualified",
            "Not-Qualified":      "Not-Qualified",
            "No-Response":        "No Response",
            "Bad-Contact":        "Bad Contact",
            "Duplicate":          "Duplicate",
            "Callback-Requested": "Callback Requested",
            "Withdrawn":          "Withdrawn",
            "Converted":          "Converted"
        },
        "ar": {
            "Pending":            "معلّق",
            "Contacted":          "تم التواصل",
            "Qualified":          "مؤهَّل",
            "Not-Qualified":      "غير مؤهَّل",
            "No-Response":        "لا يوجد رد",
            "Bad-Contact":        "بيانات اتصال خاطئة",
            "Duplicate":          "مكرَّر",
            "Callback-Requested": "طلب معاودة الاتصال",
            "Withdrawn":          "منسحب",
            "Converted":          "مُحوَّل"
        },
        "es": {
            "Pending":            "Pendiente",
            "Contacted":          "Contactado",
            "Qualified":          "Cualificado",
            "Not-Qualified":      "No cualificado",
            "No-Response":        "Sin respuesta",
            "Bad-Contact":        "Contacto incorrecto",
            "Duplicate":          "Duplicado",
            "Callback-Requested": "Solicitud de devolución de llamada",
            "Withdrawn":          "Retirado",
            "Converted":          "Convertido"
        },
        "fr": {
            "Pending":            "En attente",
            "Contacted":          "Contacté",
            "Qualified":          "Qualifié",
            "Not-Qualified":      "Non qualifié",
            "No-Response":        "Sans réponse",
            "Bad-Contact":        "Coordonnées erronées",
            "Duplicate":          "Doublon",
            "Callback-Requested": "Rappel demandé",
            "Withdrawn":          "Retiré",
            "Converted":          "Converti"
        },
        "zh": {
            "Pending":            "待处理",
            "Contacted":          "已联系",
            "Qualified":          "已合格",
            "Not-Qualified":      "未合格",
            "No-Response":        "无回复",
            "Bad-Contact":        "联系方式错误",
            "Duplicate":          "重复",
            "Callback-Requested": "请求回电",
            "Withdrawn":          "已撤回",
            "Converted":          "已转化"
        }
    }'::jsonb,
    'Dashboard labels for customers.status and customer_statuses.status, keyed by language code then status code.'
)
ON CONFLICT (message_code) DO UPDATE
SET message_text = messages.message_text || EXCLUDED.message_text,
    description  = EXCLUDED.description;

-- =============================================================
-- 7. Messages — system prompts
--    message_text is JSONB keyed by language code. One row per
--    message_code.
--
--    Most rows are English-only. The default_* fallbacks carry all
--    five languages because they render directly to the prospect:
--      default_confirmation         — ad has no ad_confirmations row
--      default_closed               — client has no client_messages row
--      default_reopen_prompt        — ad has no ad_reopen_prompts row
--      default_reopen_button_title
--      default_forward_button_title
-- =============================================================
INSERT INTO messages (message_code, message_text, description) VALUES
    ('rate_limit',
     '{"en": "I''m having trouble understanding your responses. Let''s pause this conversation for now — feel free to try again later, or contact us directly."}'::jsonb,
     'Sent when a conversation hits the invalid-answer cap'),

    ('invalid_phone',
     '{"en": "That doesn''t look like a valid phone number. Please include your country code, e.g. +27821234567."}'::jsonb,
     'Sent when a phone number answer fails validation'),

    ('invalid_email',
     '{"en": "That doesn''t look like a valid email address, e.g. name@example.com."}'::jsonb,
     'Sent when an email answer fails validation'),

    ('empty_answer',
     '{"en": "Sorry, I didn''t catch that — could you answer again?"}'::jsonb,
     'Sent when a mandatory question receives a blank reply'),

    ('radio_invalid',
     '{"en": "Please choose one of the options below."}'::jsonb,
     'Sent when a radio/dropdown_single answer doesn''t match any option'),

    ('dropdown_multi_invalid',
     '{"en": "I didn''t recognise ''{part}''. Please choose from the options below."}'::jsonb,
     'Sent when one part of a dropdown_multi answer doesn''t match any option'),

    ('unsupported_type',
     '{"en": "Unsupported question type."}'::jsonb,
     'Sent when a faq row has a question_type the engine doesn''t understand'),

    ('suggest_phone',
     '{"en": "Did you mean {part}? If so, please reply with exactly that number."}'::jsonb,
     'Sent when the AI suggests a corrected phone number'),

    ('suggest_email',
     '{"en": "Did you mean {part}? If so, please reply with exactly that address."}'::jsonb,
     'Sent when the AI suggests a corrected email address'),

    ('default_confirmation',
     '{
        "en": "Thank you {10}! That''s everything we need — our team will be in touch shortly.",
        "ar": "شكراً لك {10}! هذا كل ما نحتاجه — سيتواصل معك فريقنا قريباً.",
        "es": "¡Gracias, {10}! Eso es todo lo que necesitamos — nuestro equipo se pondrá en contacto pronto.",
        "fr": "Merci {10} ! C''est tout ce dont nous avons besoin — notre équipe vous contactera bientôt.",
        "zh": "谢谢您，{10}！我们需要的信息已经齐全——我们的团队会尽快与您联系。"
     }'::jsonb,
     'Fallback confirmation sent when an ad has no ad_confirmations row'),

    ('default_closed',
     '{"en": "Thank you for your message. This business is no longer accepting enquiries. We wish you well."}'::jsonb,
     'Fallback closed message sent when a client has no client_messages row'),

    ('default_reopen_prompt',
     '{
        "en": "Thanks for reaching out again, {10}. Your previous enquiry is with our team. Would you like to start a new enquiry?",
        "ar": "شكراً لتواصلك مرة أخرى، {10}. استفسارك السابق قيد المعالجة من قبل فريقنا. هل ترغب في بدء استفسار جديد؟",
        "es": "Gracias por contactarnos de nuevo, {10}. Su consulta anterior está con nuestro equipo. ¿Le gustaría iniciar una nueva consulta?",
        "fr": "Merci de nous avoir recontactés, {10}. Votre demande précédente est entre les mains de notre équipe. Souhaitez-vous commencer une nouvelle demande ?",
        "zh": "感谢您再次联系我们，{10}。您之前的咨询已由我们的团队处理。您想开始新的咨询吗？"
     }'::jsonb,
     'Fallback reopen prompt body, when an ad has no ad_reopen_prompts row'),

    ('default_reopen_button_title',
     '{
        "en": "Yes, start fresh",
        "ar": "نعم، ابدأ من جديد",
        "es": "Sí, empezar de nuevo",
        "fr": "Oui, recommencer",
        "zh": "是的，重新开始"
     }'::jsonb,
     'Fallback label for the reopen button'),

    ('default_forward_button_title',
     '{
        "en": "No, just pass this on",
        "ar": "لا، فقط مرّر هذا",
        "es": "No, solo reenvíelo",
        "fr": "Non, transmettez simplement",
        "zh": "不，只是转达一下"
     }'::jsonb,
     'Fallback label for the forward button')
ON CONFLICT (message_code) DO NOTHING;

-- =============================================================
-- 8. Settings
--    Platform-wide constants read by db.py::get_setting_*().
--    Values are NUMERIC(10,4); setting_type is informational.
-- =============================================================
INSERT INTO settings (setting_key, setting_value, setting_type, description) VALUES
    ('agency_discount_pct',       20.0000,  'number',  'Wholesale discount for agencies'),
    ('bundle_bots_seo_pct',       10.0000,  'number',  'Bundle discount: Bots + SEO'),
    ('bundle_bots_seo_ads_pct',   15.0000,  'number',  'Bundle discount: Bots + SEO + Ads'),
    ('bundle_bots_seo_wp_pct',    15.0000,  'number',  'Bundle discount: Bots + SEO + WordPress'),
    ('bundle_full_stack_pct',     20.0000,  'number',  'Bundle discount: all four services'),
    ('pilot_setup_discount_pct', 100.0000,  'number',  'Pilot: setup fee waived'),
    ('pilot_base_discount_pct',   50.0000,  'number',  'Pilot: base fee halved'),
    ('pilot_duration_months',      6.0000,  'number',  'Pilot pricing duration in months'),
    ('max_invalid_answers',        5.0000,  'integer', 'Consecutive invalid answers before rate-limiting'),
    ('rate_limit_cooldown_hours', 24.0000,  'number',  'Cool-down duration after rate limiting'),
    ('rate_limit_window_seconds_1', 60.0000,   'number', 'First rate-limit window (seconds)'),
    ('rate_limit_max_1',             10.0000,  'number', 'Max messages in window 1'),
    ('rate_limit_window_seconds_2', 3600.0000, 'number', 'Second rate-limit window (seconds)'),
    ('rate_limit_max_2',             60.0000,  'number', 'Max messages in window 2'),
    ('rate_limit_window_seconds_3', 86400.0000,'number', 'Third rate-limit window (seconds)'),
    ('rate_limit_max_3',            200.0000,  'number', 'Max messages in window 3'),
    ('rate_limit_cleanup_hours',     48.0000,  'number', 'Prune rate-limit rows older than this')
ON CONFLICT (setting_key) DO NOTHING;

-- =============================================================
-- 9. Pricing Tiers
--    Four industry tiers. Platform-wide, not currency-specific.
--    Every segment maps to exactly one tier (see section 10).
-- =============================================================
INSERT INTO pricing_tiers (tier_code, tier_name, tier_order, description) VALUES
    ('standard',     'Standard',     1, 'Trades, beauty, pet, non-profit, hospitality, fitness'),
    ('professional', 'Professional', 2, 'Education, professional services, retail, travel'),
    ('high_value',   'High-Value',   3, 'Automotive, health, high-ticket, logistics, agriculture, events, other'),
    ('premium',      'Premium',      4, 'Real estate, B2B, financial, legal, franchise, SaaS')
ON CONFLICT (tier_code) DO NOTHING;

-- =============================================================
-- 10. Pricing Segment Tiers
--     Maps each of the 23 segments to exactly one tier.
--     Currencies add pricing_rates rows against these tiers
--     in the 30/40/50 pricing seeds.
-- =============================================================
INSERT INTO pricing_segment_tiers (segment_id, tier_id)
SELECT s.segment_id, t.tier_id
FROM (VALUES
    -- Tier 1 Standard
    ('trades_home_services',  'standard'),
    ('beauty_personal_care',  'standard'),
    ('pet_services',          'standard'),
    ('non_profit_ngo',        'standard'),
    ('hospitality_bookings',  'standard'),
    ('fitness_coaching',      'standard'),
    -- Tier 2 Professional
    ('education_training',    'professional'),
    ('professional_services', 'professional'),
    ('retail_ecommerce',      'professional'),
    ('travel_tourism',        'professional'),
    -- Tier 3 High-Value
    ('automotive',            'high_value'),
    ('health_wellness',       'high_value'),
    ('high_ticket_services',  'high_value'),
    ('events_entertainment',  'high_value'),
    ('other_bespoke',         'high_value'),
    ('logistics_transport',   'high_value'),
    ('agriculture_farming',   'high_value'),
    -- Tier 4 Premium
    ('real_estate',           'premium'),
    ('b2b_enterprise',        'premium'),
    ('financial_services',    'premium'),
    ('legal_services',        'premium'),
    ('saas_it',               'premium'),
    ('franchise_groups',      'premium')
) AS v(segment_code, tier_code)
JOIN segments      s ON s.code = v.segment_code
JOIN pricing_tiers t ON t.tier_code = v.tier_code
ON CONFLICT (segment_id, start_date) DO NOTHING;

COMMIT;