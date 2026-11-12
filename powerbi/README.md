# Power BI folder

Everything Power BI needs is in this folder. **Dashboard pages:** Overview · AI Narrative · Hiring Side · Data Reliability (see `screenshots/`). Copy the whole `powerbi/` folder to the Windows machine and open it from Power BI Desktop — no database connection is required.

```
powerbi/
├── README.md            ← this file
├── data/
│   └── model/           ← the data model (7 tables) behind the dashboard
├── dashboard.pbix       ← the Power BI file (4 pages, data imported — opens without the CSVs)
├── dashboard.pdf        ← PDF export of the four pages
└── screenshots/         ← one PNG per page
```

The CSV files are exported from the PostgreSQL database by `sql/05_export_powerbi.sql`. Booleans are written as `TRUE`/`FALSE`, so Power BI reads them as True/False columns.

---

## 1. `data/model/` — the data model (star schema)

Two kinds of tables:
- **Fact tables** hold the events (one row = one announcement, one country-month, …).
- **Dimension tables** describe them (which company, which industry, which date). Filters and slicers come from these.

| File | Type | One row = | Rows | Key columns |
|---|---|---|---|---|
| `fact_layoffs.csv` | Fact | one job-cut announcement (layoffhedge, 2026) | 653 | `company_id`, `industry_id`, `date_key` |
| `fact_ai_postings.csv` | Fact | one country × month (Indeed, 2024–Sep 2026) | 297 | `country_code`, `date_key` |
| `fact_challenger.csv` | Fact | one month (Challenger, US, Jan–Oct 2026) | 10 | `date_key` |
| `dim_date.csv` | Dimension | one day (2024–2026) | 1,096 | `date_key` |
| `dim_company.csv` | Dimension | one company | 568 | `company_id` |
| `dim_industry.csv` | Dimension | one industry | 13 | `industry_id` |
| `dim_country.csv` | Dimension | one country (Indeed) | 9 | `country_code` |

**Most important columns in `fact_layoffs`**

| Column | Meaning |
|---|---|
| `people_cut` | Announced number of people (after corrections) |
| `in_main_analysis` | **Always filter on TRUE** (643 rows). FALSE = wrong-year or undated rows, kept for transparency |
| `is_ai_strict` | AI cited, label not questionable, number not "up to …" → **headline AI definition** |
| `is_ai_driven` | Any AI label → broad definition, **upper bound only** |
| `reliability_tier` | T1 (manually verified) … T5 (weak source) |
| `total_workforce`, `workforce_pct` | Company size and share of workforce cut |

Monthly facts (Indeed, Challenger) use the `date_key` of the **1st day of the month** (e.g. `20260301` = March 2026).

## 2. Loading the model in Power BI Desktop

1. **Get data → Text/CSV**, load the 7 files in `data/model/` (one by one, or **Get data → Folder** and combine is *not* needed — load them as separate tables).
2. Check the column types in Power Query: `date_key` and `*_id` = Whole number, `TRUE/FALSE` columns = True/False, `full_date` / `month_start` = Date.
3. **Model view → create the relationships** (all *many-to-one*, single direction, from fact to dimension):

| From (many) | To (one) |
|---|---|
| `fact_layoffs[date_key]` | `dim_date[date_key]` |
| `fact_layoffs[company_id]` | `dim_company[company_id]` |
| `fact_layoffs[industry_id]` | `dim_industry[industry_id]` |
| `fact_ai_postings[date_key]` | `dim_date[date_key]` |
| `fact_ai_postings[country_code]` | `dim_country[country_code]` |
| `fact_challenger[date_key]` | `dim_date[date_key]` |

4. Mark `dim_date` as the date table (**Table tools → Mark as date table → `full_date`**).

## 3. Numbers the dashboard must reproduce

| Check | Expected |
|---|---|
| Announcements (main analysis) | 643 |
| People (main analysis) | 653,456 |
| AI share of people, strict | 16.9% |
| AI share of people, broad (upper bound) | 38.4% |
| AI share of announcements, strict | 11.5% |
| Top 3 industries | Automotive & Transportation, Tech, Finance & Banking |
| AI share of announcements, May 2026 | 40.3% |
| Indeed US, Sep 2025 → Sep 2026 | 3.6% → 7.2% |

If a dashboard number differs, the usual cause is a missing `in_main_analysis = TRUE` filter.

## 4. Sources (show on every page)
layoffhedge.com (2026-11-08) · Indeed Hiring Lab AI Tracker (CC BY 4.0) · Challenger, Gray & Christmas monthly reports. See `../data/SOURCES.md`.
