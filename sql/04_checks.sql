-- =====================================================================
-- 04_checks.sql — SQL sonuçları Python'daki rakamlarla aynı mı?
-- Çalıştırma: psql -U postgres -d ai_is_piyasasi -f sql/04_checks.sql
--
-- "beklenen" kolonu: Python (pandas) ile layoffs_clean.csv vb. dosyalardan
-- hesaplanan değerler (PROJE_PLANI.md Bölüm 5, robustness_check.csv,
-- layoffs_clean_monthly.csv, build_challenger.py çıktısı).
-- "sql" kolonu: aynı değerin veritabanındaki view'lerden hesaplanmış hâli.
-- Herhangi bir satır tutmazsa dosya sonunda HATA verir.
-- =====================================================================

DROP TABLE IF EXISTS tmp_checks;
CREATE TEMP TABLE tmp_checks AS
WITH kontroller(kontrol, beklenen, sql) AS (
    VALUES
    -- Genel
    ('Ana analiz satır',                    643,     (SELECT announcements FROM v_kpi)::NUMERIC),
    ('Ana analiz kişi',                     653456,  (SELECT people_cut FROM v_kpi)),
    ('Ana analiz şirket',                   561,     (SELECT companies FROM v_kpi)),
    ('Toplam satır (silinen yok)',          653,     (SELECT COUNT(*) FROM fact_layoffs)),
    -- AI payı
    ('AI kişi payı sıkı %',                 16.9,    (SELECT ai_strict_people_pct FROM v_kpi)),
    ('AI kişi payı geniş %',                38.4,    (SELECT ai_upper_people_pct FROM v_kpi)),
    ('AI duyuru payı sıkı %',               11.5,    (SELECT ai_strict_count_pct FROM v_kpi)),
    ('AI duyuru payı geniş %',              14.3,    (SELECT ai_upper_count_pct FROM v_kpi)),
    -- Q1
    ('Q1 1. sektör = Otomotiv',             1,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Automotive & Transportation')),
    ('Q1 2. sektör = Teknoloji',            2,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Tech')),
    ('Q1 3. sektör = Finans',               3,       (SELECT rank_by_people FROM v_q1_sector_totals WHERE industry_name = 'Finance & Banking')),
    ('Q1 Otomotiv kişi',                    203285,  (SELECT people_cut FROM v_q1_sector_totals WHERE industry_name = 'Automotive & Transportation')),
    -- Q2
    ('Q2 Teknoloji AI sıkı %',              21.0,    (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Tech')),
    ('Q2 Finans AI sıkı %',                 32.7,    (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Finance & Banking')),
    ('Q2 Otomotiv AI sıkı %',               1.0,     (SELECT ai_strict_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Automotive & Transportation')),
    ('Q2 Teknoloji AI geniş %',             75.3,    (SELECT ai_upper_people_pct FROM v_q2_sector_ai WHERE industry_name = 'Tech')),
    -- Q3
    ('Q3 Ocak kişi payı sıkı %',            30.0,    (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-01')),
    ('Q3 Mart kişi payı sıkı %',            1.5,     (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-03')),
    ('Q3 Ekim kişi payı sıkı %',            50.5,    (SELECT ai_strict_people_pct FROM v_q3_monthly_ai WHERE year_month = '2026-10')),
    ('Q3 Mayıs sayı payı sıkı %',           40.3,    (SELECT ai_strict_count_pct FROM v_q3_monthly_ai WHERE year_month = '2026-05')),
    ('Q3 Ağustos sayı payı sıkı %',         2.8,     (SELECT ai_strict_count_pct FROM v_q3_monthly_ai WHERE year_month = '2026-08')),
    ('Q3 Oca–Nis ort. kişi sıkı %',         18.2,    (SELECT ROUND(AVG(100.0 * ai_strict_people_cut / people_cut), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-01' AND '2026-04')),
    ('Q3 Haz–Eyl ort. kişi sıkı %',         5.2,     (SELECT ROUND(AVG(100.0 * ai_strict_people_cut / people_cut), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-06' AND '2026-09')),
    ('Q3 Oca–Tem ort. sayı sıkı %',         19.5,    (SELECT ROUND(AVG(100.0 * ai_strict_announcements / announcements), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-01' AND '2026-07')),
    ('Q3 Ağu–Eki ort. sayı sıkı %',         3.6,     (SELECT ROUND(AVG(100.0 * ai_strict_announcements / announcements), 1) FROM v_q3_monthly_ai WHERE year_month BETWEEN '2026-08' AND '2026-10')),
    -- Q4
    ('Q4 AI sıkı medyan kişi',              295,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '1_%')::NUMERIC),
    ('Q4 AI geniş medyan kişi',             375,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '0_%')::NUMERIC),
    ('Q4 AI değil medyan kişi',             180,     (SELECT median_cut FROM v_q4_median WHERE grp LIKE '3_%')::NUMERIC),
    -- Q5
    ('Q5 ABD Eyl 2025 %',                   3.556,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'US' AND year_month = '2025-09')),
    ('Q5 ABD Eyl 2026 %',                   7.155,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'US' AND year_month = '2026-09')),
    ('Q5 GB Eyl 2025 %',                    4.945,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'GB' AND year_month = '2025-09')),
    ('Q5 GB Eyl 2026 %',                    9.832,   (SELECT ai_share_pct FROM v_q5_indeed WHERE country_code = 'GB' AND year_month = '2026-09')),
    ('Q5 karşılaştırılamaz satır (Kanada)', 12,      (SELECT COUNT(*) FROM fact_ai_postings WHERE NOT comparable)),
    -- Challenger + birleşik
    ('Challenger toplam Oca–Eki',           617189,  (SELECT SUM(total_us_cuts) FROM fact_challenger)),
    ('Challenger AI Oca–Eki',               121401,  (SELECT SUM(ai_attributed_cuts) FROM fact_challenger)),
    ('Korelasyon Challenger~sayı Oca–Eki',  0.72,    (SELECT corr_challenger_vs_lh_count FROM v_combined_corr WHERE n_months = 10)),
    ('Korelasyon Challenger~kişi Oca–Eki',  -0.20,   (SELECT corr_challenger_vs_lh_people FROM v_combined_corr WHERE n_months = 10)),
    ('Korelasyon Challenger~sayı Oca–Eyl',  0.69,    (SELECT corr_challenger_vs_lh_count FROM v_combined_corr WHERE n_months = 9)),
    -- Veri kalitesi
    ('T1 kişi payı %',                      47.2,    (SELECT people_pct FROM v_quality_tiers WHERE reliability_tier = 'T1_elle_dogrulandi')),
    ('T1–T2 (elle) kişi payı %',            72.3,    (SELECT cumulative_people_pct FROM v_quality_tiers WHERE reliability_tier = 'T2_elle_kismen')),
    ('T1–T3 (çekirdek) kişi payı %',        81.6,    (SELECT cumulative_people_pct FROM v_quality_tiers WHERE reliability_tier = 'T3_guclu_kaynak'))
)
SELECT kontrol, beklenen, sql,
       CASE WHEN ABS(beklenen - sql) < 0.0005 THEN 'TAMAM' ELSE 'FARKLI' END AS sonuc
FROM kontroller;

SELECT * FROM tmp_checks;

SELECT COUNT(*) FILTER (WHERE sonuc = 'TAMAM')  AS tamam,
       COUNT(*) FILTER (WHERE sonuc = 'FARKLI') AS farkli
FROM tmp_checks;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM tmp_checks WHERE sonuc = 'FARKLI') THEN
        RAISE EXCEPTION 'SQL ve Python sonuçları arasında fark var — yukarıdaki FARKLI satırlara bakın';
    END IF;
END $$;
