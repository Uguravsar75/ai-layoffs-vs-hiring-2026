-- =====================================================================
-- 03_analysis.sql — Analysis of the 5 research questions
-- Run: psql -U postgres -d ai_is_piyasasi -f sql/03_analysis.sql
--
-- Every analysis is defined as a VIEW. Why views?
--   * Power BI reads the same views -> every number is computed in one place
--   * The rules (strict AI definition, main-analysis filter) are not repeated in each query
--
-- Rules (see docs/PROJECT_PLAN.md, section 5):
--   * Main-analysis filter: in_main_analysis = TRUE (643 rows, 653,456 people)
--   * HEADLINE AI share = strict definition (is_ai_strict); broad (is_ai_driven) = upper bound
--   * Wording: "announced job cuts" (NOT "jobs lost")
-- =====================================================================

DROP VIEW IF EXISTS v_kpi, v_quality_tiers, v_combined_monthly, v_combined_corr,
                    v_q5_indeed, v_q4_median, v_q3_monthly_ai, v_q2_sector_ai,
                    v_q1_sector_totals, v_layoffs_main CASCADE;

-- ---------------------------------------------------------------------
-- Base view: main-analysis rows + dimension attributes
-- ---------------------------------------------------------------------
CREATE VIEW v_layoffs_main AS
SELECT f.*, c.company_name, i.industry_name,
       d.full_date, d.month_start, d.year_month, d.month_name, d.month_short,
       d.is_partial_month
FROM fact_layoffs f
JOIN dim_company  c ON c.company_id  = f.company_id
JOIN dim_industry i ON i.industry_id = f.industry_id
JOIN dim_date     d ON d.date_key    = f.date_key
WHERE f.in_main_analysis;

-- ---------------------------------------------------------------------
-- KPI cards (Power BI page 1)
-- ---------------------------------------------------------------------
CREATE VIEW v_kpi AS
SELECT COUNT(*)                                   AS announcements,
       COUNT(DISTINCT company_id)                 AS companies,
       SUM(people_cut)                            AS people_cut,
       ROUND(100.0 * SUM(people_cut) FILTER (WHERE is_ai_strict) / SUM(people_cut), 1) AS ai_strict_people_pct,
       ROUND(100.0 * SUM(people_cut) FILTER (WHERE is_ai_driven) / SUM(people_cut), 1) AS ai_upper_people_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_ai_strict) / COUNT(*), 1)               AS ai_strict_count_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_ai_driven) / COUNT(*), 1)               AS ai_upper_count_pct
FROM v_layoffs_main;

-- =====================================================================
-- Q1: Which industries announced the most job cuts in 2026?
--     People total + RANK() + share of the overall total
-- =====================================================================
CREATE VIEW v_q1_sector_totals AS
SELECT industry_name,
       COUNT(*)                                     AS announcements,
       COUNT(DISTINCT company_id)                   AS companies,
       SUM(people_cut)                              AS people_cut,
       RANK() OVER (ORDER BY SUM(people_cut) DESC)  AS rank_by_people,
       RANK() OVER (ORDER BY COUNT(*) DESC)         AS rank_by_announcements,
       ROUND(100.0 * SUM(people_cut) / SUM(SUM(people_cut)) OVER (), 1) AS share_of_total_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)          AS median_cut,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY workforce_pct)       AS median_workforce_pct
FROM v_layoffs_main
GROUP BY industry_name;

-- =====================================================================
-- Q2: In which industries was AI cited more often?
--     Strict definition = headline; broad = upper bound; count share as well
-- =====================================================================
CREATE VIEW v_q2_sector_ai AS
SELECT industry_name,
       COUNT(*)                                          AS announcements,
       COUNT(*) FILTER (WHERE is_ai_strict)              AS ai_strict_announcements,
       SUM(people_cut)                                   AS people_cut,
       COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0) AS ai_strict_people_cut,
       ROUND(100.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0) / SUM(people_cut), 1) AS ai_strict_people_pct,
       ROUND(100.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_driven), 0) / SUM(people_cut), 1) AS ai_upper_people_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_ai_strict) / COUNT(*), 1)                           AS ai_strict_count_pct,
       RANK() OVER (ORDER BY 1.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0)
                             / SUM(people_cut) DESC)    AS rank_ai_strict_pct,
       COUNT(*) < 10                                     AS small_sample  -- fewer than 10 announcements: share can mislead
FROM v_layoffs_main
GROUP BY industry_name;

-- =====================================================================
-- Q3: How did the share of AI as a stated reason change month by month?
--     People share + announcement-count share, LAG() month-over-month change,
--     3-month moving average. November 2026 is a partial month (flagged).
-- =====================================================================
CREATE VIEW v_q3_monthly_ai AS
WITH monthly AS (
    SELECT month_start, year_month, month_short, is_partial_month,
           COUNT(*)                                                  AS announcements,
           SUM(people_cut)                                           AS people_cut,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)   AS median_cut,
           COUNT(*) FILTER (WHERE is_ai_strict)                      AS ai_strict_announcements,
           COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0)  AS ai_strict_people_cut,
           COALESCE(SUM(people_cut) FILTER (WHERE is_ai_driven), 0)  AS ai_upper_people_cut
    FROM v_layoffs_main
    GROUP BY month_start, year_month, month_short, is_partial_month
), shares AS (
    SELECT *,
           ROUND(100.0 * ai_strict_people_cut / people_cut, 1)   AS ai_strict_people_pct,
           ROUND(100.0 * ai_upper_people_cut  / people_cut, 1)   AS ai_upper_people_pct,
           ROUND(100.0 * ai_strict_announcements / announcements, 1) AS ai_strict_count_pct
    FROM monthly
)
SELECT *,
       ai_strict_count_pct  - LAG(ai_strict_count_pct)  OVER w AS count_pct_change_pt,
       ai_strict_people_pct - LAG(ai_strict_people_pct) OVER w AS people_pct_change_pt,
       ROUND(AVG(ai_strict_count_pct)  OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS count_pct_ma3,
       ROUND(AVG(ai_strict_people_pct) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS people_pct_ma3
FROM shares
WINDOW w AS (ORDER BY month_start);

-- =====================================================================
-- Q4: Do AI-attributed announcements cover more people?
--     Median (PERCENTILE_CONT), not mean, because a few giant rows distort the mean.
-- =====================================================================
CREATE VIEW v_q4_median AS
SELECT CASE WHEN is_ai_strict THEN '1_AI (strict)'
            WHEN is_ai_driven THEN '2_AI (broad only: questionable / upper bound)'
            ELSE '3_Non-AI' END                                     AS grp,
       COUNT(*)                                                     AS announcements,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)      AS median_cut,
       ROUND(AVG(people_cut))                                       AS mean_cut,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_workforce) AS median_company_size
FROM v_layoffs_main
GROUP BY 1
UNION ALL
SELECT '0_AI (broad, all)', COUNT(*),
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut), ROUND(AVG(people_cut)),
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_workforce)
FROM v_layoffs_main WHERE is_ai_driven;

-- =====================================================================
-- Q5: How did the share of job postings mentioning AI change in the same period?
--     Indeed, country x month; year-over-year change (percentage points); US = main series
-- =====================================================================
CREATE VIEW v_q5_indeed AS
SELECT p.country_code, c.country_name, d.month_start, d.year_month,
       p.ai_share_pct, p.yoy_change_pt, p.comparable, p.note,
       p.country_code = 'US' AS is_main_series
FROM fact_ai_postings p
JOIN dim_country c ON c.country_code = p.country_code
JOIN dim_date    d ON d.date_key     = p.date_key;

-- =====================================================================
-- COMBINED: three sources in one table, by month (Jan–Oct 2026)
--   layoffhedge (global) + Indeed US (ends in September) + Challenger (US)
-- =====================================================================
CREATE VIEW v_combined_monthly AS
WITH lh AS (
    SELECT month_start, ai_strict_people_pct, ai_strict_count_pct
    FROM v_q3_monthly_ai
), indeed_us AS (
    SELECT month_start, ai_share_pct AS indeed_us_ai_pct
    FROM v_q5_indeed WHERE country_code = 'US'
), ch AS (
    SELECT d.month_start, c.ai_share_pct AS challenger_ai_pct, c.total_us_cuts, c.ai_attributed_cuts
    FROM fact_challenger c JOIN dim_date d ON d.date_key = c.date_key
)
SELECT ch.month_start, TO_CHAR(ch.month_start, 'YYYY-MM') AS year_month,
       lh.ai_strict_people_pct AS lh_ai_strict_people_pct,
       lh.ai_strict_count_pct  AS lh_ai_strict_count_pct,
       ch.challenger_ai_pct,
       iu.indeed_us_ai_pct,          -- NULL for October 2026 (Indeed ends in September)
       ch.total_us_cuts, ch.ai_attributed_cuts
FROM ch
JOIN lh             ON lh.month_start = ch.month_start
LEFT JOIN indeed_us iu ON iu.month_start = ch.month_start;

-- Correlations in two windows (Jan–Sep: all three sources overlap; Jan–Oct: all Challenger months)
-- Note: n = 9–10 months. Read as confirmation of direction, not as proof. Not causal.
CREATE VIEW v_combined_corr AS
SELECT 'Jan–Sep 2026' AS window_label, COUNT(*) AS n_months,
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2)  AS corr_challenger_vs_lh_count,
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_people_pct)::NUMERIC, 2) AS corr_challenger_vs_lh_people,
       ROUND(CORR(indeed_us_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2)   AS corr_indeed_vs_lh_count,
       ROUND(CORR(indeed_us_ai_pct, challenger_ai_pct)::NUMERIC, 2)        AS corr_indeed_vs_challenger
FROM v_combined_monthly WHERE year_month <= '2026-09'
UNION ALL
SELECT 'Jan–Oct 2026', COUNT(*),
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2),
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_people_pct)::NUMERIC, 2),
       NULL, NULL
FROM v_combined_monthly;

-- =====================================================================
-- DATA QUALITY: rows and people share by reliability tier (main analysis)
-- =====================================================================
CREATE VIEW v_quality_tiers AS
SELECT reliability_tier,
       COUNT(*)                                                        AS rows,
       SUM(people_cut)                                                 AS people_cut,
       ROUND(100.0 * SUM(people_cut) / SUM(SUM(people_cut)) OVER (), 1) AS people_pct,
       ROUND(100.0 * SUM(SUM(people_cut)) OVER (ORDER BY reliability_tier)
                   / SUM(SUM(people_cut)) OVER (), 1)                  AS cumulative_people_pct
FROM v_layoffs_main
GROUP BY reliability_tier;

-- =====================================================================
-- SHOW RESULTS
-- =====================================================================
\echo '\n=== KPI ==='
SELECT * FROM v_kpi;

\echo '\n=== Q1: Announced job cuts by industry ==='
SELECT rank_by_people AS rank, industry_name, announcements, people_cut,
       share_of_total_pct, median_cut
FROM v_q1_sector_totals ORDER BY rank_by_people;

\echo '\n=== Q2: AI share by industry (strict = headline, broad = upper bound) ==='
SELECT rank_ai_strict_pct AS rank, industry_name, announcements,
       ai_strict_people_pct, ai_upper_people_pct, ai_strict_count_pct, small_sample
FROM v_q2_sector_ai ORDER BY rank_ai_strict_pct;

\echo '\n=== Q3: Monthly AI share (strict) ==='
SELECT year_month, announcements, ai_strict_count_pct, count_pct_change_pt, count_pct_ma3,
       ai_strict_people_pct, people_pct_ma3, ai_upper_people_pct, is_partial_month
FROM v_q3_monthly_ai ORDER BY month_start;

\echo '\n=== Q4: Median people per announcement ==='
SELECT * FROM v_q4_median ORDER BY grp;

\echo '\n=== Q5: Indeed share of postings mentioning AI — Sep 2025 vs Sep 2026 ==='
SELECT country_code, country_name,
       MAX(ai_share_pct) FILTER (WHERE year_month = '2025-09') AS sep_2025,
       MAX(ai_share_pct) FILTER (WHERE year_month = '2026-09') AS sep_2026,
       MAX(yoy_change_pt) FILTER (WHERE year_month = '2026-09') AS yoy_change_pt,
       BOOL_AND(comparable) FILTER (WHERE year_month = '2026-09') AS comparable
FROM v_q5_indeed GROUP BY country_code, country_name ORDER BY sep_2026 DESC;

\echo '\n=== COMBINED: three sources by month ==='
SELECT year_month, lh_ai_strict_count_pct, lh_ai_strict_people_pct, challenger_ai_pct, indeed_us_ai_pct
FROM v_combined_monthly ORDER BY month_start;
SELECT * FROM v_combined_corr;

\echo '\n=== DATA QUALITY: reliability tiers ==='
SELECT * FROM v_quality_tiers ORDER BY reliability_tier;
