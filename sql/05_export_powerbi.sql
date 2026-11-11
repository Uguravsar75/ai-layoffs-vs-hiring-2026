-- =====================================================================
-- 05_export_powerbi.sql — Export the data model and summary tables for Power BI
-- Run (from the project root, after 01–04):
--   psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f sql/05_export_powerbi.sql
--
-- Why: Power BI Desktop runs on Windows (here: a remote virtual machine) and cannot
-- reach this machine's local PostgreSQL, so the model is shipped as CSV files:
--   powerbi/data/model/    star schema (4 dimension + 3 fact tables) -> interactive dashboard
--   powerbi/data/summary/  ready-made analysis views (same numbers as 04_checks.sql)
-- Booleans are written as TRUE/FALSE (PostgreSQL's default t/f would load as text).
-- See powerbi/README.md for the step-by-step use in Power BI.
-- =====================================================================

\! mkdir -p powerbi/data/model powerbi/data/summary

-- For every table/view to export, create a temporary view with booleans as 'TRUE'/'FALSE'
DO $$
DECLARE
    obj  TEXT;
    cols TEXT;
BEGIN
    FOREACH obj IN ARRAY ARRAY[
        'dim_date', 'dim_company', 'dim_industry', 'dim_country',
        'fact_layoffs', 'fact_ai_postings', 'fact_challenger',
        'v_kpi', 'v_q1_sector_totals', 'v_q2_sector_ai', 'v_q3_monthly_ai',
        'v_q4_median', 'v_q5_indeed', 'v_combined_monthly', 'v_quality_tiers']
    LOOP
        SELECT string_agg(
                   CASE WHEN data_type = 'boolean'
                        THEN format('CASE WHEN %1$I IS NULL THEN NULL WHEN %1$I THEN ''TRUE'' ELSE ''FALSE'' END AS %1$I', column_name)
                        ELSE format('%I', column_name) END,
                   ', ' ORDER BY ordinal_position)
          INTO cols
          FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = obj;
        EXECUTE format('CREATE OR REPLACE TEMP VIEW pbi_%s AS SELECT %s FROM %I', obj, cols, obj);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 1) DATA MODEL (star schema) -> powerbi/data/model/
-- ---------------------------------------------------------------------
\copy (SELECT * FROM pbi_dim_date WHERE full_date >= '2024-01-01' ORDER BY date_key) TO 'powerbi/data/model/dim_date.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_company  ORDER BY company_id)   TO 'powerbi/data/model/dim_company.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_industry ORDER BY industry_id)  TO 'powerbi/data/model/dim_industry.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_country  ORDER BY country_code) TO 'powerbi/data/model/dim_country.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_layoffs ORDER BY layoff_id)    TO 'powerbi/data/model/fact_layoffs.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_ai_postings WHERE date_key >= 20240101 ORDER BY country_code, date_key) TO 'powerbi/data/model/fact_ai_postings.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_challenger ORDER BY date_key)  TO 'powerbi/data/model/fact_challenger.csv' WITH (FORMAT csv, HEADER true)

-- ---------------------------------------------------------------------
-- 2) SUMMARY TABLES (ready-made answers) -> powerbi/data/summary/
-- ---------------------------------------------------------------------
\copy (SELECT * FROM pbi_v_kpi)                                        TO 'powerbi/data/summary/kpi.csv'                 WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_q1_sector_totals ORDER BY rank_by_people)   TO 'powerbi/data/summary/q1_industry_totals.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_q2_sector_ai ORDER BY rank_ai_strict_pct)   TO 'powerbi/data/summary/q2_industry_ai_share.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_q3_monthly_ai ORDER BY month_start)         TO 'powerbi/data/summary/q3_monthly_ai_share.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_q4_median ORDER BY grp)                     TO 'powerbi/data/summary/q4_median_size.csv'      WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_q5_indeed WHERE year_month >= '2024-01' ORDER BY country_code, month_start) TO 'powerbi/data/summary/q5_indeed_monthly.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_combined_monthly ORDER BY month_start)      TO 'powerbi/data/summary/combined_monthly.csv'    WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_v_quality_tiers ORDER BY reliability_tier)    TO 'powerbi/data/summary/quality_tiers.csv'       WITH (FORMAT csv, HEADER true)

\echo 'Exported: powerbi/data/model/ (7 files) and powerbi/data/summary/ (8 files)'
