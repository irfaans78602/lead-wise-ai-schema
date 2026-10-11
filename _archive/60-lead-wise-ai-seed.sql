-- =============================================================
-- 60-lead-wise-ai-seed.sql
-- Instance data for LeadWise AI: the platform owner client, its
-- channel identifiers, the canonical ad set with its questions,
-- and the global volume discount tiers.
-- Run after:
--   20-lead-wise-ai-seed-base.sql       (languages, currencies,
--                                        countries, segments,
--                                        qualification_levels,
--                                        messages, settings)
--   30-lead-wise-ai-seed-pricing-zar.sql
--   40-lead-wise-ai-seed-pricing-gbp.sql
--   50-lead-wise-ai-seed-pricing-usd.sql
-- Safe to re-run: all inserts are idempotent.
--
-- Contents:
--   1.  Client                (LeadWise AI (Pty) Ltd — is_platform_owner = TRUE)
--   2.  client_messages       (English closed message)
--   3.  client_whatsapps      (TODO placeholders — replace with real values)
--   4.  Ads                   (web root + 4 channel leaves + 4 language leaves)
--   5.  ad_confirmations      (en/ar/es/fr/zh on the root ad)
--   6.  ad_reopen_prompts     (en/ar/es/fr/zh on the root ad)
--   7.  FAQs                  (8 canonical questions, en/ar/es/fr/zh)
--   8.  qualification_score   (4 bands, level_code only)
--   9.  pricing_discounts     (global volume tiers)
--
-- Placeholder syntax for outbound text: {N} resolves to the answer
-- of the question with question_id N, {N.M} to option M of question N
-- when chosen. {part} is the offending fragment supplied by validation.
--
-- Languages carried in this seed: en, ar, es, fr, zh.
-- Arabic is RTL; rendering layers should set dir="rtl" for ar.
-- =============================================================

BEGIN;

-- =============================================================
-- 1. Client — LeadWise AI itself (the platform owner).
--    is_platform_owner = TRUE. Segment `saas_it`, country ZA,
--    currency ZAR, language English. Never billed.
-- =============================================================
INSERT INTO clients (client_id, name, email_to, country_id, segment_id, currency_id, language_id, is_platform_owner)
SELECT
    'a5c7e9b1-2d4f-4a6c-9e0b-1c3d5f7a9b2e'::uuid,
    'LeadWise AI (Pty) Ltd',
    'irfaan.sulaiman786.biz@gmail.com',
    (SELECT country_id   FROM countries  WHERE code = 'ZA'),
    (SELECT segment_id   FROM segments   WHERE code = 'saas_it'),
    (SELECT currency_id  FROM currencies WHERE code = 'ZAR'),
    (SELECT language_id  FROM languages  WHERE code = 'en'),
    TRUE
WHERE NOT EXISTS (SELECT 1 FROM clients WHERE is_platform_owner = TRUE);

-- =============================================================
-- 2. Client Messages — English closed message.
--    VERSIONED: PK is client_message_version_id (UUID).
--    Logical key: client_id.
-- =============================================================
INSERT INTO client_messages (client_message_version_id, client_id, message_text)
SELECT
    'b6d8f0a2-3e5c-4b7d-8f9a-0c2e4d6f8a1b'::uuid,
    c.client_id,
    '{"en": "Thank you for your message. This business is no longer accepting enquiries. We wish you well."}'::jsonb
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (client_message_version_id) DO NOTHING;

-- =============================================================
-- 3. Client Whatsapps — LeadWise AI's own WhatsApp number.
--    NOT VERSIONED. phone_number_id is the PK (Meta's identifier).
--    TODO: replace the placeholders with the real values from
--    Meta Business Suite once the number is registered.
-- =============================================================
INSERT INTO client_whatsapps (phone_number_id, client_id, display_phone_number)
SELECT
    'LEADWISE_PHONE_NUMBER_ID',
    c.client_id,
    '+27000000000'
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (phone_number_id) DO NOTHING;

-- =============================================================
-- 4. Ads — one root ad + channel leaves + language leaves.
--    NOT VERSIONED. ad_id is the PK, supplied by the seed.
--    The root owns all content. Leaves point at it via reuse_ad_id.
--    Leaf.language_id picks which JSONB key to render.
--
--    UUIDs are fixed per ad so re-runs upsert the same rows.
--    They are derived as uuid5(namespace, "ad:<source_ad_id>"),
--    so the loader can reproduce them.
-- =============================================================

-- 4a. Root ad — canonical web, English.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id)
SELECT
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    'leadwise-web',
    c.client_id,
    'LeadWise AI - Web',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'en')
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4b. WhatsApp leaf — reuses the root's content.
INSERT INTO ads (ad_id, source_ad_id, client_id, whatsapp_number_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'd2b3c4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'::uuid,
    'leadwise-wa',
    c.client_id,
    'LEADWISE_PHONE_NUMBER_ID',
    'LeadWise AI - WhatsApp',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'en'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4c. Messenger leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'e3c4d5f6-a7b8-4c9d-8e1f-2a3b4c5d6e7f'::uuid,
    'leadwise-messenger',
    c.client_id,
    'LeadWise AI - Messenger',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'en'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4d. Instagram leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'f4d5e6a7-b8c9-4d0e-9f1a-2b3c4d5e6f7a'::uuid,
    'leadwise-instagram',
    c.client_id,
    'LeadWise AI - Instagram',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'en'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4e. TikTok leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'a5e6f7b8-c9d0-4e1f-8a2b-3c4d5e6f7a8b'::uuid,
    'leadwise-tiktok',
    c.client_id,
    'LeadWise AI - TikTok',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'en'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4f–4i. Language-variant leaves on the canonical web ad.
--        Each renders the same questions, options, confirmation,
--        and reopen prompt in its language. Owns no content.
--        Arabic (ar) is RTL — rendering layer must set dir="rtl".

-- 4f. Arabic leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'b6f7a8c9-d0e1-4f2a-9b3c-4d5e6f7a8b9c'::uuid,
    'leadwise-web-ar',
    c.client_id,
    'LeadWise AI - Web (ar)',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'ar'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4g. Spanish leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'c7a8b9d0-e1f2-4a3b-8c4d-5e6f7a8b9c0d'::uuid,
    'leadwise-web-es',
    c.client_id,
    'LeadWise AI - Web (es)',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'es'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4h. French leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'd8b9c0e1-f2a3-4b4c-9d5e-6f7a8b9c0d1e'::uuid,
    'leadwise-web-fr',
    c.client_id,
    'LeadWise AI - Web (fr)',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'fr'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- 4i. Chinese leaf.
INSERT INTO ads (ad_id, source_ad_id, client_id, ad_name, is_placeholder, language_id, reuse_ad_id)
SELECT
    'e9c0d1f2-a3b4-4c5d-8e6f-7a8b9c0d1e2f'::uuid,
    'leadwise-web-zh',
    c.client_id,
    'LeadWise AI - Web (zh)',
    TRUE,
    (SELECT language_id FROM languages WHERE code = 'zh'),
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid
FROM clients c
WHERE c.is_platform_owner = TRUE
ON CONFLICT (ad_id) DO NOTHING;

-- =============================================================
-- 5. Ad Confirmation — en/ar/es/fr/zh on the root ad.
--    VERSIONED: PK is ad_confirmation_version_id (UUID).
--    Logical key: ad_id. Root-only.
--    {10} resolves to the answer of the first_name question.
-- =============================================================
INSERT INTO ad_confirmations (ad_confirmation_version_id, ad_id, message_text)
SELECT
    'f0d1e2a3-b4c5-4d6e-9f7a-8b9c0d1e2f3a'::uuid,
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    '{
        "en": "Thank you {10}! That''s everything we need — our team will be in touch shortly.",
        "ar": "شكراً لك {10}! هذا كل ما نحتاجه — سيتواصل معك فريقنا قريباً.",
        "es": "¡Gracias, {10}! Eso es todo lo que necesitamos — nuestro equipo se pondrá en contacto pronto.",
        "fr": "Merci {10} ! C''est tout ce dont nous avons besoin — notre équipe vous contactera bientôt.",
        "zh": "谢谢您，{10}！我们需要的信息已经齐全——我们的团队会尽快与您联系。"
    }'::jsonb
ON CONFLICT (ad_confirmation_version_id) DO NOTHING;

-- =============================================================
-- 6. Ad Reopen Prompt — en/ar/es/fr/zh on the root ad.
--    VERSIONED: PK is ad_reopen_prompt_version_id (UUID).
--    Logical key: ad_id. Root-only.
--    All three content columns are JSONB keyed by language code.
--    {10} resolves to the answer of the first_name question.
-- =============================================================
INSERT INTO ad_reopen_prompts
    (ad_reopen_prompt_version_id, ad_id,
     prompt_text, reopen_button_title, forward_button_title)
SELECT
    'a1e2f3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b'::uuid,
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    '{
        "en": "Thanks for reaching out again, {10}. Your previous enquiry is with our team. Would you like to start a new enquiry?",
        "ar": "شكراً لتواصلك مرة أخرى، {10}. استفسارك السابق قيد المعالجة من قبل فريقنا. هل ترغب في بدء استفسار جديد؟",
        "es": "Gracias por contactarnos de nuevo, {10}. Su consulta anterior está con nuestro equipo. ¿Le gustaría iniciar una nueva consulta?",
        "fr": "Merci de nous avoir recontactés, {10}. Votre demande précédente est entre les mains de notre équipe. Souhaitez-vous commencer une nouvelle demande ?",
        "zh": "感谢您再次联系我们，{10}。您之前的咨询已由我们的团队处理。您想开始新的咨询吗？"
    }'::jsonb,
    '{
        "en": "Yes, start fresh",
        "ar": "نعم، ابدأ من جديد",
        "es": "Sí, empezar de nuevo",
        "fr": "Oui, recommencer",
        "zh": "是的，重新开始"
    }'::jsonb,
    '{
        "en": "No, just pass this on",
        "ar": "لا، فقط مرّر هذا",
        "es": "No, solo reenvíelo",
        "fr": "Non, transmettez simplement",
        "zh": "不，只是转达一下"
    }'::jsonb
ON CONFLICT (ad_reopen_prompt_version_id) DO NOTHING;

-- =============================================================
-- 7. FAQs — 8 canonical questions on the root ad.
--    VERSIONED: PK is faq_version_id (UUID).
--    Logical key: (ad_id, question_id). Root-only.
--    question_id is unique per ad, multiples of 10.
--    question_text is JSONB keyed by language code.
--    options is a JSONB array. Each option:
--      { "id": int, "score": int, "en": "...", "ar": "...",
--        "es": "...", "fr": "...", "zh": "..." }
--    Option ids and scores are language-independent.
--
--    The version UUIDs are fixed per (ad_id, question_id) so
--    re-runs upsert the same rows. Derivation:
--      uuid5(namespace, "faq:<ad_id>:<question_id>")
-- =============================================================
INSERT INTO faqs (faq_version_id, ad_id, question_id, question_order, question_text, question_type, options, mandatory)
SELECT
    q.faq_version_id::uuid,
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    q.question_id,
    q.question_order,
    q.question_text,
    q.question_type,
    q.options,
    q.mandatory
FROM (VALUES
    ('b2f3a4c5-d6e7-4f8a-9b0c-1d2e3f4a5b6c',
     10, 1,
     '{
        "en": "Hello! Thanks for reaching out to LeadWise AI. May I have your first name, please?",
        "ar": "مرحباً! شكراً لتواصلك مع LeadWise AI. هل يمكنني الحصول على اسمك الأول من فضلك؟",
        "es": "¡Hola! Gracias por contactar a LeadWise AI. ¿Me podría dar su nombre, por favor?",
        "fr": "Bonjour ! Merci d''avoir contacté LeadWise AI. Puis-je avoir votre prénom, s''il vous plaît ?",
        "zh": "您好！感谢您联系 LeadWise AI。请问可以告诉我您的名字吗？"
     }'::jsonb,
     'first_name',
     NULL::jsonb,
     TRUE),

    ('c3a4b5d6-e7f8-4a9b-8c1d-2e3f4a5b6c7d',
     20, 2,
     '{
        "en": "May I have your last name, please?",
        "ar": "هل يمكنني الحصول على اسم عائلتك من فضلك؟",
        "es": "¿Me podría dar su apellido, por favor?",
        "fr": "Puis-je avoir votre nom de famille, s''il vous plaît ?",
        "zh": "请问可以告诉我您的姓氏吗？"
     }'::jsonb,
     'last_name',
     NULL::jsonb,
     TRUE),

    ('d4b5c6e7-f8a9-4b0c-9d1e-3f4a5b6c7d8e',
     30, 3,
     '{
        "en": "Great to meet you, {10}. What''s the best phone number to reach you on, including country code?",
        "ar": "تشرفنا بلقائك، {10}. ما هو أفضل رقم هاتف للتواصل معك عليه، مع رمز الدولة؟",
        "es": "Un placer conocerle, {10}. ¿Cuál es el mejor número de teléfono para contactarle, incluyendo el código de país?",
        "fr": "Enchanté, {10}. Quel est le meilleur numéro de téléphone pour vous joindre, indicatif pays inclus ?",
        "zh": "很高兴认识您，{10}。能联系到您的最佳电话号码是多少？请包含国家代码。"
     }'::jsonb,
     'phone_number',
     NULL::jsonb,
     TRUE),

    ('e5c6d7f8-a9b0-4c1d-8e2f-4a5b6c7d8e9f',
     40, 4,
     '{
        "en": "And what''s your email address?",
        "ar": "وما هو بريدك الإلكتروني؟",
        "es": "¿Y cuál es su dirección de correo electrónico?",
        "fr": "Et quelle est votre adresse e-mail ?",
        "zh": "您的电子邮箱地址是什么？"
     }'::jsonb,
     'email_address',
     NULL::jsonb,
     TRUE),

    ('f6d7e8a9-b0c1-4d2e-9f3a-5b6c7d8e9f0a',
     50, 5,
     '{
        "en": "What''s your company or business name?",
        "ar": "ما هو اسم شركتك أو نشاطك التجاري؟",
        "es": "¿Cuál es el nombre de su empresa o negocio?",
        "fr": "Quel est le nom de votre entreprise ou société ?",
        "zh": "您的公司或企业名称是什么？"
     }'::jsonb,
     'business_name',
     NULL::jsonb,
     FALSE),

    ('a7e8f9b0-c1d2-4e3f-8a4b-6c7d8e9f0a1b',
     60, 6,
     '{
        "en": "Which of our services are you interested in?",
        "ar": "بأي من خدماتنا أنت مهتم؟",
        "es": "¿En cuál de nuestros servicios está interesado?",
        "fr": "Quels sont les services qui vous intéressent ?",
        "zh": "您对我们的哪些服务感兴趣？"
     }'::jsonb,
     'dropdown_multi',
     '[
        {"id":10,"score":30,
         "en":"Lead Generation",
         "ar":"توليد العملاء المحتملين",
         "es":"Generación de leads",
         "fr":"Génération de leads",
         "zh":"潜在客户开发"},
        {"id":20,"score":20,
         "en":"SEO",
         "ar":"تحسين محركات البحث",
         "es":"SEO",
         "fr":"SEO",
         "zh":"搜索引擎优化（SEO）"},
        {"id":30,"score":15,
         "en":"WordPress Development",
         "ar":"تطوير ووردبريس",
         "es":"Desarrollo WordPress",
         "fr":"Développement WordPress",
         "zh":"WordPress 开发"},
        {"id":40,"score":30,
         "en":"Ads Management",
         "ar":"إدارة الإعلانات",
         "es":"Gestión de anuncios",
         "fr":"Gestion des publicités",
         "zh":"广告管理"}
     ]'::jsonb,
     TRUE),

    ('b8f9a0c1-d2e3-4f4a-9b5c-7d8e9f0a1b2c',
     70, 7,
     '{
        "en": "What budget range are you working with for this project?",
        "ar": "ما هي الميزانية التي تعمل بها لهذا المشروع؟",
        "es": "¿Con qué rango de presupuesto está trabajando para este proyecto?",
        "fr": "Quel budget envisagez-vous pour ce projet ?",
        "zh": "您为这个项目准备的预算范围是多少？"
     }'::jsonb,
     'radio',
     '[
        {"id":10,"score":10,
         "en":"Small",
         "ar":"صغير",
         "es":"Pequeño",
         "fr":"Petit",
         "zh":"小型"},
        {"id":20,"score":25,
         "en":"Medium",
         "ar":"متوسط",
         "es":"Medio",
         "fr":"Moyen",
         "zh":"中型"},
        {"id":30,"score":40,
         "en":"Large",
         "ar":"كبير",
         "es":"Grande",
         "fr":"Grand",
         "zh":"大型"},
        {"id":40,"score":5,
         "en":"Not sure yet",
         "ar":"لست متأكداً بعد",
         "es":"Aún no estoy seguro",
         "fr":"Pas encore sûr",
         "zh":"还不确定"}
     ]'::jsonb,
     TRUE),

    ('c9a0b1d2-e3f4-4a5b-8c6d-8e9f0a1b2c3d',
     80, 8,
     '{
        "en": "Last question — when would you like to get started?",
        "ar": "سؤال أخير — متى تريد أن تبدأ؟",
        "es": "Última pregunta — ¿cuándo le gustaría empezar?",
        "fr": "Dernière question — quand souhaitez-vous commencer ?",
        "zh": "最后一个问题——您想什么时候开始？"
     }'::jsonb,
     'radio',
     '[
        {"id":10,"score":40,
         "en":"Immediately",
         "ar":"فوراً",
         "es":"Inmediatamente",
         "fr":"Immédiatement",
         "zh":"立即"},
        {"id":20,"score":25,
         "en":"Within a Week",
         "ar":"خلال أسبوع",
         "es":"Dentro de una semana",
         "fr":"Dans une semaine",
         "zh":"一周内"},
        {"id":30,"score":10,
         "en":"Within a Month",
         "ar":"خلال شهر",
         "es":"Dentro de un mes",
         "fr":"Dans un mois",
         "zh":"一个月内"},
        {"id":40,"score":5,
         "en":"Just exploring options",
         "ar":"أستكشف الخيارات فقط",
         "es":"Solo estoy explorando opciones",
         "fr":"Je ne fais qu''explorer les options",
         "zh":"只是在了解一下"}
     ]'::jsonb,
     TRUE)
) AS q(faq_version_id, question_id, question_order, question_text, question_type, options, mandatory)
ON CONFLICT (faq_version_id) DO NOTHING;

-- =============================================================
-- 8. Qualification Score — 4 bands on the root ad.
--    VERSIONED: PK is qualification_score_version_id (UUID).
--    Logical key: (ad_id, level_code). Root-only.
--    level_code is the machine code. Label resolves at read
--    time from qualification_levels in the reader's language.
-- =============================================================
INSERT INTO qualification_score (qualification_score_version_id, ad_id, score, level_code)
SELECT
    b.qualification_score_version_id::uuid,
    'c1a2b3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'::uuid,
    b.score,
    b.level_code
FROM (VALUES
    ('d0b1c2e3-f4a5-4b6c-9d7e-9f0a1b2c3d4e', int4range(0, 60),    'low'),
    ('e1c2d3f4-a5b6-4c7d-8e8f-0a1b2c3d4e5f', int4range(60, 100),  'medium'),
    ('f2d3e4a5-b6c7-4d8e-9f9a-1b2c3d4e5f6a', int4range(100, 140), 'high'),
    ('a3e4f5b6-c7d8-4e9f-8a0b-2c3d4e5f6a7b', int4range(140, 176), 'very_high')
) AS b(qualification_score_version_id, score, level_code)
ON CONFLICT (qualification_score_version_id) DO NOTHING;

-- =============================================================
-- 9. Pricing Discounts — global volume tiers.
--    Platform-wide, tier-independent, applied to the per-lead fee.
--    Volume thresholds:
--      0–25       full price
--      26–100     15% off
--      101–500    25% off
--      501+       35% off
--
--    Re-run safe: a row is only inserted when no global volume
--    tier with the same leads_min exists. (ON CONFLICT DO NOTHING
--    is not enough here: NULLs are distinct in unique indexes, so
--    it would add four more rows on every run.)
--
--    The CHECK on pricing_discounts requires leads_max IS NOT NULL
--    for 'volume' rows, so the open-ended 500+ tier uses 999999 as
--    its upper bound. Treat any leads_max >= 999999 as "no upper limit".
--
--    If a row violates a CHECK constraint, the script stops with a
--    message naming the row, the constraint and its definition,
--    and the whole file rolls back (nothing is half-seeded).
-- =============================================================
DO $$
DECLARE
    r            record;
    v_constraint text;
    v_rule       text;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            (0,   25,           0.00::numeric, '0-25'),
            (26,  100,         15.00::numeric, '26-100'),
            (101, 500,         25.00::numeric, '101-500'),
            (501, 999999,      35.00::numeric, '500+')
        ) AS v(mn, mx, pct, lbl)
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pricing_discounts d
            WHERE d.discount_type = 'volume'
              AND d.tier_id    IS NULL
              AND d.client_id  IS NULL
              AND d.country_id IS NULL
              AND d.segment_id IS NULL
              AND d.leads_min  = r.mn
        ) THEN
            BEGIN
                INSERT INTO pricing_discounts
                    (discount_type, tier_id, client_id, country_id, segment_id,
                     field_name, leads_min, leads_max, discount_pct, label)
                VALUES
                    ('volume', NULL, NULL, NULL, NULL,
                     NULL, r.mn, r.mx, r.pct, r.lbl);
            EXCEPTION WHEN check_violation THEN
                GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
                SELECT pg_get_constraintdef(c.oid) INTO v_rule
                FROM pg_constraint c
                WHERE c.conrelid = 'pricing_discounts'::regclass
                  AND c.conname  = v_constraint;
                RAISE EXCEPTION
                    'pricing_discounts row "%" (leads_min %, leads_max %, discount_pct %) violates %: %',
                    r.lbl, r.mn, r.mx, r.pct, v_constraint, v_rule;
            END;
        END IF;
    END LOOP;
END $$;

COMMIT;