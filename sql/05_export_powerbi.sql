-- =====================================================================
-- 05_export_powerbi.sql — Export the data model for Power BI
-- Run (from the project root, after 01–04):
--   psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f sql/05_export_powerbi.sql
--
-- Why: Power BI Desktop runs on Windows (here: a remote virtual machine) and cannot
-- reach this machine's local PostgreSQL, so the model is shipped as CSV files:
--   powerbi/data/model/    star schema (4 dimension + 3 fact tables) -> interactive dashboard
-- Booleans are written as TRUE/FALSE (PostgreSQL's default t/f would load as text).
-- See powerbi/README.md for the step-by-step use in Power BI.
-- =====================================================================

\! mkdir -p powerbi/data/model

-- For every table/view to export, create a temporary view with booleans as 'TRUE'/'FALSE'
DO $$
DECLARE
    obj  TEXT;
    cols TEXT;
BEGIN
    FOREACH obj IN ARRAY ARRAY[
        'dim_date', 'dim_company', 'dim_industry', 'dim_country',
        'fact_layoffs', 'fact_ai_postings', 'fact_challenger']
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
-- DATA MODEL (star schema) -> powerbi/data/model/
-- ---------------------------------------------------------------------
\copy (SELECT * FROM pbi_dim_date WHERE full_date >= '2024-01-01' ORDER BY date_key) TO 'powerbi/data/model/dim_date.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_company  ORDER BY company_id)   TO 'powerbi/data/model/dim_company.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_industry ORDER BY industry_id)  TO 'powerbi/data/model/dim_industry.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_dim_country  ORDER BY country_code) TO 'powerbi/data/model/dim_country.csv'  WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_layoffs ORDER BY layoff_id)    TO 'powerbi/data/model/fact_layoffs.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_ai_postings WHERE date_key >= 20240101 ORDER BY country_code, date_key) TO 'powerbi/data/model/fact_ai_postings.csv' WITH (FORMAT csv, HEADER true)
\copy (SELECT * FROM pbi_fact_challenger ORDER BY date_key)  TO 'powerbi/data/model/fact_challenger.csv' WITH (FORMAT csv, HEADER true)

\echo 'Exported: powerbi/data/model/ (7 files)'
