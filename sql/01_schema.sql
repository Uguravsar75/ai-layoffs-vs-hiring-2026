-- =====================================================================
-- 01_schema.sql — Yıldız şema
-- Proje: Yapay Zekânın İş Piyasasına Gerçek Etkisi (2026)
-- Çalıştırma: psql -U postgres -d ai_is_piyasasi -f sql/01_schema.sql
--
-- Yapı:
--   stg_*      : CSV'lerin olduğu gibi yüklendiği ara (staging) tablolar
--   dim_*      : boyut tabloları (şirket, sektör, tarih, ülke)
--   fact_*     : olay tabloları (kesinti duyuruları, Indeed ilan payı, Challenger)
--
-- Tarih anahtarı: date_key = YYYYMMDD (tam sayı). Aylık veriler (Indeed,
-- Challenger) ayın 1. gününün anahtarına bağlanır; böylece üç veri seti
-- tek bir dim_date üzerinden ay bazında birleşir.
-- =====================================================================

DROP TABLE IF EXISTS fact_layoffs, fact_ai_postings, fact_challenger,
                     dim_company, dim_industry, dim_date, dim_country,
                     stg_layoffs, stg_ai_postings, stg_challenger CASCADE;

-- ---------------------------------------------------------------------
-- 1) STAGING: CSV kolonlarının birebir aynısı. Dönüşüm burada yapılmaz.
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
-- 2) BOYUT TABLOLARI
-- ---------------------------------------------------------------------
CREATE TABLE dim_industry (
    industry_id    SERIAL PRIMARY KEY,
    industry_name  TEXT NOT NULL UNIQUE,
    industry_tr    TEXT NOT NULL          -- Power BI'da Türkçe etiket
);

-- total_workforce burada DEĞİL: 21 şirkette satırdan satıra farklı
-- (ör. Amazon 350 bin / 1,55 milyon). Bu yüzden fact_layoffs'ta tutulur.
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
    month_start    DATE NOT NULL,         -- ayın 1. günü (ay bazında gruplama için)
    year_month     CHAR(7) NOT NULL,      -- '2026-03'
    month_name_tr  TEXT NOT NULL,         -- 'Mart'
    month_short_tr TEXT NOT NULL,         -- 'Mar'
    is_partial_month BOOLEAN NOT NULL DEFAULT FALSE  -- Kasım 2026 (6 Kasım'a kadar)
);

CREATE TABLE dim_country (
    country_code  CHAR(2) PRIMARY KEY,
    country_name  TEXT NOT NULL
);

-- ---------------------------------------------------------------------
-- 3) OLAY (FACT) TABLOLARI
-- ---------------------------------------------------------------------
-- Her satır = bir kesinti duyurusu. Hiçbir satır silinmez; analiz dışı
-- satırlar in_main_analysis = FALSE ile işaretlidir.
CREATE TABLE fact_layoffs (
    layoff_id             SERIAL PRIMARY KEY,
    company_id            INTEGER NOT NULL REFERENCES dim_company(company_id),
    industry_id           INTEGER NOT NULL REFERENCES dim_industry(industry_id),
    date_key              INTEGER REFERENCES dim_date(date_key),  -- ayı bilinmeyen 6 satırda NULL
    date_precision        TEXT NOT NULL CHECK (date_precision IN ('day','month','year_only','multi_year')),
    people_cut            INTEGER NOT NULL CHECK (people_cut > 0),
    people_cut_original   INTEGER NOT NULL CHECK (people_cut_original > 0),
    is_corrected          BOOLEAN NOT NULL,
    total_workforce       INTEGER NOT NULL CHECK (total_workforce > 0),
    workforce_pct         NUMERIC(5,1) NOT NULL CHECK (workforce_pct BETWEEN 0 AND 100),
    category              TEXT NOT NULL CHECK (category IN ('AI-DRIVEN','COST CUT','RESTRUCTURE','WEAK DEMAND','MERGER')),
    is_ai_driven          BOOLEAN NOT NULL,   -- geniş AI tanımı (üst sınır)
    is_ai_strict          BOOLEAN NOT NULL,   -- sıkı AI tanımı (ANA RAKAM)
    ai_label_questionable BOOLEAN NOT NULL,
    ai_label_missing      BOOLEAN NOT NULL,
    is_upper_bound        BOOLEAN NOT NULL,
    reliability_tier      TEXT NOT NULL CHECK (reliability_tier IN
                            ('T1_elle_dogrulandi','T2_elle_kismen','T3_guclu_kaynak',
                             'T4_orta_kaynak','T5_zayif_kaynak',
                             'X_hatali','X_tarihsiz_plan','X_ay_belirsiz')),
    verification          TEXT NOT NULL,
    verification_note     TEXT,
    auto_source_level     TEXT NOT NULL,
    in_main_analysis      BOOLEAN NOT NULL,
    in_core_verified      BOOLEAN NOT NULL,
    is_invalid            BOOLEAN NOT NULL,
    is_undated            BOOLEAN NOT NULL,
    generic_source        BOOLEAN NOT NULL,
    source_url            TEXT NOT NULL,
    date_raw              TEXT NOT NULL,
    -- Mantık kuralları: veri bu kurallara uymazsa yükleme reddedilir
    CONSTRAINT strict_implies_ai   CHECK (NOT is_ai_strict OR is_ai_driven),
    CONSTRAINT strict_excludes_bad CHECK (NOT is_ai_strict OR (NOT ai_label_questionable AND NOT is_upper_bound)),
    CONSTRAINT main_needs_date     CHECK (NOT in_main_analysis OR date_key IS NOT NULL),
    CONSTRAINT cut_le_workforce    CHECK (people_cut <= total_workforce)
);

CREATE TABLE fact_ai_postings (
    country_code   CHAR(2) NOT NULL REFERENCES dim_country(country_code),
    date_key       INTEGER NOT NULL REFERENCES dim_date(date_key),   -- ayın 1. günü
    ai_share_pct   NUMERIC(6,3) NOT NULL CHECK (ai_share_pct BETWEEN 0 AND 100),
    yoy_change_pt  NUMERIC(6,3),                                      -- ilk 12 ayda NULL
    comparable     BOOLEAN NOT NULL,                                  -- Kanada Eki 2025+ = FALSE
    note           TEXT,
    PRIMARY KEY (country_code, date_key)
);

CREATE TABLE fact_challenger (
    date_key            INTEGER PRIMARY KEY REFERENCES dim_date(date_key),  -- ayın 1. günü
    total_us_cuts       INTEGER NOT NULL CHECK (total_us_cuts > 0),
    ai_attributed_cuts  INTEGER NOT NULL CHECK (ai_attributed_cuts >= 0),
    ai_share_pct        NUMERIC(5,1) NOT NULL,
    ai_ytd_cuts         INTEGER NOT NULL,
    total_ytd_cuts      INTEGER NOT NULL,
    source_url          TEXT NOT NULL,
    note                TEXT,
    CONSTRAINT ai_le_total CHECK (ai_attributed_cuts <= total_us_cuts)
);

-- Sık kullanılan filtreler için indeksler
CREATE INDEX ix_layoffs_date     ON fact_layoffs(date_key);
CREATE INDEX ix_layoffs_industry ON fact_layoffs(industry_id);
CREATE INDEX ix_layoffs_main     ON fact_layoffs(in_main_analysis);
