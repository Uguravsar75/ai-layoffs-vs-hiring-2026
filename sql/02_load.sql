-- =====================================================================
-- 02_load.sql — Load the clean CSVs, populate dimension and fact tables
-- Run (from the project root folder!):
--   psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f sql/02_load.sql
--
-- Flow: CSV --\copy--> stg_* --INSERT/SELECT--> dim_* and fact_*
-- Re-runnable: empties all tables and reloads them every time.
-- =====================================================================

BEGIN;

TRUNCATE fact_layoffs, fact_ai_postings, fact_challenger,
         dim_company, dim_industry, dim_date, dim_country,
         stg_layoffs, stg_ai_postings, stg_challenger RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- 1) CSV -> staging  (\copy runs client-side; paths are relative to the project root)
-- ---------------------------------------------------------------------
\copy stg_layoffs     FROM 'data/clean/layoffs_clean.csv'        WITH (FORMAT csv, HEADER true)
\copy stg_ai_postings FROM 'data/clean/ai_posting_monthly.csv'   WITH (FORMAT csv, HEADER true)
\copy stg_challenger  FROM 'data/clean/challenger_ai_monthly.csv' WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------------
-- 2) dim_date: 2019-01-01 .. 2026-12-31, one row per day
--    (Indeed starts in 2019; layoffhedge and Challenger cover 2026)
-- ---------------------------------------------------------------------
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_start,
                      year_month, month_name, month_short, is_partial_month)
SELECT TO_CHAR(d, 'YYYYMMDD')::INT,
       d::DATE,
       EXTRACT(YEAR FROM d),
       EXTRACT(QUARTER FROM d),
       EXTRACT(MONTH FROM d),
       DATE_TRUNC('month', d)::DATE,
       TO_CHAR(d, 'YYYY-MM'),
       TRIM(TO_CHAR(d, 'Month')),
       TO_CHAR(d, 'Mon'),
       TO_CHAR(d, 'YYYY-MM') = '2026-11'
FROM GENERATE_SERIES('2019-01-01'::DATE, '2026-12-31'::DATE, INTERVAL '1 day') AS d;

-- ---------------------------------------------------------------------
-- 3) dim_industry
-- ---------------------------------------------------------------------
INSERT INTO dim_industry (industry_name)
SELECT DISTINCT industry FROM stg_layoffs ORDER BY 1;

-- ---------------------------------------------------------------------
-- 4) dim_company (each company belongs to one industry; checked in the data)
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
       TO_CHAR(s.announce_date, 'YYYYMMDD')::INT,      -- NULL date -> NULL key
       s.date_precision,
       s.people_cut, s.people_cut_original, s.is_corrected, s.total_workforce, s.workforce_pct,
       s.category, s.is_ai_driven, s.is_ai_strict, s.ai_label_questionable, s.ai_label_missing,
       s.is_upper_bound, s.reliability_tier, s.verification, s.verification_note,
       s.auto_source_level, s.in_main_analysis, s.in_core_verified, s.is_invalid, s.is_undated,
       s.generic_source, s.source_url, s.date_raw
FROM stg_layoffs s
JOIN dim_company c ON c.company_name = s.company;

-- ---------------------------------------------------------------------
-- 7) fact_ai_postings (month -> key of the 1st day of the month)
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
-- 9) Load check: staging and fact row counts must match
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM fact_layoffs)     <> (SELECT COUNT(*) FROM stg_layoffs)     THEN RAISE EXCEPTION 'fact_layoffs lost rows'; END IF;
    IF (SELECT COUNT(*) FROM fact_ai_postings) <> (SELECT COUNT(*) FROM stg_ai_postings) THEN RAISE EXCEPTION 'fact_ai_postings lost rows'; END IF;
    IF (SELECT COUNT(*) FROM fact_challenger)  <> (SELECT COUNT(*) FROM stg_challenger)  THEN RAISE EXCEPTION 'fact_challenger lost rows'; END IF;
END $$;

COMMIT;

SELECT 'fact_layoffs' AS table_name, COUNT(*) AS row_count FROM fact_layoffs
UNION ALL SELECT 'fact_ai_postings', COUNT(*) FROM fact_ai_postings
UNION ALL SELECT 'fact_challenger',  COUNT(*) FROM fact_challenger
UNION ALL SELECT 'dim_company',      COUNT(*) FROM dim_company
UNION ALL SELECT 'dim_industry',     COUNT(*) FROM dim_industry
UNION ALL SELECT 'dim_country',      COUNT(*) FROM dim_country
UNION ALL SELECT 'dim_date',         COUNT(*) FROM dim_date;
