-- =====================================================================
-- 01_schema.sql — Star schema
-- Project: AI layoffs vs. hiring (2026)
-- Run: psql -U postgres -d ai_is_piyasasi -f sql/01_schema.sql
--
-- Layers:
--   stg_*      : staging tables, CSVs loaded as-is
--   dim_*      : dimension tables (company, industry, date, country)
--   fact_*     : fact tables (layoff announcements, Indeed posting share, Challenger)
--
-- Date key: date_key = YYYYMMDD (integer). Monthly data (Indeed, Challenger)
-- is linked to the key of the 1st day of the month, so all three data sets
-- join on a single dim_date at month level.
-- =====================================================================

DROP TABLE IF EXISTS fact_layoffs, fact_ai_postings, fact_challenger,
                     dim_company, dim_industry, dim_date, dim_country,
                     stg_layoffs, stg_ai_postings, stg_challenger CASCADE;

-- ---------------------------------------------------------------------
-- 1) STAGING: exact copy of the CSV columns. No transformation here.
-- ---------------------------------------------------------------------
CREATE TABLE stg_layoffs (
    company               TEXT,
    industry              TEXT,
    people_cut            INTEGER,
    people_cut_original   INTEGER,
    is_corrected          BOOLEAN,
    workforce_pct         NUMERIC(5,1),
    total_workforce       INTEGER,
    announce_date         DATE,
    month                 TEXT,
    date_precision        TEXT,
    category              TEXT,
    is_ai_driven          BOOLEAN,
    is_ai_strict          BOOLEAN,
    source_url            TEXT,
    in_main_analysis      BOOLEAN,
    in_core_verified      BOOLEAN,
    reliability_tier      TEXT,
    verification          TEXT,
    verification_note     TEXT,
    auto_source_level     TEXT,
    is_invalid            BOOLEAN,
    is_multi_year         BOOLEAN,
    is_undated            BOOLEAN,
    is_upper_bound        BOOLEAN,
    ai_label_questionable BOOLEAN,
    ai_label_missing      BOOLEAN,
    generic_source        BOOLEAN,
    needs_check           BOOLEAN,
    date_mismatch         BOOLEAN,
    is_partial_month      BOOLEAN,
    date_raw              TEXT
);

CREATE TABLE stg_ai_postings (
    country_code   TEXT,
    month          TEXT,
    ai_share_pct   NUMERIC(6,3),
    country_name   TEXT,
    yoy_change_pt  NUMERIC(6,3),
    note           TEXT,
    comparable     BOOLEAN
);

CREATE TABLE stg_challenger (
    month               TEXT,
    total_us_cuts       INTEGER,
    ai_attributed_cuts  INTEGER,
    ai_share_pct        NUMERIC(5,1),
    ai_ytd_cuts         INTEGER,
    total_ytd_cuts      INTEGER,
    source_url          TEXT,
    note                TEXT
);

-- ---------------------------------------------------------------------
-- 2) DIMENSION TABLES
-- ---------------------------------------------------------------------
CREATE TABLE dim_industry (
    industry_id    SERIAL PRIMARY KEY,
    industry_name  TEXT NOT NULL UNIQUE
);

-- total_workforce is NOT stored here: it differs between rows for 21 companies
-- (e.g. Amazon 350k / 1.55m). It is kept in fact_layoffs instead.
CREATE TABLE dim_company (
    company_id    SERIAL PRIMARY KEY,
    company_name  TEXT NOT NULL UNIQUE,
    industry_id   INTEGER NOT NULL REFERENCES dim_industry(industry_id)
);

CREATE TABLE dim_date (
    date_key       INTEGER PRIMARY KEY,   -- YYYYMMDD
    full_date      DATE NOT NULL UNIQUE,
    year           SMALLINT NOT NULL,
    quarter        SMALLINT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month          SMALLINT NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_start    DATE NOT NULL,         -- 1st day of the month (for monthly grouping)
    year_month     CHAR(7) NOT NULL,      -- '2026-03'
    month_name     TEXT NOT NULL,         -- 'March'
    month_short    TEXT NOT NULL,         -- 'Mar'
    is_partial_month BOOLEAN NOT NULL DEFAULT FALSE  -- November 2026 (data until 6 Nov)
);

CREATE TABLE dim_country (
    country_code  CHAR(2) PRIMARY KEY,
    country_name  TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 3) FACT TABLES
-- ---------------------------------------------------------------------
-- One row = one layoff announcement. No row is deleted; rows outside the
-- main analysis are flagged with in_main_analysis = FALSE.
CREATE TABLE fact_layoffs (
    layoff_id             SERIAL PRIMARY KEY,
    company_id            INTEGER NOT NULL REFERENCES dim_company(company_id),
    industry_id           INTEGER NOT NULL REFERENCES dim_industry(industry_id),
    date_key              INTEGER REFERENCES dim_date(date_key),  -- NULL for the 6 rows with unknown month
    date_precision        TEXT NOT NULL CHECK (date_precision IN ('day','month','year_only','multi_year')),
    people_cut            INTEGER NOT NULL CHECK (people_cut > 0),
    people_cut_original   INTEGER NOT NULL CHECK (people_cut_original > 0),
    is_corrected          BOOLEAN NOT NULL,
    total_workforce       INTEGER NOT NULL CHECK (total_workforce > 0),
    workforce_pct         NUMERIC(5,1) NOT NULL CHECK (workforce_pct BETWEEN 0 AND 100),
    category              TEXT NOT NULL CHECK (category IN ('AI-DRIVEN','COST CUT','RESTRUCTURE','WEAK DEMAND','MERGER')),
    is_ai_driven          BOOLEAN NOT NULL,   -- broad AI definition (upper bound)
    is_ai_strict          BOOLEAN NOT NULL,   -- strict AI definition (HEADLINE)
    ai_label_questionable BOOLEAN NOT NULL,
    ai_label_missing      BOOLEAN NOT NULL,
    is_upper_bound        BOOLEAN NOT NULL,
    reliability_tier      TEXT NOT NULL CHECK (reliability_tier IN
                            ('T1_manual_verified','T2_manual_partial','T3_strong_source',
                             'T4_medium_source','T5_weak_source',
                             'X_invalid','X_multi_year_plan','X_month_unknown')),
    verification          TEXT NOT NULL CHECK (verification IN
                            ('verified','corrected','partial','invalid','mismatch','not_found','not_checked')),
    verification_note     TEXT,
    auto_source_level     TEXT NOT NULL,
    in_main_analysis      BOOLEAN NOT NULL,
    in_core_verified      BOOLEAN NOT NULL,
    is_invalid            BOOLEAN NOT NULL,
    is_undated            BOOLEAN NOT NULL,
    generic_source        BOOLEAN NOT NULL,
    source_url            TEXT NOT NULL,
    date_raw              TEXT NOT NULL,
    -- Business rules: a row that breaks them is rejected at load time
    CONSTRAINT strict_implies_ai   CHECK (NOT is_ai_strict OR is_ai_driven),
    CONSTRAINT strict_excludes_bad CHECK (NOT is_ai_strict OR (NOT ai_label_questionable AND NOT is_upper_bound)),
    CONSTRAINT main_needs_date     CHECK (NOT in_main_analysis OR date_key IS NOT NULL),
    CONSTRAINT cut_le_workforce    CHECK (people_cut <= total_workforce)
);

CREATE TABLE fact_ai_postings (
    country_code   CHAR(2) NOT NULL REFERENCES dim_country(country_code),
    date_key       INTEGER NOT NULL REFERENCES dim_date(date_key),   -- 1st day of the month
    ai_share_pct   NUMERIC(6,3) NOT NULL CHECK (ai_share_pct BETWEEN 0 AND 100),
    yoy_change_pt  NUMERIC(6,3),                                      -- NULL for the first 12 months
    comparable     BOOLEAN NOT NULL,                                  -- Canada Oct 2025+ = FALSE
    note           TEXT,
    PRIMARY KEY (country_code, date_key)
);

CREATE TABLE fact_challenger (
    date_key            INTEGER PRIMARY KEY REFERENCES dim_date(date_key),  -- 1st day of the month
    total_us_cuts       INTEGER NOT NULL CHECK (total_us_cuts > 0),
    ai_attributed_cuts  INTEGER NOT NULL CHECK (ai_attributed_cuts >= 0),
    ai_share_pct        NUMERIC(5,1) NOT NULL,
    ai_ytd_cuts         INTEGER NOT NULL,
    total_ytd_cuts      INTEGER NOT NULL,
    source_url          TEXT NOT NULL,
    note                TEXT,
    CONSTRAINT ai_le_total CHECK (ai_attributed_cuts <= total_us_cuts)
);

-- Indexes for frequently used filters
CREATE INDEX ix_layoffs_date     ON fact_layoffs(date_key);
CREATE INDEX ix_layoffs_industry ON fact_layoffs(industry_id);
CREATE INDEX ix_layoffs_main     ON fact_layoffs(in_main_analysis);
