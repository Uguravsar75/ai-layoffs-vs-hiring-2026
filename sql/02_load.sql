-- =====================================================================
-- 02_load.sql — Temiz CSV'leri yükle, boyut ve olay tablolarını doldur
-- Çalıştırma (proje kök klasöründen!):
--   psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f sql/02_load.sql
--
-- Akış: CSV --\copy--> stg_* --INSERT/SELECT--> dim_* ve fact_*
-- Tekrar çalıştırılabilir: her seferinde tabloları boşaltıp baştan doldurur.
-- =====================================================================

BEGIN;

TRUNCATE fact_layoffs, fact_ai_postings, fact_challenger,
         dim_company, dim_industry, dim_date, dim_country,
         stg_layoffs, stg_ai_postings, stg_challenger RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- 1) CSV -> staging  (\copy istemci tarafında çalışır; yol proje köküne göre)
-- ---------------------------------------------------------------------
\copy stg_layoffs     FROM 'data/clean/layoffs_clean.csv'        WITH (FORMAT csv, HEADER true)
\copy stg_ai_postings FROM 'data/clean/ai_posting_monthly.csv'   WITH (FORMAT csv, HEADER true)
\copy stg_challenger  FROM 'data/clean/challenger_ai_monthly.csv' WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------------
-- 2) dim_date: 2019-01-01 .. 2026-12-31, her gün bir satır
--    (Indeed 2019'dan başlıyor; layoffhedge ve Challenger 2026)
-- ---------------------------------------------------------------------
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_start,
                      year_month, month_name_tr, month_short_tr, is_partial_month)
SELECT TO_CHAR(d, 'YYYYMMDD')::INT,
       d::DATE,
       EXTRACT(YEAR FROM d),
       EXTRACT(QUARTER FROM d),
       EXTRACT(MONTH FROM d),
       DATE_TRUNC('month', d)::DATE,
       TO_CHAR(d, 'YYYY-MM'),
       (ARRAY['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz',
              'Ağustos','Eylül','Ekim','Kasım','Aralık'])[EXTRACT(MONTH FROM d)],
       (ARRAY['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'])[EXTRACT(MONTH FROM d)],
       TO_CHAR(d, 'YYYY-MM') = '2026-11'
FROM GENERATE_SERIES('2019-01-01'::DATE, '2026-12-31'::DATE, INTERVAL '1 day') AS d;

-- ---------------------------------------------------------------------
-- 3) dim_industry (Türkçe etiketle)
-- ---------------------------------------------------------------------
INSERT INTO dim_industry (industry_name, industry_tr)
SELECT DISTINCT s.industry,
       CASE s.industry
           WHEN 'Automotive & Transportation' THEN 'Otomotiv & Ulaşım'
           WHEN 'Tech'                        THEN 'Teknoloji'
           WHEN 'Finance & Banking'           THEN 'Finans & Bankacılık'
           WHEN 'Manufacturing'               THEN 'İmalat'
           WHEN 'Media & Entertainment'       THEN 'Medya & Eğlence'
           WHEN 'Healthcare & Pharma'         THEN 'Sağlık & İlaç'
           WHEN 'Consumer Goods'              THEN 'Tüketim Ürünleri'
           WHEN 'Retail'                      THEN 'Perakende'
           WHEN 'Government & Nonprofit'      THEN 'Kamu & STK'
           WHEN 'Crypto & Fintech'            THEN 'Kripto & Fintech'
           WHEN 'Telecom'                     THEN 'Telekom'
           WHEN 'Education'                   THEN 'Eğitim'
           WHEN 'Energy'                      THEN 'Enerji'
       END
FROM stg_layoffs s
ORDER BY 1;

-- Çeviri listesinde olmayan yeni bir sektör gelirse sessizce NULL kalmasın:
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM dim_industry WHERE industry_tr IS NULL) THEN
        RAISE EXCEPTION 'Türkçe karşılığı olmayan sektör var';
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- 4) dim_company (her şirket tek sektörde; veride kontrol edildi)
-- ---------------------------------------------------------------------
INSERT INTO dim_company (company_name, industry_id)
SELECT DISTINCT s.company, i.industry_id
FROM stg_layoffs s
JOIN dim_industry i ON i.industry_name = s.industry
ORDER BY 1;

-- ---------------------------------------------------------------------
-- 5) dim_country
-- ---------------------------------------------------------------------
INSERT INTO dim_country (country_code, country_name)
SELECT DISTINCT country_code, country_name FROM stg_ai_postings ORDER BY 1;

-- ---------------------------------------------------------------------
-- 6) fact_layoffs
-- ---------------------------------------------------------------------
INSERT INTO fact_layoffs (company_id, industry_id, date_key, date_precision,
        people_cut, people_cut_original, is_corrected, total_workforce, workforce_pct,
        category, is_ai_driven, is_ai_strict, ai_label_questionable, ai_label_missing,
        is_upper_bound, reliability_tier, verification, verification_note,
        auto_source_level, in_main_analysis, in_core_verified, is_invalid, is_undated,
        generic_source, source_url, date_raw)
SELECT c.company_id, c.industry_id,
       TO_CHAR(s.announce_date, 'YYYYMMDD')::INT,      -- NULL tarih -> NULL anahtar
       s.date_precision,
       s.people_cut, s.people_cut_original, s.is_corrected, s.total_workforce, s.workforce_pct,
       s.category, s.is_ai_driven, s.is_ai_strict, s.ai_label_questionable, s.ai_label_missing,
       s.is_upper_bound, s.reliability_tier, s.verification, s.verification_note,
       s.auto_source_level, s.in_main_analysis, s.in_core_verified, s.is_invalid, s.is_undated,
       s.generic_source, s.source_url, s.date_raw
FROM stg_layoffs s
JOIN dim_company c ON c.company_name = s.company;

-- ---------------------------------------------------------------------
-- 7) fact_ai_postings (ay -> ayın 1. gününün anahtarı)
-- ---------------------------------------------------------------------
INSERT INTO fact_ai_postings (country_code, date_key, ai_share_pct, yoy_change_pt, comparable, note)
SELECT country_code, REPLACE(month, '-', '')::INT * 100 + 1,
       ai_share_pct, yoy_change_pt, comparable, NULLIF(note, '')
FROM stg_ai_postings;

-- ---------------------------------------------------------------------
-- 8) fact_challenger
-- ---------------------------------------------------------------------
INSERT INTO fact_challenger (date_key, total_us_cuts, ai_attributed_cuts, ai_share_pct,
                             ai_ytd_cuts, total_ytd_cuts, source_url, note)
SELECT REPLACE(month, '-', '')::INT * 100 + 1, total_us_cuts, ai_attributed_cuts, ai_share_pct,
       ai_ytd_cuts, total_ytd_cuts, source_url, note
FROM stg_challenger;

-- ---------------------------------------------------------------------
-- 9) Yükleme kontrolü: staging ile fact satır sayıları aynı olmalı
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM fact_layoffs)     <> (SELECT COUNT(*) FROM stg_layoffs)     THEN RAISE EXCEPTION 'fact_layoffs satır kaybı'; END IF;
    IF (SELECT COUNT(*) FROM fact_ai_postings) <> (SELECT COUNT(*) FROM stg_ai_postings) THEN RAISE EXCEPTION 'fact_ai_postings satır kaybı'; END IF;
    IF (SELECT COUNT(*) FROM fact_challenger)  <> (SELECT COUNT(*) FROM stg_challenger)  THEN RAISE EXCEPTION 'fact_challenger satır kaybı'; END IF;
END $$;

COMMIT;

SELECT 'fact_layoffs' AS tablo, COUNT(*) AS satir FROM fact_layoffs
UNION ALL SELECT 'fact_ai_postings', COUNT(*) FROM fact_ai_postings
UNION ALL SELECT 'fact_challenger',  COUNT(*) FROM fact_challenger
UNION ALL SELECT 'dim_company',      COUNT(*) FROM dim_company
UNION ALL SELECT 'dim_industry',     COUNT(*) FROM dim_industry
UNION ALL SELECT 'dim_country',      COUNT(*) FROM dim_country
UNION ALL SELECT 'dim_date',         COUNT(*) FROM dim_date;
