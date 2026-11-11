-- =====================================================================
-- 05_export_powerbi.sql — Export the star schema and analysis views to CSV
-- Run (from the project root, after 01–04):
--   psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f sql/05_export_powerbi.sql
--
-- Why: Power BI Desktop runs on Windows. The Windows machine (e.g. via remote
-- desktop) cannot reach this machine's local PostgreSQL, so the model is
-- shipped as CSV files in powerbi/data/ (also published on GitHub).
-- In Power BI: Get data -> Text/CSV (or Folder) -> powerbi/data/.
-- Relationships: fact_layoffs.date_key -> dim_date.date_key,
--                fact_layoffs.company_id -> dim_company.company_id,
--                fact_layoffs.industry_id -> dim_industry.industry_id,
--                fact_ai_postings.country_code -> dim_country.country_code,
--                fact_ai_postings.date_key / fact_challenger.date_key -> dim_date.date_key
-- =====================================================================

\! mkdir -p powerbi/data

-- Star schema (dimensions + facts)
\copy (SELECT * FROM dim_date WHERE full_date >= '2024-01-01' ORDER BY date_key) TO 'powerbi/data/dim_date.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM dim_company  ORDER BY company_id)  TO 'powerbi/data/dim_company.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM dim_industry ORDER BY industry_id) TO 'powerbi/data/dim_industry.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM dim_country  ORDER BY country_code) TO 'powerbi/data/dim_country.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM fact_layoffs ORDER BY layoff_id)   TO 'powerbi/data/fact_layoffs.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM fact_ai_postings WHERE date_key >= 20240101 ORDER BY country_code, date_key) TO 'powerbi/data/fact_ai_postings.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM fact_challenger ORDER BY date_key) TO 'powerbi/data/fact_challenger.csv' WITH (FORMAT csv, HEADER true)

-- Ready-made analysis views (same numbers as 04_checks.sql)
\copy (SELECT * FROM v_kpi)                                        TO 'powerbi/data/v_kpi.csv'              WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_q1_sector_totals ORDER BY rank_by_people)   TO 'powerbi/data/v_q1_sector_totals.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_q2_sector_ai ORDER BY rank_ai_strict_pct)   TO 'powerbi/data/v_q2_sector_ai.csv'     WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_q3_monthly_ai ORDER BY month_start)         TO 'powerbi/data/v_q3_monthly_ai.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_q4_median ORDER BY grp)                     TO 'powerbi/data/v_q4_median.csv'        WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_combined_monthly ORDER BY month_start)      TO 'powerbi/data/v_combined_monthly.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM v_quality_tiers ORDER BY reliability_tier)    TO 'powerbi/data/v_quality_tiers.csv'    WITH (FORMAT csv, HEADER true)

\echo 'Exported to powerbi/data/'
