# Data Sources and Licenses

The raw data in `data/raw/` comes from third parties and is **not** covered by the MIT license of this repository. Files in `data/clean/` are derived from these sources and keep the same terms.

| Data | Files | Source | License / terms |
|---|---|---|---|
| 2026 layoff announcements | `raw/layoffs_2026.csv` | [layoffhedge.com](https://layoffhedge.com) — export generated 2026-11-08 | "Free to use with attribution" (stated in the file header) |
| Share of job postings mentioning AI | `raw/indeed_ai_posting.csv` | [Indeed Hiring Lab — AI Tracker](https://www.hiringlab.org/) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| US job cuts and AI-attributed cuts, Jan–Oct 2026 | `clean/challenger_ai_monthly.csv` (built by `python/build_challenger.py`) | [Challenger, Gray & Christmas](https://www.challengergray.com/) monthly job-cut reports and news coverage of them (source link per row) | Publicly reported figures; facts quoted with attribution |

## Attribution
- Layoff data: **layoffhedge.com**, 2026 layoff list (version of 8 November 2026).
- Job-posting data: **Indeed Hiring Lab, AI Tracker**, licensed under CC BY 4.0. Changes made: daily values aggregated to monthly means per country; year-over-year change computed; Canadian rows from October 2025 flagged as not comparable.
- US job-cut data: **Challenger, Gray & Christmas, Inc.**, monthly job-cut reports, January–October 2026.

## Modifications to the layoff data
No row was deleted. Data-quality columns were added; 2 numbers were corrected based on news sources (the original value is kept in `people_cut_original`); 4 wrong-year rows and 6 undated rows are excluded from the main analysis by flag. See `docs/DATA_QUALITY.md`.
