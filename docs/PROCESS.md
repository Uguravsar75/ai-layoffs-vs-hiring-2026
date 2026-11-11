# Process Log — Every Step From Scratch
## AI Layoffs vs. Hiring (2026)

This file documents every data-preparation and analysis step, in order, with the reasoning behind it.
Goal: anyone reviewing the project should find the answers to "where does this data come from, how was it cleaned, and why can it be trusted?" here.

---

## 0. Purpose of the project

**Question:** In 2026, how often did companies cite artificial intelligence (AI) when announcing job cuts, how did that change over time, and how did the share of job postings mentioning AI move in the same period?

**The 5 research questions:**
1. Which industries announced the most job cuts in 2026?
2. In which industries was AI cited more often?
3. How did the share of AI as a stated reason change month by month? (independent cross-check with Challenger reports)
4. Do AI-attributed announcements cover more people?
5. How did the share of job postings mentioning AI change in the same period?

**Conclusion section:** what this picture **suggests** for junior (entry-level) candidates. This section is an interpretation: the data contains no seniority information.

**Tools:** Python (pandas, numpy, scipy) → PostgreSQL → Power BI. No machine learning; pure data analytics.

**Important wording decision:** the project says **"announced job cuts"**, not "jobs lost", because many of the large numbers are multi-year plans or "up to …" statements (see §5).

---

## 1. Data sources

| # | File | Source | Content | License |
|---|---|---|---|---|
| 1 | `raw/layoffs_2026.csv` | layoffhedge.com (version of 8 Nov 2026) | 653 job-cut announcements in 2026: company, industry, people cut, workforce %, total workforce, date, category, source link | Free to use with attribution |
| 2 | `raw/layoffs_monthly_2026.csv`, `raw/layoffs_industries_2026.csv` | layoffhedge.com | The site's own monthly and industry summaries (used for reconciliation only) | Free to use with attribution |
| 3 | `raw/indeed_ai_posting.csv` | Indeed Hiring Lab – AI Tracker | Daily share of job postings mentioning AI in 9 countries (7-day average). 25,470 rows | CC-BY-4.0 |
| 4 | `clean/challenger_ai_monthly.csv` (`build_challenger.py`) | Challenger, Gray & Christmas monthly reports | Jan–Oct 2026, monthly total and AI-attributed job cuts in the US (independent cross-check) | Public reports |

**Why these sources?**
- layoffhedge is the most up-to-date free source for 2026 that gives a source link for every row. Because it is little known, **it had to be verified** (§3–§7).
- Indeed is the best-known open data set measuring the share of job postings that mention AI (not a direct measure of AI-skill demand; see §11).
- Challenger reports US job cuts and their stated reasons every month and is widely quoted in the media. It is used to check the AI share independently.

---

## 2. First inspection: why did the file open as a single column in Excel?

When `layoffs_2026.csv` was opened in Excel, all data appeared in column A. Reasons:
- The file is **comma-separated**, while Turkish-locale Excel expects a **semicolon**.
- The first 3 lines are not data but comments starting with `#`:
  ```
  # Source: layoffhedge.com
  # License: Free to use with attribution
  # Generated: 2026-11-08
  ```

**Fix:**
- In Excel: *Data → From Text/CSV* → choose "Comma" as separator.
- In Python: `pd.read_csv("layoffs_2026.csv", comment="#")` → lines starting with `#` are skipped.

The data was not broken; only the read settings were wrong.

---

## 3. Automatic checks (all 653 rows)

Before looking at any row by hand, all data was checked with code:

| Check | Result |
|---|---|
| Blank cells? | None |
| Duplicate rows? | None |
| Logic errors (people cut > total workforce) | None |
| Does `Workforce %` = people / total workforce × 100? | Exact match |
| Date format | **Problematic** → §3.1 |
| Source links | Each scored automatically → §3.2 |

### 3.1 The date problem and its fix
The date column has no year and comes in four formats:

| Raw value | Meaning | What was done | `date_precision` |
|---|---|---|---|
| `Oct 13` | 13 October (no year) | Read as 2026-10-13 (the file is a 2026 list) | `day` |
| `Jan 2026` | Only the month is known | Read as 2026-01-01 | `month` |
| `2026` | Only the year is known | Date left empty, **excluded from the main analysis** | `year_only` |
| `2025-30`, `2025-26` etc. | Multi-year plan, no date | Date left empty, **excluded from the main analysis** | `multi_year` |

For 6 rows the month is unknown (`is_undated = True`): 3 are `multi_year` (Citigroup 20,000, P&G 7,000, Bosch 13,000) and 3 are `year_only` (Chevron 7,820, Telefonica 6,000, Accenture 11,000). They cannot be placed in a month, so they are excluded from the main analysis. They were not deleted, only flagged.

### 3.2 Source-link scoring (`auto_source_level`)
Every source link was examined by code:

| Level | Rule |
|---|---|
| `A_company_and_number` | Link contains both the company name and the people count (e.g. `.../visa-to-cut-2-600-jobs...`) |
| `B_official_warn` | Link is an official government / WARN notice page |
| `C_company_only` | Link contains the company name but not the number |
| `D_unclear` | Link contains neither |

In addition, links to generic aggregator pages (`layoff-tracker`, `major-employers-job-cuts`, `intellizence` etc.) were flagged with `generic_source = True`. **It later turned out that most wrong rows came from such aggregator pages.** The home pages of state WARN lists (e.g. `edd.ca.gov/.../Layoff_Services_WARN`) are not row-specific either and also count as generic; generic rows that were not checked manually go to T5 (see §13).

---

## 4. Manual verification: which rows were checked, and why?

Instead of checking all 653 rows, the **materiality** approach used by professional auditors was applied: the rows that influence the result most are always checked, the rest by sampling.

In total **146 rows** were compared one by one with news sources:

| Group | Why? | Rows |
|---|---|---|
| 1. **All** rows above 3,000 people | A few giant rows make up most of the total; if one is wrong, the result changes | ~50 |
| 2. **All** rows labelled "AI-DRIVEN" | The main research question depends on this label | ~90 |
| 3. A **stratified random sample of 20** smaller rows | To see whether small rows contain systematic errors | 20 |
| 4. Rows whose URL number differs from the data (11 Nov audit) | A meaningful difference came out of an automatic scan | 2 |
| 5. Non-AI rows whose URL mentions AI (11 Nov) | Is there a missed AI label? | 1 (Comcast; not AI) |

(The groups overlap; e.g. Barclays is both a large row and an AI row.)

**Method:** for every row, a news search with company + number + month; the number, date and reason in the article were compared with the data. Each finding and source link was written to `verification_log.csv`.

### 4.1 Verification results

| Status | Meaning | Rows |
|---|---|---|
| `verified` | Number, date and reason match the article | 104 |
| `corrected` | The article gives a different number; corrected according to the source | 2 |
| `partial` | The event is right but the number is "up to", a plan, voluntary retirement, or could not be confirmed | 27 |
| `invalid` | The announcement is not from 2026 (earlier year) → excluded | 4 |
| `mismatch` | The number in the article contradicts the data | 1 |
| `not_found` | No source could be found | 8 |

### 4.2 Errors found and what was done

**Wrong year (excluded from the analysis):**
| Company | In the data | Actually |
|---|---|---|
| Intel | 15,000 | August 2024 announcement |
| Nestlé | 16,000 | October 2025 announcement |
| Nokia | 14,000 | October 2023 announcement |
| CrowdStrike | 500 | May 2025 announcement |

**Numbers corrected according to the source** (the original value is kept in `people_cut_original`):
| Company | In the data | Corrected | Reason |
|---|---|---|---|
| Verizon | 3,000 | 500 | News reports 500 corporate layoffs; ~2,500 store employees move to another company with a store sale |
| Commerzbank | 6,900 | 3,000 | May 2026 reports say 3,000 |

**Number mismatch:** Apple 147 → the article says "400+ positions". The row was kept and flagged.

### 4.3 AI rows
- **90 of the 92 AI rows** in the main analysis were fully or partially verified.
- 2 (Skai, Rapyd) could not be found.
- The **numerator of the AI share (cuts attributed to AI) is therefore verified row by row**.

### 4.4 Random sample
**None** of the 20 small rows was wrong; 16 were fully or partially verified, 4 could not be found because they are small local events. This suggests there is no systematic problem in the small rows.

### 4.5 My own mistakes, corrected (for transparency)
- **Volkswagen:** at first I treated the 31,000 and 19,000 rows as duplicates. Checking showed they are two parts of the 50,000 plan of March 2026, while the 50,000 in September is a separate, new announcement. The flag was removed.
- **"Large companies are the ones citing AI":** I had reached this conclusion earlier; the robustness check (§7) showed it does not hold. The claim was dropped from the project.

---

## 5. Label problems: is the AI label always right?

"AI-DRIVEN" is layoffhedge's own classification. Verification revealed two kinds of problems:

**Questionable AI label** (`ai_label_questionable = True`) — the article gives another main reason:
| Company | Why questionable |
|---|---|
| UPS 30,000 | Main reason is the reduction of Amazon volume |
| Dell 11,000 | Not an announcement; headcount fell in the annual report |
| HDFC Bank 3,343 | Not an announcement; headcount fell during the fiscal year |
| HubSpot 660 | The CEO explicitly denies the cut is AI-driven |
| Uber 340 | Cut in the HR unit; no AI reason in the reports |
| Southern Cross Media 200 | Main reason is falling TV advertising revenue |
| Wells Fargo 112 | WARN notice; no AI reason |

**Missing AI label** (`ai_label_missing = True`) — the article cites AI but the label is "RESTRUCTURE":
Envato 200, United Internet 800.

**Number is an upper bound** (`is_upper_bound = True`) — "up to …" or a plan that is not final:
Oracle 30,000, HSBC 20,000, Meta 16,000, Cognizant 15,000, Microsoft 8,750 (voluntary retirement), Heineken 6,000, Amdocs 2,500, Wix 1,000, Thomson Reuters 500, Groupon 400, Gemini 200, Southern Cross Media 200, The Telegraph 100.

**Decision:** these rows were not deleted. The AI share is reported in two ways:
- **Strict definition** (`is_ai_strict`: questionable and upper-bound rows excluded) → headline
- **Broad definition** (`is_ai_driven`: all AI labels) → upper bound only

---

## 6. Cleaning principle: "flag, don't delete"

No row was deleted. Instead, quality columns were added to every row. As a result:
- The analyst can show which rows were left out and why.
- Results can be recomputed with different filters (the robustness check relies on this).

**Main-analysis filter:**
```python
in_main_analysis = ~is_undated & ~is_invalid
```
→ of 653 rows, **643 rows and 653,456 people** enter the main analysis (6 rows with unknown month + 4 invalid rows are out).

### 6.1 Reliability tiers (`reliability_tier`)
Every row gets exactly one reliability label:

| Tier | Meaning | Rows | Share of people |
|---|---|---|---|
| `T1_manual_verified` | Manually verified / corrected | 106 | 47.2% |
| `T2_manual_partial` | Manually, partially verified | 27 | 25.0% |
| `T3_strong_source` | Not checked manually, but the link contains company + number or is a row-specific official WARN page | 180 | 9.3% |
| `T4_medium_source` | Link contains only the company | 186 | 11.1% |
| `T5_weak_source` | Generic page / aggregator / WARN list home page | 144 | 7.3% |
| `X_invalid` | Wrong year | 4 | outside the analysis |
| `X_multi_year_plan` | Multi-year plan | 3 | outside the analysis |
| `X_month_unknown` | Only "2026" given, no month | 3 | outside the analysis |

**Summary:** **72%** of the people in the main analysis were checked manually; **81.6%** are in the T1–T3 "verified core".

---

## 7. Robustness check

**Question:** do my findings stay the same if I drop the questionable part of the data?

The main findings were recomputed at three data levels:
1. All main-analysis rows (T1–T5)
2. Verified core (T1–T3)
3. Manually checked only (T1–T2)

| Finding | All rows | Core (T1–T3) | Manual only (T1–T2) | Result |
|---|---|---|---|---|
| Top 3 industries | Automotive & Transportation, Tech, Finance & Banking | Same | Same | ✅ Robust |
| AI people share, Jan–Apr mean — strict (broad) | 18.2% (57.3%) | 22.3% (69.9%) | 23.4% (74.1%) | ✅ Higher at every level |
| AI people share, Jun–Sep mean — strict (broad) | 5.2% (8.0%) | 6.6% (9.9%) | 13.0% (16.8%) | ✅ Lower at every level |
| AI announcements cover more people (median, strict) | 295 vs 180 | 320 vs 200 | — | ✅ Same direction |
| Large companies are the ones citing AI | No | — | — | ❌ Does not hold, not used |

**Headline AI share (all rows):**
- Strict definition: about **16.9%** of the people in announced job cuts are attributed to AI.
- Broad definition: 38.4% (depends on a few giant plans → upper bound only).

**Caution:** manual verification covered every AI row, so AI rows are over-represented at the T1–T2 level (selection effect). The AI share at that level is therefore not used as a headline. The point of the robustness check is not the share itself, but that **the direction and the ranking** stay the same at every level.

---

## 8. Preparing the Indeed AI posting data

`indeed_ai_posting.csv` (25,470 rows) was checked:
- Columns: `date`, `jobcountry`, `AI_share_postings`
- Countries: Australia, Canada, Germany, France, United Kingdom, Ireland, Italy, Netherlands, United States. **No Turkey.**
- No missing days (2,830 days per country, 2019-01-01 to 2026-09-30).

**What `clean_ai_posting.py` does:**
1. Daily data → country × month mean.
2. Change versus the same month one year earlier (`yoy_change_pt`, percentage points).
3. **Canada warning:** from 1 January 2026, Ontario requires job postings to disclose the use of AI in hiring. The jump in Canada therefore comes from the law, not from AI-skill demand. From October 2025, Canadian rows are flagged `comparable = False`.

**Headline trend (Sep 2025 → Sep 2026):**
- United States: 3.6% → 7.2%
- United Kingdom: 4.9% → 9.8%

**Joining the data sets:** layoffhedge has no country column and Indeed has no Turkey. The two are therefore joined **by month**; on the hiring side the US series is used, and the common window is January–September 2026.

---

## 9. Output files

| File | Content |
|---|---|
| `layoffs_clean.csv` | 653 rows, clean data with all quality columns |
| `layoffs_clean_monthly.csv` | Monthly summary of the main analysis (announcements, people, median; AI people share and announcement share, strict + broad) |
| `layoffs_clean_industries.csv` | Industry summary (median workforce %, AI share strict + broad, median people) |
| `verification_log.csv` | 146 manually verified rows: status, finding, source link |
| `robustness_check.csv` | Robustness check table |
| `ai_posting_monthly.csv` | Indeed data as a country × month table |
| `challenger_ai_monthly.csv` | Challenger Jan–Oct 2026: monthly total, AI cuts, AI share, YTD, source, note |
| `challenger_vs_layoffhedge.csv` | Challenger AI share next to the layoffhedge AI shares, by month |
| `statistical_tests.csv` | Bootstrap confidence intervals, Mann-Whitney, permutation, split-month and missed-label sensitivity |

### 9.1 `layoffs_clean.csv` column dictionary

| Column | Description |
|---|---|
| `company`, `industry` | Company, industry |
| `people_cut` | Announced number of people (after correction) |
| `people_cut_original` | Original number in the source |
| `is_corrected` | Was the number corrected according to the source? |
| `workforce_pct`, `total_workforce` | Share of workforce, total workforce |
| `announce_date`, `month` | Announcement date (2026), month (YYYY-MM) |
| `date_precision` | `day` / `month` / `year_only` / `multi_year` |
| `category`, `is_ai_driven` | The site's reason category; is it AI-DRIVEN? (broad definition) |
| `is_ai_strict` | Strict AI definition: AI-DRIVEN, label not questionable, number not an upper bound (**headline**) |
| `source_url` | Source link |
| `in_main_analysis` | Part of the main analysis? |
| `in_core_verified` | In the T1–T3 core? |
| `reliability_tier` | Reliability tier (T1–T5, X) |
| `verification`, `verification_note` | Manual verification status and note |
| `auto_source_level` | Automatic link score (A/B/C/D) |
| `is_invalid` | Invalid (wrong year)? |
| `is_multi_year` | Undated multi-year plan? |
| `is_undated` | Month unknown? (`multi_year` or `year_only`) |
| `is_upper_bound` | Is the number "up to …"? |
| `ai_label_questionable` | Is the AI label questionable? |
| `ai_label_missing` | Is the AI label missing? |
| `generic_source` | Is the link a generic aggregator page? |
| `needs_check` | Not checked manually and weak signals? |
| `date_mismatch` | Does the date in the link differ from the data by 2+ months? |
| `is_partial_month` | November 2026 (partial month)? |
| `date_raw` | Original date text |

---

## 10. How to run

```bash
# All scripts run without arguments: they read data/raw and write data/clean
# (from any working directory)

# 1) Clean and verify the layoff data
python3 python/clean_layoffs.py

# 2) Robustness check
python3 python/robustness_check.py

# 3) Indeed data -> monthly table
python3 python/clean_ai_posting.py

# 4) Build the Challenger table and compare with layoffhedge (after step 1)
python3 python/build_challenger.py

# 5) Statistical tests (bootstrap, Mann-Whitney, permutation, sensitivity)
python3 python/statistical_tests.py
```

```bash
# 6) PostgreSQL: create the database once, then run the 4 files in order (from the project root)
createdb -U postgres ai_is_piyasasi
for f in sql/0*.sql; do psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f "$f"; done
```

Required libraries: `pandas`, `numpy`, `scipy`

Manual verification results live in dictionaries inside `clean_layoffs.py`. When a new row is verified, it is added to these dictionaries and the script is run again:
- `VERIFICATION` → (company, people) : (status, finding, source)
- `CORRECTIONS` → (company, raw number) : corrected number
- `UPPER_BOUND`, `AI_LABEL_QUESTIONABLE`, `AI_LABEL_MISSING` → flag lists

---

## 11. Limitations

- The data only contains cuts that were announced publicly and reached the news; small companies are under-represented.
- There is no country column; no country-level analysis is possible.
- `total_workforce` is the site's estimate and can differ between rows of the same company; it is not summed by industry.
- The monthly AI people share can jump with a single giant announcement. E.g. in October 2026 the 50.5% is driven by the Dutch Government's 25,000 plan, spread until 2035 (the announcement-count share for the same month is 5.3%). Monthly values are therefore shown with the **announcement-count share, period means and medians**.
- The site seems to have collected more small announcements in recent months; comparisons of monthly announcement **counts** should be read with care.
- November 2026 is a partial month (data until 6 November).
- Indeed measures the "share of postings mentioning AI"; it does not mean AI is creating or destroying jobs.
- **Different scopes:** layoffhedge = global (no country column) · Indeed = 9 countries (no Turkey) · Challenger = US only. Cross-source comparisons are **confirmations of direction**; they do not measure the same population.
- **No seniority information:** none of the data sets distinguishes junior/senior roles. The junior section is an **interpretation**, not a finding.
- **Asymmetric verification:** every AI-labelled row but only 50 non-AI rows were checked manually. Measured (`statistical_tests.py`, test 5): the missed-label rate among checked rows is 4% (2/50); applying it to the 502 unchecked rows raises the strict AI share from 16.9% to at most ~18.1%. All non-AI URLs were also scanned for AI keywords; no new missed label was found (the Comcast candidate was checked: not AI).
- **Narrow Indeed metric:** "posting mentions AI" ≠ AI-skill demand. Postings of companies selling AI products and "we use AI in hiring" disclosures are counted too (the Canada law effect proves it).
- **Limited statistical power:** 10-month time series; correlations confirm direction. The headline AI share (16.9%) depends on a few giant rows: 95% CI 8.8–27.5%. The announcement-count share is more stable (11.5%; CI 9.0–14.0%).

---

## 12. Next steps

1. ~~Challenger table~~ ✅ (§14)
2. ~~PostgreSQL~~ ✅ (§15)
3. ~~Python notebook~~ ✅ `notebooks/analysis.ipynb` (9 charts in `notebooks/figures/`)
4. **Power BI (4 pages):** Overview · AI narrative · Hiring side · Data reliability.
5. **README + Medium post:** findings, charts and the data-quality section.

---

## 13. Additional audit (11 November 2026) — problems found and fixes

Before moving on to the analysis, every number was recomputed from scratch and the script logic was checked line by line.

**What was correct:** 643 rows / 653,456 people, 16.9% and 38.4%, tier shares; every (company, people) key in the verification dictionaries matches the data; the differences with the site's monthly summary come exactly from our corrections (January −15,000 Intel, February −16,500 Nestlé + CrowdStrike, March −14,000 Nokia, May −3,900 Commerzbank, July −2,500 Verizon); the Indeed data has no missing days.

| # | Problem | Why it matters | Fix |
|---|---|---|---|
| 1 | The headline AI share (16.9%) used the strict definition, but the period means (57% / 8%) and industry AI shares used the broad one | The two definitions were mixed; the 57% came mostly from questionable / upper-bound giant rows (strict: March 61.5% → 1.5%) | `is_ai_strict` column added; every output uses strict as headline, broad as `_upper` next to it |
| 2 | The monthly AI share was people-based only | A single giant announcement drives a month (October: Dutch Government) | Announcement-count share added (`ai_strict_count_share_pct`); better suited to the Challenger comparison |
| 3 | The "weighted workforce %" in the industry table summed `total_workforce` row by row | The same company was counted several times (Amazon 7 times); for 21 companies the total workforce differs between rows | Metric removed, replaced by `median_workforce_pct` |
| 4 | URL number differs from the data: Gilead 192 (URL "108"), Capital One 1,100 (URL "1,700") | Possible wrong number | Checked manually, the data is right: Gilead 108 + 84 = 192 (headline updated later); Capital One WARN 1,139, 1,700 is cumulative |
| 5 | 42 rows linking to generic WARN home pages were in T3 | The tier rule did not use the `generic_source` flag; it contradicted the definition "T5 = generic page" | Generic rows not checked manually moved to T5 (T1–T3 share 82.5% → 81.6%) |
| 6 | 3 rows saying only "2026" were labelled "multi-year plan" | Wrong label (the year is known, the month is not) | New `year_only` / `X_month_unknown` label; `is_undated` filter. The main analysis did not change |
| 7 | Scripts expected old file names and wrote into the current directory | Reproducibility | Default paths `data/raw` → `data/clean` |

The Indeed output was identical after this audit. The raw data was not touched.

---

## 14. Challenger cross-check table (11 November 2026)

**Why:** layoffhedge is a little-known source. We wanted to compare the AI share over time with the independent source most quoted in the media (Challenger, Gray & Christmas).

**How it was collected:** for January–October 2026, two figures were taken from each month's report (or from the news coverage of that report): total announced US job cuts and AI-attributed cuts. Figures and source links live in `build_challenger.py`.

**How it was verified:** every Challenger report also gives year-to-date (YTD) totals. The script adds up the monthly figures and compares them with these YTD values (7 AI + 4 total checkpoints); if one does not match, it stops with an error. All matched.
- The January AI figure was not found directly; it was derived as February YTD (12,304) − February (4,680) = 7,624.
- One article gives "7,000" for September; it does not fit the YTD chain and was not used. The correct value is 3,961.

| Month | Total | AI | AI share |
|---|---|---|---|
| Jan | 108,435 | 7,624 | 7.0% |
| Feb | 48,307 | 4,680 | 9.7% |
| Mar | 60,620 | 15,341 | 25.3% |
| Apr | 83,387 | 21,490 | 25.8% |
| May | 97,006 | 38,579 | **39.8%** |
| Jun | 45,849 | 14,029 | 30.6% |
| Jul | 33,429 | 10,970 | 32.8% |
| Aug | 52,881 | 3,462 | 6.5% |
| Sep | 43,281 | 3,961 | 9.2% |
| Oct | 43,994 | 1,265 | **2.9%** |
| **Total** | **617,189** | **121,401** | **19.7%** |

**Result:** Challenger's monthly AI share moves in the same direction as the layoffhedge AI **announcement-count** share (Pearson 0.72; Jan–Jul → Aug–Oct: Challenger 24.4% → 6.2%, layoffhedge 19.5% → 3.6%). It does not track the layoffhedge **people** share (−0.20), because that share depends on a few giant announcements. This also shows why adding the count share in §13 was necessary. In a 10-month series, the correlation only confirms direction.

---

## 15. PostgreSQL layer (11 November 2026)

**Why:** the data is small and pandas would have been enough. The SQL layer was added to make the calculations transparent and reproducible, to give Power BI a proper star schema, and to show that two independent paths (Python + SQL) reach the same numbers.

**Database:** `ai_is_piyasasi` (PostgreSQL 18). Dedicated to this project; no other database was touched.

| File | What it does | Why |
|---|---|---|
| `01_schema.sql` | Creates staging (exact copy of the CSVs), dimension (`dim_company`, `dim_industry`, `dim_date`, `dim_country`) and fact (`fact_layoffs`, `fact_ai_postings`, `fact_challenger`) tables | Separates raw loading from the analysis structure; a star schema makes Power BI filters work correctly |
| `02_load.sql` | `\copy` CSV → staging, then staging → dimensions/facts; row-loss check | Transformations are visible in SQL; the file is re-runnable |
| `03_analysis.sql` | Views for the 5 questions + combined table + data quality | Power BI reads the same views → every number is computed in one place |
| `04_checks.sql` | Compares 41 numbers with the Python results | Python and SQL must agree; any mismatch raises an error |

**Design decisions:**
- `date_key` = YYYYMMDD. Monthly data (Indeed, Challenger) is linked to the 1st day of the month, so the three data sets join on one `dim_date` at month level. `dim_date` starts in 2019 because Indeed starts in 2019.
- `total_workforce` lives in the fact table, not the company table: it differs between rows for 21 companies.
- The 6 rows with unknown month have `date_key` NULL; they are not deleted, `in_main_analysis = FALSE`.
- CHECK rules make the data rules permanent: strict AI ⇒ AI-labelled; a strict AI row cannot be questionable / upper bound; a main-analysis row must have a date; people ≤ total workforce; percentages 0–100; allowed values for tiers and verification status. Tested with deliberately wrong rows: rejected.

**Result:** 653 / 837 / 10 rows loaded without loss; 41/41 checks equal to Python.

**Additional observations from SQL:**
- The "broad only" AI rows (questionable label or upper bound, 18 rows) are very large: median 1,750 people (strict AI 295, non-AI 180). These giant rows are what inflate the broad definition.
- Government & Nonprofit (7 announcements) and Energy (2) are flagged `small_sample` in the industry AI share; a single announcement decides the share.
- In Jan–Sep 2026 the Indeed US share of postings mentioning AI keeps rising (4.6% → 7.2%) while the layoffhedge AI announcement share falls (correlation −0.38). The two trends are shown side by side; no causal claim is made.

---

## 16. Fixes after an external review (11 November 2026)

The project was reviewed from the perspective of a hiring manager; the 7 weak points found and what was done:

| # | Weak point | What was done |
|---|---|---|
| 1 | The junior conclusion is not supported by the data (no seniority information) | Rewritten as "what the data suggests", explicitly labelled as interpretation; limitation added |
| 2 | The sources have different scopes (global / 9 countries / US) | Written explicitly as a limitation; comparisons called "confirmation of direction" |
| 3 | Verification is asymmetric | Measured: non-AI URLs scanned (no new missed label, Comcast checked); sensitivity analysis: worst case 16.9% → ~18.1% |
| 4 | Little statistical weight | `statistical_tests.py`: bootstrap CIs, Mann-Whitney, permutation test, split-month sensitivity (see DATA_QUALITY.md §7) |
| 5 | The Indeed metric must be read narrowly | "AI demand / AI-skill demand" replaced by "share of job postings mentioning AI"; limitation added |
| 6 | No git/GitHub | Git repository created; GitHub-facing content translated to English |
| 7 | Being able to defend the project | A personal interview-preparation file (kept locally, not published): likely questions, answers and a self-test list |

---

## The project in one sentence (interview)

> "I validated data from a little-known source by materiality: I compared every large row and every AI-labelled row with news sources one by one, sampled the small rows at random, found 4 wrong-year rows and 2 wrong numbers, and then showed with a robustness check that my findings hold when the questionable rows are removed."
