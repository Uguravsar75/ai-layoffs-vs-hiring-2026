-- =====================================================================
-- 04_checks.sql — Do the SQL results match the Python results?
-- Run: psql -U postgres -d ai_is_piyasasi -f sql/04_checks.sql
--
-- "expected": values computed in Python (pandas) from the clean CSV files
--   (layoffs_clean.csv, robustness_check.csv, layoffs_clean_monthly.csv,
--   output of build_challenger.py).
-- "actual": the same value computed from the database views.
-- If any row does not match, the script raises an ERROR at the end.
-- =====================================================================

DROP TABLE IF EXISTS tmp_checks;
CREATE TEMP TABLE tmp_checks AS
WITH checks(check_name, expected, actual) AS (
    VALUES
    -- General
    ('Main analysis rows',                    643,     (SELECT announcements FROM v_kpi)::NUMERIC),
    ('Main analysis people',                  653456,  (SELECT people_cut FROM v_kpi)),
    ('Main analysis companies',               561,     (SELECT companies FROM v_kpi)),
    ('All rows kept (none deleted)',          653,     (SELECT COUNT(*) FROM fact_layoffs)),
    -- AI share
    ('AI people share strict %',              16.9,    (SELECT ai_strict_people_pct FROM v_kpi)),
    ('AI people share broad %',               38.4,    (SELECT ai_upper_people_pct FROM v_kpi)),
    ('AI announcement share strict %',        11.5,    (SELECT ai_strict_count_pct FROM v_kpi)),
    ('AI announcement share broad %',         14.3,    (SELECT ai_upper_count_pct FROM v_kpi)),
    -- Q1
    ('Q1 rank 1 = Automotive',                1,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Automotive & Transportation')),
    ('Q1 rank 2 = Tech',                      2,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Tech')),
    ('Q1 rank 3 = Finance',                   3,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Finance & Banking')),
    ('Q1 Automotive people',                  203285,  (SELECT people_cut FROM v_q1_sector_totals WHERE industry_name = 'Automotive & Transportation')),
    -- Q2
    ('Q2 Tech AI strict %',                   21.0,    (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Tech')),
    ('Q2 Finance AI strict %',                32.7,    (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Finance & Banking')),
    ('Q2 Automotive AI strict %',             1.0,     (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Automotive & Transportation')),
    ('Q2 Tech AI broad %',                    75.3,    (SELECT ai_upper_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Tech')),
    -- Q3
    ('Q3 Jan people share strict %',          30.0,    (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-01')),
    ('Q3 Mar people share strict %',          1.5,     (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-03')),
    ('Q3 Oct people share strict %',          50.5,    (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-10')),
    ('Q3 May count share strict %',           40.3,    (SELECT ai_strict_count_pct FROM v_q3_monthly_ai WHERE year_month = '2026-05')),
    ('Q3 Aug count share strict %',           2.8,     (SELECT ai_strict_count_pct FROM v_q3_monthly_ai WHERE year_month = '2026-08')),
    ('Q3 Jan–Apr mean people strict %',       18.2,    (SELECT ROUND(AVG(100.0 * ai_strict_people_cut / people_cut), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-01' AND '2026-04')),
    ('Q3 Jun–Sep mean people strict %',       5.2,     (SELECT ROUND(AVG(100.0 * ai_strict_people_cut / people_cut), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-06' AND '2026-09')),
    ('Q3 Jan–Jul mean count strict %',        19.5,    (SELECT ROUND(AVG(100.0 * ai_strict_announcements / announcements), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-01' AND '2026-07')),
    ('Q3 Aug–Oct mean count strict %',        3.6,     (SELECT ROUND(AVG(100.0 * ai_strict_announcements / announcements), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-08' AND '2026-10')),
    -- Q4
    ('Q4 AI strict median people',            295,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '1_%')::NUMERIC),
    ('Q4 AI broad median people',             375,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '0_%')::NUMERIC),
    ('Q4 Non-AI median people',               180,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '3_%')::NUMERIC),
    -- Q5
    ('Q5 US Sep 2025 %',                      3.556,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'US' AND year_month = '2025-09')),
    ('Q5 US Sep 2026 %',                      7.155,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'US' AND year_month = '2026-09')),
    ('Q5 GB Sep 2025 %',                      4.945,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'GB' AND year_month = '2025-09')),
    ('Q5 GB Sep 2026 %',                      9.832,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'GB' AND year_month = '2026-09')),
    ('Q5 non-comparable rows (Canada)',       12,      (SELECT COUNT(*) FROM fact_ai_postings WHERE NOT comparable)),
    -- Challenger + combined
    ('Challenger total Jan–Oct',              617189,  (SELECT SUM(total_us_cuts) FROM fact_challenger)),
    ('Challenger AI Jan–Oct',                 121401,  (SELECT SUM(ai_attributed_cuts) FROM fact_challenger)),
    ('Corr Challenger~count Jan–Oct',         0.72,    (SELECT corr_challenger_vs_lh_count FROM v_combined_corr WHERE n_months = 10)),
    ('Corr Challenger~people Jan–Oct',        -0.20,   (SELECT corr_challenger_vs_lh_people FROM v_combined_corr WHERE n_months = 10)),
    ('Corr Challenger~count Jan–Sep',         0.69,    (SELECT corr_challenger_vs_lh_count FROM v_combined_corr WHERE n_months = 9)),
    -- Data quality
    ('T1 people share %',                     47.2,    (SELECT people_pct FROM v_quality_tiers WHERE reliability_tier = 'T1_manual_verified')),
    ('T1–T2 (manual) people share %',         72.3,    (SELECT cumulative_people_pct FROM v_quality_tiers WHERE reliability_tier = 'T2_manual_partial')),
    ('T1–T3 (core) people share %',           81.6,    (SELECT cumulative_people_pct FROM v_quality_tiers WHERE reliability_tier = 'T3_strong_source'))
)
SELECT check_name, expected, actual,
       CASE WHEN ABS(expected - actual) < 0.0005 THEN 'OK' ELSE 'MISMATCH' END AS result
FROM checks;

SELECT * FROM tmp_checks;

SELECT COUNT(*) FILTER (WHERE result = 'OK')       AS ok,
       COUNT(*) FILTER (WHERE result = 'MISMATCH') AS mismatch
FROM tmp_checks;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM tmp_checks WHERE result = 'MISMATCH') THEN
        RAISE EXCEPTION 'SQL and Python results differ — see the MISMATCH rows above';
    END IF;
END $$;
