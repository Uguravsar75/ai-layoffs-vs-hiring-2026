-- =====================================================================
-- 03_analysis.sql — 5 sorunun analizi
-- Çalıştırma: psql -U postgres -d ai_is_piyasasi -f sql/03_analysis.sql
--
-- Her analiz bir VIEW olarak tanımlanır. Neden view?
--   * Power BI aynı view'leri okur -> rakamlar tek yerde hesaplanır
--   * Kuralları (sıkı AI tanımı, ana analiz filtresi) her sorguda tekrar yazmayız
--
-- Kurallar (PROJE_PLANI.md Bölüm 5):
--   * Ana analiz filtresi: in_main_analysis = TRUE (643 satır, 653.456 kişi)
--   * AI payı ANA RAKAM = sıkı tanım (is_ai_strict); geniş tanım (is_ai_driven) = üst sınır
--   * İfade: "duyurulan kesintiler" (kaybedilen işler DEĞİL)
-- =====================================================================

DROP VIEW IF EXISTS v_kpi, v_quality_tiers, v_combined_monthly, v_combined_corr,
                    v_q5_indeed, v_q4_median, v_q3_monthly_ai, v_q2_sector_ai,
                    v_q1_sector_totals, v_layoffs_main CASCADE;

-- ---------------------------------------------------------------------
-- Temel view: ana analizdeki satırlar + boyut bilgileri
-- ---------------------------------------------------------------------
CREATE VIEW v_layoffs_main AS
SELECT f.*, c.company_name, i.industry_name, i.industry_tr,
       d.full_date, d.month_start, d.year_month, d.month_name_tr, d.month_short_tr,
       d.is_partial_month
FROM fact_layoffs f
JOIN dim_company  c ON c.company_id  = f.company_id
JOIN dim_industry i ON i.industry_id = f.industry_id
JOIN dim_date     d ON d.date_key    = f.date_key
WHERE f.in_main_analysis;

-- ---------------------------------------------------------------------
-- KPI kartları (Power BI Sayfa 1)
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
-- Q1: 2026'da en çok hangi sektörler işten çıkarma duyurdu?
--     Kişi toplamı + RANK() ile sıralama + toplamdaki payı
-- =====================================================================
CREATE VIEW v_q1_sector_totals AS
SELECT industry_name,
       industry_tr,
       COUNT(*)                                     AS announcements,
       COUNT(DISTINCT company_id)                   AS companies,
       SUM(people_cut)                              AS people_cut,
       RANK() OVER (ORDER BY SUM(people_cut) DESC)  AS rank_by_people,
       RANK() OVER (ORDER BY COUNT(*) DESC)         AS rank_by_announcements,
       ROUND(100.0 * SUM(people_cut) / SUM(SUM(people_cut)) OVER (), 1) AS share_of_total_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)          AS median_cut,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY workforce_pct)       AS median_workforce_pct
FROM v_layoffs_main
GROUP BY industry_name, industry_tr;

-- =====================================================================
-- Q2: Hangi sektörlerde AI daha sık gerekçe gösterildi?
--     Sıkı tanım ana rakam; geniş tanım üst sınır; duyuru sayısı payı da var
-- =====================================================================
CREATE VIEW v_q2_sector_ai AS
SELECT industry_name,
       industry_tr,
       COUNT(*)                                          AS announcements,
       COUNT(*) FILTER (WHERE is_ai_strict)              AS ai_strict_announcements,
       SUM(people_cut)                                   AS people_cut,
       COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0) AS ai_strict_people_cut,
       ROUND(100.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0) / SUM(people_cut), 1) AS ai_strict_people_pct,
       ROUND(100.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_driven), 0) / SUM(people_cut), 1) AS ai_upper_people_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_ai_strict) / COUNT(*), 1)                           AS ai_strict_count_pct,
       RANK() OVER (ORDER BY 1.0 * COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0)
                             / SUM(people_cut) DESC)    AS rank_ai_strict_pct,
       COUNT(*) < 10                                     AS small_sample  -- 10'dan az duyuru: oran yanıltıcı olabilir
FROM v_layoffs_main
GROUP BY industry_name, industry_tr;

-- =====================================================================
-- Q3: AI gerekçesinin payı aydan aya nasıl değişti?
--     Kişi payı + duyuru sayısı payı, LAG() ile aydan aya değişim,
--     3 aylık hareketli ortalama. Kasım 2026 kısmi ay (işaretli).
-- =====================================================================
CREATE VIEW v_q3_monthly_ai AS
WITH aylik AS (
    SELECT month_start, year_month, month_short_tr, is_partial_month,
           COUNT(*)                                                  AS announcements,
           SUM(people_cut)                                           AS people_cut,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)   AS median_cut,
           COUNT(*) FILTER (WHERE is_ai_strict)                      AS ai_strict_announcements,
           COALESCE(SUM(people_cut) FILTER (WHERE is_ai_strict), 0)  AS ai_strict_people_cut,
           COALESCE(SUM(people_cut) FILTER (WHERE is_ai_driven), 0)  AS ai_upper_people_cut
    FROM v_layoffs_main
    GROUP BY month_start, year_month, month_short_tr, is_partial_month
), oran AS (
    SELECT *,
           ROUND(100.0 * ai_strict_people_cut / people_cut, 1)   AS ai_strict_people_pct,
           ROUND(100.0 * ai_upper_people_cut  / people_cut, 1)   AS ai_upper_people_pct,
           ROUND(100.0 * ai_strict_announcements / announcements, 1) AS ai_strict_count_pct
    FROM aylik
)
SELECT *,
       ai_strict_count_pct  - LAG(ai_strict_count_pct)  OVER w AS count_pct_change_pt,
       ai_strict_people_pct - LAG(ai_strict_people_pct) OVER w AS people_pct_change_pt,
       ROUND(AVG(ai_strict_count_pct)  OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS count_pct_ma3,
       ROUND(AVG(ai_strict_people_pct) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 1) AS people_pct_ma3
FROM oran
WINDOW w AS (ORDER BY month_start);

-- =====================================================================
-- Q4: AI gerekçeli duyurular daha fazla kişiyi mi kapsıyor?
--     Medyan (PERCENTILE_CONT) — ortalama değil, çünkü birkaç dev satır
--     ortalamayı bozar.
-- =====================================================================
CREATE VIEW v_q4_median AS
SELECT CASE WHEN is_ai_strict THEN '1_AI (sıkı)'
            WHEN is_ai_driven THEN '2_AI (sadece geniş: tartışmalı / üst sınır)'
            ELSE '3_AI değil' END                                   AS grp,
       COUNT(*)                                                     AS announcements,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut)      AS median_cut,
       ROUND(AVG(people_cut))                                       AS mean_cut,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_workforce) AS median_company_size
FROM v_layoffs_main
GROUP BY 1
UNION ALL
SELECT '0_AI (geniş, tümü)', COUNT(*),
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY people_cut), ROUND(AVG(people_cut)),
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_workforce)
FROM v_layoffs_main WHERE is_ai_driven;

-- =====================================================================
-- Q5: Aynı dönemde iş ilanlarında AI'dan bahsedenlerin payı nasıl değişti?
--     Indeed, ülke x ay; yıllık değişim (yüzde puan); ABD vurgusu
-- =====================================================================
CREATE VIEW v_q5_indeed AS
SELECT p.country_code, c.country_name, d.month_start, d.year_month,
       p.ai_share_pct, p.yoy_change_pt, p.comparable, p.note,
       p.country_code = 'US' AS is_main_series
FROM fact_ai_postings p
JOIN dim_country c ON c.country_code = p.country_code
JOIN dim_date    d ON d.date_key     = p.date_key;

-- =====================================================================
-- BİRLEŞİK: üç kaynak aynı tabloda, ay bazında (Ocak–Ekim 2026)
--   layoffhedge (dünya) + Indeed ABD (Eylül'de bitiyor) + Challenger (ABD)
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
       iu.indeed_us_ai_pct,          -- Ekim 2026'da NULL (Indeed Eylül'de bitiyor)
       ch.total_us_cuts, ch.ai_attributed_cuts
FROM ch
JOIN lh             ON lh.month_start = ch.month_start
LEFT JOIN indeed_us iu ON iu.month_start = ch.month_start;

-- Korelasyonlar: iki pencere (Oca–Eyl: üç kaynağın ortak dönemi; Oca–Eki: Challenger tümü)
-- Not: n = 9–10 ay. Yön teyidi olarak okunur, kanıt olarak değil. Neden-sonuç değildir.
CREATE VIEW v_combined_corr AS
SELECT 'Oca–Eyl 2026' AS window_label, COUNT(*) AS n_months,
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2)  AS corr_challenger_vs_lh_count,
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_people_pct)::NUMERIC, 2) AS corr_challenger_vs_lh_people,
       ROUND(CORR(indeed_us_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2)   AS corr_indeed_vs_lh_count,
       ROUND(CORR(indeed_us_ai_pct, challenger_ai_pct)::NUMERIC, 2)        AS corr_indeed_vs_challenger
FROM v_combined_monthly WHERE year_month <= '2026-09'
UNION ALL
SELECT 'Oca–Eki 2026', COUNT(*),
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_count_pct)::NUMERIC, 2),
       ROUND(CORR(challenger_ai_pct, lh_ai_strict_people_pct)::NUMERIC, 2),
       NULL, NULL
FROM v_combined_monthly;

-- =====================================================================
-- VERİ KALİTESİ: katman bazında satır ve kişi payı (ana analiz)
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
-- SONUÇLARI GÖSTER
-- =====================================================================
\echo '\n=== KPI ==='
SELECT * FROM v_kpi;

\echo '\n=== Q1: Sektöre göre duyurulan kesintiler ==='
SELECT rank_by_people AS sira, industry_tr AS sektor, announcements AS duyuru, people_cut AS kisi,
       share_of_total_pct AS pay_pct, median_cut AS medyan_kisi
FROM v_q1_sector_totals ORDER BY rank_by_people;

\echo '\n=== Q2: Sektöre göre AI payı (sıkı = ana, geniş = üst sınır) ==='
SELECT rank_ai_strict_pct AS sira, industry_tr AS sektor, announcements AS duyuru,
       ai_strict_people_pct AS ai_kisi_siki, ai_upper_people_pct AS ai_kisi_genis,
       ai_strict_count_pct AS ai_sayi_siki, small_sample AS az_ornek
FROM v_q2_sector_ai ORDER BY rank_ai_strict_pct;

\echo '\n=== Q3: Aylık AI payı (sıkı) ==='
SELECT year_month AS ay, announcements AS duyuru, ai_strict_count_pct AS sayi_pct,
       count_pct_change_pt AS sayi_degisim, count_pct_ma3 AS sayi_ho3,
       ai_strict_people_pct AS kisi_pct, people_pct_ma3 AS kisi_ho3,
       ai_upper_people_pct AS kisi_genis, is_partial_month AS kismi
FROM v_q3_monthly_ai ORDER BY month_start;

\echo '\n=== Q4: Medyan kişi sayısı ==='
SELECT * FROM v_q4_median ORDER BY grp;

\echo '\n=== Q5: Indeed AI ilan payı — Eyl 2025 vs Eyl 2026 ==='
SELECT country_code, country_name,
       MAX(ai_share_pct) FILTER (WHERE year_month = '2025-09') AS eyl_2025,
       MAX(ai_share_pct) FILTER (WHERE year_month = '2026-09') AS eyl_2026,
       MAX(yoy_change_pt) FILTER (WHERE year_month = '2026-09') AS yillik_degisim_pt,
       BOOL_AND(comparable) FILTER (WHERE year_month = '2026-09') AS karsilastirilabilir
FROM v_q5_indeed GROUP BY country_code, country_name ORDER BY eyl_2026 DESC;

\echo '\n=== BİRLEŞİK: üç kaynak ay bazında ==='
SELECT year_month, lh_ai_strict_count_pct, lh_ai_strict_people_pct, challenger_ai_pct, indeed_us_ai_pct
FROM v_combined_monthly ORDER BY month_start;
SELECT * FROM v_combined_corr;

\echo '\n=== VERİ KALİTESİ: katmanlar ==='
SELECT * FROM v_quality_tiers ORDER BY reliability_tier;
