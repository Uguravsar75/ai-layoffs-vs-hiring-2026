# Project Plan — AI Layoffs vs. Hiring (2026)
**Uğur Avşar · Softito Data Analytics-2 capstone project · Due: 13 November 2026**

> Single source of truth for whoever continues the project.

---

## 1. Summary
**Question:** How often did companies cite AI when announcing job cuts in 2026, how did that change over time, and how did the share of job postings mentioning AI move in the same period?

**Core idea:** Show the gap between *what companies say* (AI-attributed layoff announcements) and *what the data shows* (the actual distribution of cuts + the hiring side).

**Scope:** Pure data analytics. NO machine learning. Tools: Python (pandas, numpy, scipy) → PostgreSQL → Power BI.

**Wording rule:** "announced job cuts", NOT "jobs lost". NO causal claims; the two trends are shown side by side.

---

## 2. Folder structure
```
ai-layoffs-vs-hiring-2026/
├── data/
│   ├── raw/              ← original downloads (NEVER modified)
│   └── clean/            ← outputs of the Python scripts
├── python/               ← clean_layoffs.py, clean_ai_posting.py, build_challenger.py,
│                           robustness_check.py, statistical_tests.py
├── sql/                  ← 01_schema.sql, 02_load.sql, 03_analysis.sql, 04_checks.sql, 05_export_powerbi.sql
├── notebooks/            ← analysis.ipynb + figures/ (PNG charts)
├── powerbi/              ← data/ (CSV export for Power BI), dashboard.pbix + screenshots (png)
├── docs/                 ← PROJECT_PLAN.md, PROCESS.md, DATA_QUALITY.md,
│                           (+ a personal interview-prep file, kept locally)
└── README.md             ← the showcase (written last)
```

---

## 3. Data sets (FINAL — 3 in total)

| # | Data | File | Role | Status |
|---|---|---|---|---|
| 1 | layoffhedge.com 2026 layoffs (version of 8 Nov 2026) | raw/layoffs_2026.csv → clean/layoffs_clean.csv | Main data (global) | ✅ Clean, verified |
| 2 | Indeed Hiring Lab AI Tracker (CC-BY-4.0) | raw/indeed_ai_posting.csv → clean/ai_posting_monthly.csv | Main data (hiring side) | ✅ Clean |
| 3 | Challenger, Gray & Christmas monthly reports | clean/challenger_ai_monthly.csv | Independent check for the US | ✅ Ready |

Auxiliary (not counted as a data set): raw/layoffs_monthly_2026.csv, raw/layoffs_industries_2026.csv → only used to reconcile our own totals.

**Set-up:**
- layoffhedge = global; share of cuts where companies cite AI
- Indeed = US main series + GB, DE, FR, NL, IE, IT, AU for comparison. Canada `comparable=False` (Ontario disclosure law). No Turkey → limitation.
- Challenger = US AI-attributed cuts; confirms the **direction** of the layoffhedge AI share.
- Common window: **Jan–Sep 2026** (Indeed ends in September). Joins are **monthly**.

---

## 4. Done ✅
- Raw data inspected (CSV has `#` comment lines, comma separator → `pd.read_csv(..., comment="#")`).
- Automatic checks on all 653 rows: no blanks / duplicates / logic errors; year-less dates set to 2026; 6 undated rows (3 multi-year plans + 3 "2026" only) excluded.
- 146 rows verified manually (all rows with 3,000+ people, all AI rows, a stratified random sample of 20, 2 rows whose URL number differs, 1 non-AI row whose URL mentions AI):
  - 4 wrong-year rows excluded (Intel, Nestlé, Nokia, CrowdStrike)
  - 2 numbers corrected (Verizon 3,000 → 500, Commerzbank 6,900 → 3,000)
- Reliability tiers T1–T5, X. 72% of people manually checked, 81.6% in T1–T3.
- Robustness check: industry ranking and the decline of the AI share hold at every level.
- Indeed converted to a monthly table.
- 2026-11-11 audit (see PROCESS.md §13): AI share switched to the strict definition everywhere (`is_ai_strict`), announcement-count share added, wrong "weighted workforce %" removed, generic WARN links moved to T5, Gilead and Capital One verified.
- 2026-11-11 external review (see PROCESS.md §16): junior conclusion reframed, limitations added, statistical tests, git, interview preparation.

**Filter for the analysis:** `in_main_analysis = True` (643 rows, 653,456 people)

---

## 5. Final findings (these are the numbers — do not change)
**Rule:** the AI share is always given with the **strict definition** (`is_ai_strict`); the broad definition is only shown next to it as an "upper bound". The two are never mixed.

| Finding | Strict (HEADLINE) | Broad (upper bound) |
|---|---|---|
| Top 3 industries (people) | Automotive & Transportation, Tech, Finance & Banking | — |
| AI share – people, full year | **16.9%** (95% CI 8.8–27.5) | 38.4% (CI 24.0–52.0) |
| AI share – announcements, full year | **11.5%** (CI 9.0–14.0) | 14.3% |
| AI people share, Jan–Apr mean | **18.2%** | 57.3% |
| AI people share, Jun–Sep mean | **5.2%** | 8.0% |
| AI announcement share (monthly) | Jan–Jul **8–20%** (peak **May 40%**), Aug–Nov **3–6%** | — |
| Median people per AI announcement | **295** vs non-AI 180 (difference 115, CI 50–421; Mann-Whitney p < 0.001) | 375 vs 180 |
| Challenger (US) cross-check | Same direction as the count share, Pearson **0.72** (permutation p ≈ 0.006; the decline appears for any split month from June to September). Jan–Jul → Aug–Oct: Challenger 24.4% → 6.2%; layoffhedge count share 19.5% → 3.6% | Does not track the people share (−0.20) |
| AI people share by industry | Finance 32.7% · Tech 21.0% · Automotive 1.0% | Tech 75.3% · Finance 65.7% |

| Other | Value |
|---|---|
| Indeed share of postings mentioning AI (Sep 2025 → Sep 2026) | US 3.6% → 7.2% · GB 4.9% → 9.8% |
| Claim NOT to be used | "Large companies are the ones citing AI" (not robust) |

Warning: the October 2026 AI **people** share (50.5%) depends on one plan (Dutch Government, 25,000, spread until 2035; outside the US). The **announcement-count** share for the same month is 5.3%. The monthly trend therefore always shows both measures; for the comparison with Challenger (US), the count share is the right one.

---

## 6. The 5 research questions
1. Which industries announced the most job cuts in 2026?
2. In which industries was AI cited more often?
3. How did the share of AI as a stated reason change month by month? (+ Challenger cross-check)
4. Do AI-attributed announcements cover more people?
5. How did the share of job postings mentioning AI change in the same period?

**Conclusion — "what the data suggests for junior candidates" (INTERPRETATION, not a finding):** while AI as a stated reason for job cuts declined during the year, the share of job postings mentioning AI doubled in a year. These two trends **suggest** that, for job seekers, AI shows up less as a *layoff threat* and more as a *job-posting requirement*. The data has no seniority information; junior roles were not measured separately. This section is always presented with that caveat.

**Phrases NOT to use:** "AI-skill demand" (correct: "share of job postings mentioning AI"), "junior jobs are disappearing", "AI is taking jobs".

---

## 7. TO DO (in order)

### Step 1 — Challenger cross-check table ✅
- Script: `python/build_challenger.py` (figures and sources live in the script; monthly totals are checked automatically against Challenger's own YTD figures at 11 checkpoints).
- Outputs: `data/clean/challenger_ai_monthly.csv` (10 rows, each with source and note), `data/clean/challenger_vs_layoffhedge.csv`.
- Challenger AI share: Jan 7.0% · Feb 9.7% · Mar 25.3% · Apr 25.8% · **May 39.8%** · Jun 30.6% · Jul 32.8% · Aug 6.5% · Sep 9.2% · **Oct 2.9%**. Total: 121,401 / 617,189 = 19.7%.
- **Result:** Challenger tracks the layoffhedge **announcement-count share** (Pearson 0.72), **not the people share** (−0.20), because the people share depends on giant announcements (March: Oracle/Meta/HSBC upper bounds; October: Dutch Government, outside the US).
- Split month = August: the month in which AI loses its 5-month first place in Challenger (the independent source's break point). The result does not depend on this choice (statistical_tests.py, test 3).
- Caveat: n = 10 months; the correlation confirms direction, it is not proof. Challenger = US, layoffhedge = global.

### Step 2 — PostgreSQL ✅
Database: `ai_is_piyasasi` (PostgreSQL 18, localhost)
- `01_schema.sql`: 3 staging + 4 dimensions (`dim_company`, `dim_industry`, `dim_date` [2019–2026, daily, `date_key` = YYYYMMDD], `dim_country`) + 3 facts (`fact_layoffs`, `fact_ai_postings`, `fact_challenger`). `total_workforce` lives in the fact table (it differs between rows for 21 companies). CHECK rules (e.g. `is_ai_strict` ⇒ `is_ai_driven`, people ≤ total workforce) reject bad rows (tested).
- `02_load.sql`: CSV → staging → dimensions/facts; row-loss check. Re-runnable.
- `03_analysis.sql`: views read by Power BI: `v_kpi`, `v_q1_sector_totals`, `v_q2_sector_ai`, `v_q3_monthly_ai` (`LAG()`, 3-month moving average), `v_q4_median` (`PERCENTILE_CONT`), `v_q5_indeed`, `v_combined_monthly` (CTE), `v_combined_corr` (`CORR()`), `v_quality_tiers`.
- `04_checks.sql`: 41 numbers compared with Python → **41/41 OK**; raises an error on any mismatch.
- Extra findings: 561 companies in the main analysis; the 18 "broad only" AI rows (questionable / upper bound) have a median of 1,750 people → these giant rows inflate the broad definition. Indeed US vs layoffhedge count share move in opposite directions in Jan–Sep (−0.38). Shown side by side, no causal claim.
- Run (from the project root): `for f in sql/0*.sql; do psql -U postgres -d ai_is_piyasasi -v ON_ERROR_STOP=1 -f "$f"; done`

### Step 3 — Python notebook (EDA + charts) ✅
- `notebooks/analysis.ipynb`: one section per question (question → code → chart → 2–3 sentences of interpretation), executed with all outputs. 9 charts saved to `notebooks/figures/` for the README and the Medium post.
- Chart rules: one y-axis per chart (two measures of different scale → two panels), emphasis (highlight one series, grey the rest), validated categorical palette in fixed order, source note under every chart, a table under every chart.

### Step 4 — Power BI 📊 (4 pages) ⏳
- Power BI Desktop is Windows-only. Either connect to PostgreSQL (*Get data → PostgreSQL*, server `localhost`, database `ai_is_piyasasi`) or import CSV exports of the `v_*` views. Relationships via `date_key`, `company_id`, `industry_id`, `country_code`.
1. **Overview:** KPI cards (announcements, people, companies, AI share 16.9%), monthly trend, industry bar chart
2. **AI narrative:** monthly AI share line (layoffhedge people share + count share vs Challenger), AI share by industry, AI vs non-AI median
3. **Hiring side:** Indeed share of postings mentioning AI (US highlighted, other countries grey), year-over-year change; Canada annotated
4. **Data reliability:** tier distribution (T1–T5), verification results, strict vs broad AI share
- Filters: month, industry, reliability tier, "strict AI definition only"
- Source note on every page. Save screenshots to `powerbi/`.

### Step 5 — README + Medium + LinkedIn 📝 ⏳
- `README.md`: title, one-sentence question, 3–4 key findings, dashboard image, data sources, method, data-quality section (from DATA_QUALITY.md), limitations, how to run.
- `docs/medium_post.md`: "Is AI Taking Jobs, or Did Only the Narrative Change?" — short, 3–4 charts, plain language.
- LinkedIn post: 4–5 sentences + dashboard image.

### Step 6 — Final check ✔️ ⏳
- Are all numbers identical in SQL, Power BI and README?
- Are sources credited (layoffhedge, Indeed CC-BY, Challenger)?
- Is the raw data unchanged?
- Does the phrase "jobs lost" appear anywhere?

---

## 8. Limitations (to go into the README)
- Only announced cuts that reached the news; small companies are under-represented.
- layoffhedge has no country column; no country-level analysis is possible.
- The monthly AI people share can jump with a single giant announcement.
- November 2026 is a partial month (data until 6 Nov).
- Indeed measures the "share of postings mentioning AI"; it does not mean jobs are being created.
- The two trends are shown side by side; no causal claim is made.
- **Different scopes:** layoffhedge = global (no country column) · Indeed = 9 countries (no Turkey) · Challenger = US only. Cross-source comparisons are therefore **confirmations of direction**; they do not measure the same population. Say this explicitly in the presentation.
- **No seniority information:** none of the data sets distinguishes junior/senior roles. The junior section is an **interpretation**, not a finding.
- **Asymmetric verification:** every AI-labelled row but only 50 non-AI rows were checked manually, so missed AI labels could make the headline too low. Measured (`statistical_tests.py`, test 5): the missed-label rate among checked rows is 4% (2/50); applying it to the 502 unchecked rows raises the strict AI share from 16.9% to at most ~18.1%. All non-AI URLs were also scanned for AI keywords; no new missed label was found (the Comcast candidate was checked: not AI).
- **Narrow Indeed metric:** "posting mentions AI" ≠ AI-skill demand. Postings of companies selling AI products and "we use AI in hiring" disclosures are counted too (the Canada law effect proves it). Correct wording: "share of postings mentioning AI".
- **Limited statistical power:** 10-month time series; correlations confirm direction. The headline AI share (16.9%) depends on a few giant rows: 95% CI 8.8–27.5%. The announcement-count share is more stable (11.5%; CI 9.0–14.0%).

---

## 9. Interview sentence
> "I validated data from a little-known source by materiality: I compared every large row and every AI-labelled row with news sources, sampled the small rows at random, found 4 wrong-year rows and 2 wrong numbers, and then showed with a robustness check that my findings hold when the questionable rows are removed."
