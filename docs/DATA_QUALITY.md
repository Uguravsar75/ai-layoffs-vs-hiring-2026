# Data Quality and Validation

The main data set of this project is the 2026 layoff list of layoffhedge.com (653 rows, version of 8 November 2026). Because the source is little known and does not document its method, the data was checked in three steps before any analysis: **verification by materiality, sampling, and robustness testing**.

## 1. Automatic checks (all 653 rows)
- No blank cells, no duplicate rows, no logic errors (people cut > total workforce).
- The "Workforce %" column matches people cut / total workforce exactly.
- The date column has no year ("Oct 13"); all dates were read as 2026. For 6 rows the month is unknown: 3 contain a year range ("2025-30", a multi-year plan) and 3 only say "2026". These 6 rows are excluded from the main analysis.
- Every source link was scored automatically: does it contain the company name and the people count, is it an official WARN notice, or is it a generic aggregator page?
- Rows whose URL contains a number different from the data were scanned; the 2 rows with a meaningful difference (Gilead, Capital One) were checked manually and the data was correct (the links contained an outdated headline / a cumulative total).

## 2. Manual verification (146 rows)
Five groups of rows were compared one by one with news sources:
1. **All rows with more than 3,000 people** (the rows that drive the totals),
2. **All rows labelled "AI-DRIVEN"** (the main research question depends on this label),
3. **A stratified random sample of 20 rows below 3,000,**
4. **2 rows whose URL number differs from the data,**
5. **1 non-AI row whose URL mentions AI** (Comcast; the reason turned out not to be AI).

| Result | Rows |
|---|---|
| Verified | 104 |
| Corrected according to the source | 2 (Verizon 3,000 → 500, Commerzbank 6,900 → 3,000) |
| Partially verified (plan, "up to", voluntary retirement, number not confirmed, etc.) | 27 |
| Invalid, excluded (announcements from earlier years) | 4 (Intel 2024, Nestlé 2025, Nokia 2023, CrowdStrike 2025) |
| Number mismatch | 1 (Apple 147) |
| Not found | 8 |

The finding and source for every row is in `data/clean/verification_log.csv`.

**AI rows:** of the 92 AI-DRIVEN rows in the main analysis, **90 were fully or partially verified**; 2 (Skai, Rapyd) could not be found. One more row (CrowdStrike) turned out to be a 2025 announcement and was excluded. The **numerator of the AI share (cuts attributed to AI) is therefore verified row by row**.

**Observations**
- Most wrong rows come from aggregator sites of the "biggest layoffs of 2026" type. Wrong years are rare for links that point directly to a news article.
- The random sample (20 small rows) contained no wrong row; 16 were fully or partially verified, 4 could not be found because they are small local events.
- Many large numbers are not completed layoffs but **plans** spread over several years. The project therefore says **"announced job cuts"**, never "jobs lost".
- "AI-DRIVEN" is the site's own classification. It is questionable for 7 rows (UPS, Dell, HDFC Bank, HubSpot, Uber, Southern Cross Media, Wells Fargo); for 2 rows the news cites AI but the label is missing (Envato, United Internet). For 13 rows the number is an upper bound ("up to …").

## 3. Two AI definitions
| Definition | Rule | Use |
|---|---|---|
| **Strict** (`is_ai_strict`) | AI-DRIVEN **and** label not questionable **and** number not "up to …" (74 rows) | **Headline — used everywhere** |
| Broad (`is_ai_driven`) | All AI-DRIVEN labels (92 rows) | Upper bound only |

Why it matters: the gap between the two comes mostly from a few giant rows (UPS 30,000, Oracle 30,000, HSBC 20,000, Meta 16,000, Cognizant 15,000, Dell 11,000, Microsoft 8,750). For each of them either the AI reason is questionable or the number is an upper bound. The 18 "broad only" rows have a median of 1,750 people.

## 4. Reliability tiers
Every row carries exactly one reliability label (`reliability_tier`). Main analysis: 643 rows, 653,456 people.

| Tier | Meaning | Rows | Share of people |
|---|---|---|---|
| T1 | Manually verified / corrected | 106 | 47.2% |
| T2 | Manually, partially verified | 27 | 25.0% |
| T3 | Strong source (link contains company and number, or a row-specific official WARN page) | 180 | 9.3% |
| T4 | Medium source (link contains the company) | 186 | 11.1% |
| T5 | Weak source (generic page / aggregator / WARN list home page) | 144 | 7.3% |

**72%** of the people in the main analysis were checked manually; **81.6%** are in the T1–T3 "verified core".

## 5. Robustness check
The main findings were recomputed at three data levels (`robustness_check.csv`). AI shares use the **strict definition**, broad in brackets:

| Finding | All rows | Core (T1–T3) | Manual only (T1–T2) | Result |
|---|---|---|---|---|
| Top 3 industries | Automotive, Tech, Finance | Same | Same | ✅ Robust |
| AI people share, Jan–Apr mean | 18.2% (57.3%) | 22.3% (69.9%) | 23.4% (74.1%) | ✅ Higher at every level |
| AI people share, Jun–Sep mean | 5.2% (8.0%) | 6.6% (9.9%) | 13.0% (16.8%) | ✅ Lower at every level — the decline is robust |
| AI announcements cover more people (median) | 295 vs 180 | 320 vs 200 | — | ✅ Same direction |
| Large companies are the ones citing AI | No | No | No | ❌ Not used |

**The headline AI share is reported from all rows:** about **16.9%** of the people in announced job cuts are attributed to AI (strict definition). With all labels the share is 38.4%; because it depends on a few giant plans, it is only given as an upper bound.

**Announcement-count share as a second measure:** the people share can jump with a single giant announcement (in October, the Dutch Government's 25,000 plan alone lifts it to 50.5%). The monthly trend is therefore also given by number of announcements. With the strict definition, the AI share of announcements is 8–20% from January to July (peak **May 40.3%**) and **3–6%** from August on.

> Note: manual verification covered every AI row, so AI rows are over-represented at the T1–T2 level; the AI share at that level carries a selection effect and is not used as a headline. The point of the robustness check is not the share itself but that the **direction over time and the industry ranking** stay the same at every level.

## 6. Independent cross-check (Challenger, Gray & Christmas)
The AI share over time was compared with Challenger, Gray & Christmas's monthly US reports for January–October 2026 (`challenger_ai_monthly.csv`, `challenger_vs_layoffhedge.csv`). The monthly figures add up exactly to the year-to-date totals Challenger publishes, at 11 checkpoints. A "7,000" September figure in one article does not fit that chain and was not used (the correct value is 3,961).

| | Jan–Jul mean | Aug–Oct mean | Correlation with Challenger |
|---|---|---|---|
| Challenger AI share (US, people) | 24.4% | 6.2% | — |
| layoffhedge AI **announcement-count** share (strict) | 19.5% | 3.6% | **0.72** |
| layoffhedge AI **people** share (strict) | 18.4% | 17.5% | −0.20 |

Two independent sources tell the same story: AI as a stated reason is high through spring and summer (first place in Challenger from March to July, peak May 39.8%) and drops clearly from August (October 2.9%). The match shows up in the layoffhedge **announcement-count** share; the people share is distorted by a few giant announcements (upper-bound numbers in March, the non-US Dutch Government plan in October). August was used as the split because it is the month AI loses first place in the independent source — and the result holds for any split from June to September (see §7).

> Note: in a 10-month series a correlation is weak evidence; here it is only used to confirm direction. Challenger covers the US only, layoffhedge is global. Challenger's AI figure is also the reason stated by the employer.

## 7. Statistical tests (`statistical_tests.py`, `statistical_tests.csv`)
No machine learning; resampling (bootstrap, 10,000 repetitions, fixed seed) and classical tests. Goal: check whether the findings could be due to chance or to the chosen window.

| Test | Result | Meaning |
|---|---|---|
| Median difference (strict AI − non-AI) | 115 people, 95% CI 50–421 | CI excludes zero → the difference is not chance |
| Mann-Whitney U (one-sided) | p < 0.001 | AI announcements cover more people |
| Headline AI share (strict, people) | 16.9%, CI 8.8–27.5% | Wide interval: depends on a few giant rows → present as "about one in six" |
| AI share (strict, announcements) | 11.5%, CI 9.0–14.0% | Narrow interval: the more stable measure |
| Split-month sensitivity | "High first → low later" for a split in June, July, August or September (in both sources) | Choosing August after the fact does not drive the result. With a May split there is no difference, because the peak month May falls into the "after" group |
| Challenger ~ count share | r = 0.72, permutation p ≈ 0.006 | Monthly series are autocorrelated, so p may be optimistic; confirms direction |
| Challenger ~ people share | r = −0.20, p ≈ 0.72 | No match |
| Missed AI labels | Strict AI share 16.9% → at most ~18.1% in the worst case | Asymmetric verification does not change the result |

## Limitations
- The data only contains cuts that were announced publicly and reached the news; small companies are under-represented.
- There is no country column; no country-level analysis is possible.
- `total_workforce` is the site's estimate and can differ between rows of the same company (e.g. Amazon 350k / 1.55m); industry ratios are therefore not computed from summed workforce but from the median of the row-level workforce %.
- **Different scopes:** layoffhedge = global (no country column) · Indeed = 9 countries (no Turkey) · Challenger = US only. Cross-source comparisons are **confirmations of direction**; they do not measure the same population.
- **No seniority information:** none of the data sets distinguishes junior/senior roles. The junior section is an **interpretation**, not a finding.
- **Asymmetric verification:** every AI-labelled row but only 50 non-AI rows were checked manually. Measured (`statistical_tests.py`, test 5): the missed-label rate among checked rows is 4% (2/50); applying it to the 502 unchecked rows raises the strict AI share from 16.9% to at most ~18.1%. All non-AI URLs were also scanned for AI keywords; no new missed label was found.
- **Narrow Indeed metric:** "posting mentions AI" ≠ AI-skill demand. Postings of companies selling AI products and "we use AI in hiring" disclosures are counted too (the Canada law effect proves it).
- **Limited statistical power:** 10-month time series; correlations confirm direction. The headline AI share depends on a few giant rows (95% CI 8.8–27.5%).
- The site seems to have collected more small announcements in recent months; comparisons of monthly announcement **counts** should be read with care.
- November 2026 is a partial month (data until 6 November).
